# OpenShift → Kubernetes Migration

This document records the migration of the **Task Manager** service from its
OpenShift-specific deployment model to standard Kubernetes manifests.

## What was migrated

The service previously relied on OpenShift-only resources (the "custom
orchestrator" configuration). Each has been replaced with a standard Kubernetes
equivalent. The original OpenShift files are **preserved** with `DEPRECATED:`
banners (they are not deployed) so the change is reviewable and reversible.

| OpenShift resource (source) | Kubernetes replacement | Notes |
|---|---|---|
| `DeploymentConfig` (`openshift-task-manager/openshift-resources/deploymentconfig.yaml`) | `Deployment` (`k8s/deployment.yaml`) | RollingUpdate 25%/25%, `/health` probes, resource requests/limits, non-root securityContext all preserved. |
| `Route` (in `template.yaml`) | `Ingress` (`k8s/ingress.yaml`) | AWS ALB Ingress. Edge TLS + HTTP→HTTPS redirect not reproduced yet (needs ACM cert — see TODOs). |
| `ImageStream` (`imagestream.yaml`) | Direct registry image reference (`k8s/deployment.yaml` `image:`) | No K8s equivalent; images come from a registry (ECR), patched per env in `overlays/*`. |
| `SecurityContextConstraints` (`scc.yaml`) | Pod `securityContext` + Pod Security Standards (`k8s/deployment.yaml`, `k8s/namespace.yaml`) | Non-root UID 1001, drop ALL caps, no privilege escalation; namespace enforces the `restricted` profile. |
| `Project` (`project.yaml`) | `Namespace` (`k8s/namespace.yaml`) | |
| `Template` (`template.yaml`) | Kustomize (`k8s/` base + `overlays/{dev,staging,prod}`) | Parameterization via overlays instead of Template parameters. |
| `BuildConfig` (`buildconfig.yaml`) | External CI/CD build of the `Dockerfile` → registry (ECR) | In-cluster builds replaced by pipeline builds. |

### Service runtime (unchanged)

- **Runtime**: Python 3.11, Flask app served by gunicorn (2 workers), listening on
  `:8080`. Entry point `app:app` in `openshift-task-manager/app/app.py`.
- **Endpoints**: `GET /` (UI), `GET /health`, `GET/POST /api/tasks`,
  `PUT /api/tasks/{id}/complete`, `DELETE /api/tasks/{id}`.
- **Dependencies**: none external — tasks are stored **in-memory** (see TODOs).
- **Config**: `PORT` env var (defaults to 8080), sourced from a ConfigMap.

## New files created

```
MIGRATION.md                          # this document
.gitignore                            # Python / env / editor ignores (repo had none)

k8s/                                  # Kubernetes base manifests (flat)
  kustomization.yaml                  # base kustomization (namespace, common labels)
  namespace.yaml                      # replaces OpenShift Project; PSS "restricted"
  serviceaccount.yaml                 # task-manager ServiceAccount
  configmap.yaml                      # non-sensitive config (PORT)
  secret.yaml                         # references-only placeholder (no values)
  deployment.yaml                     # replaces DeploymentConfig
  service.yaml                        # ClusterIP (internal)
  ingress.yaml                        # ALB Ingress (replaces Route)

components/
  autoscaling/
    kustomization.yaml                # opt-in Kustomize component
    hpa.yaml                          # HorizontalPodAutoscaler (2–5, 80% CPU)

overlays/                             # environment overlays (Kustomize)
  dev/kustomization.yaml              # 1 replica, no autoscaling, tag: dev
  staging/kustomization.yaml          # 2 replicas + HPA, tag: staging
  prod/kustomization.yaml             # 3 replicas + HPA (2–10, 70% CPU), tag: prod

openshift-task-manager/
  Dockerfile                          # K8s-oriented image build (non-root UID 1001)
  .dockerignore
  app/app.py                          # vendored application source
  app/requirements.txt
  openshift-resources/*.yaml          # original OpenShift configs, DEPRECATED banners
```

> The base manifests live flat in `k8s/` so they are picked up by simple tooling
> (e.g. `kubectl apply -f k8s/` / `k8s/*.yaml` globs). `overlays/` and
> `components/` sit at the repo root to avoid a Kustomize "base inside overlay"
> cycle.

## How to deploy

```bash
# Render a specific environment (offline):
kubectl kustomize overlays/dev
kubectl kustomize overlays/staging
kubectl kustomize overlays/prod

# Apply to a cluster:
kubectl apply -k overlays/prod

# Or apply the raw base (no env-specific replicas/tags):
kubectl apply -k k8s
```

## TODOs / manual steps before production

These are also flagged as `TODO(human-review)` comments in the manifests.

1. **Container image reference** — replace the placeholder `task-manager` image
   name with your registry (e.g.
   `<account-id>.dkr.ecr.<region>.amazonaws.com/task-manager`) in each overlay's
   `images:` block, and pin an immutable tag for prod.
2. **Ingress TLS** — the OpenShift Route used edge TLS termination with
   HTTP→HTTPS redirect. The ALB Ingress currently serves **HTTP only**. Provide an
   ACM certificate ARN and enable the HTTPS listener + `ssl-redirect` annotations
   in `k8s/ingress.yaml`.
3. **AWS Load Balancer Controller** — the ALB Ingress requires the
   [AWS Load Balancer Controller](https://kubernetes-sigs.github.io/aws-load-balancer-controller/)
   installed in the cluster.
4. **metrics-server** — the HPA (staging/prod) requires
   `metrics-server` installed for CPU metrics.
5. **Secrets** — `k8s/secret.yaml` is an empty placeholder (the app currently has
   no credentials). If the service gains secrets, populate them out-of-band
   (kubectl / External Secrets Operator / Sealed Secrets — never commit values)
   and uncomment the `envFrom` block in `k8s/deployment.yaml`.
6. **In-memory state** — tasks are stored per-process, so state is **not shared**
   across gunicorn workers or replicas (unchanged from OpenShift). Before relying
   on consistent state at scale, back the app with a shared datastore (e.g.
   Postgres/Redis) and add the corresponding Service/Secret/env wiring.
7. **Image build** — build and push the image from
   `openshift-task-manager/Dockerfile` via CI/CD before deploying (replaces the
   OpenShift BuildConfig).

## Validation performed

- `kubectl kustomize` builds cleanly for base (`k8s/`) and all three overlays.
- `kubeconform -strict` — all resources valid (base 7; dev 7; staging 8; prod 8).
- `hadolint openshift-task-manager/Dockerfile` — clean.
- Dockerfile build/run steps reproduced locally (pip install + gunicorn 2
  workers); `/health` returns 200 and the task API returns 201/200/200/204.
- PyYAML `safe_load_all` parses every file in `k8s/*.yaml`.

> `kubectl apply --dry-run=client` and `helm template | kubectl apply
> --dry-run=client` contact a cluster API server for resource resolution, and no
> cluster/Docker daemon is available in this environment. `kubeconform -strict`
> was used as the offline schema-validation equivalent.

## Rollback

The migration is **additive** — no OpenShift files were deleted. To roll back to
the OpenShift deployment:

1. **Remove the Kubernetes deployment** (if applied):
   ```bash
   kubectl delete -k overlays/<env>   # or: kubectl delete -k k8s
   ```
2. **Re-apply the original OpenShift resources.** They remain intact under
   `openshift-task-manager/openshift-resources/` (each carries a `DEPRECATED:`
   banner comment only; the specs are unchanged). On an OpenShift cluster:
   ```bash
   oc apply -f openshift-task-manager/openshift-resources/project.yaml
   oc apply -f openshift-task-manager/openshift-resources/scc.yaml
   oc apply -f openshift-task-manager/openshift-resources/imagestream.yaml
   oc apply -f openshift-task-manager/openshift-resources/buildconfig.yaml
   oc apply -f openshift-task-manager/openshift-resources/deploymentconfig.yaml
   # Route/Service are provided via the Template:
   oc process -f openshift-task-manager/openshift-resources/template.yaml | oc apply -f -
   ```
   (Remove the `DEPRECATED:` banner comments first if you want clean files;
   they do not affect `oc` parsing.)
3. The vendored application source and `Dockerfile` are shared by both models, so
   no code rollback is required.
