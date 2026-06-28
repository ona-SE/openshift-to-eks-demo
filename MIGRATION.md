# OpenShift → Kubernetes Migration

This document records the migration of the Task Manager service from OpenShift's
custom orchestration resources to standard Kubernetes manifests targeting Amazon
EKS.

## What was migrated

The service previously deployed through OpenShift-specific resources. Each was
converted to its standard Kubernetes equivalent. The original descriptors are
preserved under `legacy-openshift/` (with `DEPRECATED` headers) for reference and
rollback.

| OpenShift resource (source) | Kubernetes replacement | Notes |
|---|---|---|
| `DeploymentConfig` (`apps.openshift.io/v1`) | `Deployment` (`apps/v1`) — `k8s/base/deployment.yaml` | ConfigChange trigger is implicit in a Deployment. Rolling strategy (maxUnavailable/maxSurge 25%) preserved. |
| `Route` (`route.openshift.io/v1`) | `Ingress` (`networking.k8s.io/v1`) — `k8s/base/ingress.yaml` | AWS Load Balancer Controller provisions an ALB. TLS edge termination is **not yet configured** (see TODOs). |
| `ImageStream` (`image.openshift.io/v1`) | Direct ECR image reference — `k8s/base/deployment.yaml` + overlay `images:` | Per-environment repo/tag set in `k8s/overlays/*`. |
| `SecurityContextConstraints` (`security.openshift.io/v1`) | Pod Security Standards + container `securityContext` | Namespace labeled `restricted` (`k8s/base/namespace.yaml`); non-root UID 1001, dropped capabilities, no privilege escalation preserved. |
| `Project` (`project.openshift.io/v1`) | `Namespace` — `k8s/base/namespace.yaml` | Same name: `task-manager`. |
| `Template` (`template.openshift.io/v1`) | Kustomize overlays — `k8s/overlays/{dev,staging,prod}` | Template parameters (replicas, resources, image, TLS) become overlay patches and image overrides. |
| `BuildConfig` (`build.openshift.io/v1`) | External CI/CD using root `Dockerfile` | In-cluster builds replaced by `docker build` + ECR push. |

### Service characteristics (preserved)

- **Runtime:** Python 3.11 Flask app served by gunicorn (2 workers), port 8080.
- **Entry point:** `gunicorn --bind 0.0.0.0:8080 --workers 2 --timeout 120 app:app`.
- **Environment variables:** `PORT` (defaults to 8080), supplied via ConfigMap.
- **External dependencies:** none — tasks are stored in memory.
- **Health check:** `GET /health` (used by liveness, readiness, and ALB health check).
- **Resources:** requests 100m CPU / 128Mi; limits 500m CPU / 512Mi.
- **Security context:** runAsNonRoot, UID 1001, fsGroup 1001, drop ALL capabilities,
  allowPrivilegeEscalation false, seccomp RuntimeDefault.

### Behavior changes (intentional)

- **Replicas:** raised from the DeploymentConfig's `1` to `2` in base to match the
  Helm chart default and provide availability during rolling updates. In
  staging/prod the HorizontalPodAutoscaler owns the replica count; the dev overlay
  pins it back to `1` and removes the HPA.
- **Autoscaling:** the source defined autoscaling rules (min 2, max 5, 80% CPU) but
  had them disabled. They are now materialized as a `HorizontalPodAutoscaler`
  (`k8s/base/hpa.yaml`), included in staging/prod and removed in dev.

## New files created

```
Dockerfile                              # K8s-targeted image (fixed UID/GID 1001)
.dockerignore                           # build-context excludes
app/app.py                              # vendored Flask application source
app/requirements.txt                    # Python dependencies

k8s/README.md                           # how to apply/validate the manifests
k8s/base/namespace.yaml                 # <- OpenShift Project + PSS labels
k8s/base/serviceaccount.yaml            # <- SCC user binding
k8s/base/configmap.yaml                 # non-sensitive config (PORT)
k8s/base/secret.yaml                    # secret scaffold (no values)
k8s/base/deployment.yaml                # <- DeploymentConfig
k8s/base/service.yaml                   # ClusterIP service
k8s/base/ingress.yaml                   # <- Route (ALB)
k8s/base/hpa.yaml                       # <- autoscaling rules
k8s/base/kustomization.yaml             # base resource list + common labels
k8s/overlays/dev/kustomization.yaml     # 1 replica, no HPA, dev image
k8s/overlays/staging/kustomization.yaml # HPA 2–4, staging image
k8s/overlays/prod/kustomization.yaml    # HPA 2–5, prod image

legacy-openshift/README.md              # legacy mapping + deprecation notice
legacy-openshift/deploymentconfig.yaml  # original OpenShift descriptors,
legacy-openshift/imagestream.yaml       #   preserved with DEPRECATED headers
legacy-openshift/project.yaml
legacy-openshift/scc.yaml
legacy-openshift/buildconfig.yaml
legacy-openshift/template.yaml

MIGRATION.md                            # this document
```

The pre-existing `migrated-helm-chart/` (a Helm-based equivalent) is unchanged and
remains available as an alternative packaging.

## Validation performed

| Check | Command | Result |
|---|---|---|
| Manifest schema (base) | `kubectl kustomize k8s/base \| kubeconform -strict` | 8 valid |
| Manifest schema (overlays) | `kubectl kustomize k8s/overlays/<env> \| kubeconform -strict` | dev 7, staging 8, prod 8 — all valid |
| Helm chart | `helm lint` + `helm template \| kubeconform -strict` | lint clean, 4 valid |
| Dockerfile | `hadolint Dockerfile` | 0 findings |

> Note: `kubectl apply --dry-run=client` and an actual `docker build` require a
> cluster and a Docker daemon respectively, neither of which is available in this
> environment. Equivalent offline checks (`kubeconform`, `hadolint`,
> build-context verification) were used instead.

## TODOs / manual steps before production

These are also flagged with `TODO(human review)` comments inline.

1. **Set the container image (required).** Replace the placeholder
   `<account-id>.dkr.ecr.<region>.amazonaws.com/task-manager` in each overlay
   (`k8s/overlays/*/kustomization.yaml`) with your real ECR repository. Build and
   push the image first:
   ```bash
   docker build -t <account-id>.dkr.ecr.<region>.amazonaws.com/task-manager:<tag> .
   aws ecr get-login-password --region <region> \
     | docker login --username AWS --password-stdin <account-id>.dkr.ecr.<region>.amazonaws.com
   docker push <account-id>.dkr.ecr.<region>.amazonaws.com/task-manager:<tag>
   ```
2. **Configure TLS (recommended).** The original Route used TLS edge termination
   with HTTP→HTTPS redirect. In `k8s/base/ingress.yaml`, uncomment the HTTPS
   listener annotations and set a real ACM certificate ARN and host. Until then the
   ALB serves HTTP only.
3. **Install the AWS Load Balancer Controller.** The Ingress (`ingressClassName:
   alb`) requires the controller to be installed in the cluster, with an IAM OIDC
   provider configured.
4. **Secrets (when applicable).** The app currently has no secrets.
   `k8s/base/secret.yaml` is an empty scaffold. Before adding sensitive config,
   wire it to a real source (External Secrets Operator / AWS Secrets Manager or
   Sealed Secrets). Never commit secret values.
5. **IRSA (optional).** If the workload needs AWS API access, add the
   `eks.amazonaws.com/role-arn` annotation to `k8s/base/serviceaccount.yaml`.
6. **Pin the prod image tag (recommended).** Prod currently uses a moving `latest`
   tag; pin to an immutable digest or promoted tag for reproducible deploys.
7. **Optional hardening.** Consider `readOnlyRootFilesystem: true` with an
   `emptyDir` mount for `/tmp` after confirming gunicorn writes nothing to the
   root filesystem.

## Rollback

The original OpenShift configuration is preserved under `legacy-openshift/` and was
**not deleted**. To roll back to OpenShift:

1. **Remove the Kubernetes resources** (if they were applied to EKS):
   ```bash
   kubectl delete -k k8s/overlays/<env>
   # or: kubectl delete namespace task-manager
   ```

2. **Restore the OpenShift resources on an OpenShift/OKD cluster.** The legacy
   files carry `DEPRECATED` / "do not apply to EKS" headers but are otherwise
   intact — remove the header comment block (lines starting with `#` at the top)
   if your tooling is strict, then apply:
   ```bash
   oc apply -f legacy-openshift/project.yaml
   oc apply -f legacy-openshift/scc.yaml
   oc apply -f legacy-openshift/imagestream.yaml
   oc apply -f legacy-openshift/deploymentconfig.yaml
   # buildconfig.yaml and template.yaml as needed
   ```
   The header comments are non-executable YAML comments, so the files also apply
   as-is; stripping the header is only needed if a linter rejects leading comments.

3. **Verify** the OpenShift Route, DeploymentConfig, and pods are healthy via
   `oc get route,dc,pods -n task-manager`.

Because the migration adds new files and does not modify or delete the legacy
configuration, rollback carries no risk of lost source.
