# OpenShift to Kubernetes migration

This repository now contains a standard Kubernetes deployment for the Task
Manager service. The service source and original OpenShift resources were
restored from repository history so the migration is buildable and auditable.
The OpenShift files remain under `openshift-task-manager/openshift-resources/`
with deprecation banners and unchanged resource specifications.

## Runtime inventory

| Concern | Existing behavior | Kubernetes mapping |
|---|---|---|
| Runtime and entry point | Python 3.11; Gunicorn runs `app:app` with two workers | Preserved by `openshift-task-manager/Dockerfile` |
| Build | OpenShift `BuildConfig` using the Dockerfile and an `ImageStream` output | Build externally, push to a registry, and replace the TODO image reference |
| Network | HTTP on container/service port 8080; external edge-TLS `Route` with HTTP-to-HTTPS redirect | ClusterIP `Service` plus AWS ALB `Ingress` |
| Health | HTTP `GET /health`; readiness delay 10s/period 5s; liveness delay 30s/period 10s | Preserved in the `Deployment` |
| Resources | Request 100m CPU/128Mi; limit 500m CPU/512Mi | Preserved in the `Deployment` |
| Replicas and rollout | Two replicas in the Helm values; rolling 25% unavailable/25% surge | Preserved in the `Deployment` |
| Autoscaling | Parameters exist for 2-5 replicas at 80% CPU, but autoscaling is disabled | `k8s/hpa.yaml` is supplied but remains opt-in |
| Configuration | `PORT=8080`; the production Gunicorn command also binds explicitly to 8080 | ConfigMap-backed environment variable |
| Secrets | None | Empty Secret object referenced by the pod; values must be supplied out of band if later needed |
| Storage | No volume mounts or persistent volumes; task data is process-local memory | No Kubernetes volumes added |
| Dependencies | No database, cache, queue, or other service | No dependency resources added |
| Security | Non-root UID 1001, no privilege escalation, all capabilities dropped | Pod/container security contexts and restricted Pod Security Standards |

The HTTP UI is at `/`; the API uses `/api/tasks`,
`/api/tasks/{id}/complete`, and `/api/tasks/{id}`. Because task state is
in-memory, it is neither durable nor shared between the two Gunicorn workers
or replicas. This pre-existing behavior is intentionally unchanged.

## Resource mapping

| Deprecated OpenShift resource | Replacement |
|---|---|
| `Project` | `k8s/namespace.yaml` |
| `DeploymentConfig` | `k8s/deployment.yaml` |
| `Route` inside the OpenShift template | `k8s/ingress.yaml` |
| `ImageStream` | Direct container registry image reference |
| `SecurityContextConstraints` | Pod Security Standards plus security contexts |
| `Template` | Base `k8s/kustomization.yaml` and `overlays/{dev,staging,prod}` |
| `BuildConfig` | External Docker/CI build |

## Files created or restored

- `k8s/deployment.yaml` — standard Deployment with probes, resources, rolling
  updates, ConfigMap/Secret references, and non-root security controls.
- `k8s/service.yaml` — internal ClusterIP service on port 8080.
- `k8s/ingress.yaml` — external AWS ALB Ingress replacing the OpenShift Route.
- `k8s/configmap.yaml` — non-sensitive `PORT` configuration.
- `k8s/secret.yaml` — empty Secret reference with no committed secret values.
- `k8s/hpa.yaml` — optional, previously disabled 2-5 replica/80% CPU policy.
- `k8s/namespace.yaml` and `k8s/serviceaccount.yaml` — namespace, Pod Security
  Standards labels, and workload identity.
- `k8s/kustomization.yaml` — conservative base with autoscaling excluded.
- `overlays/dev/kustomization.yaml`, `overlays/staging/kustomization.yaml`, and
  `overlays/prod/kustomization.yaml` — environment-specific image/label hooks.
- `openshift-task-manager/Dockerfile` and `.dockerignore` — external OCI image
  build replacing the OpenShift BuildConfig build path.
- `openshift-task-manager/app/app.py` and `app/requirements.txt` — service build
  context restored from repository history.
- `openshift-task-manager/openshift-resources/*.yaml` — the six original
  OpenShift descriptors restored with deprecation comments for rollback.
- `MIGRATION.md` — this migration record; the root `README.md` was also updated
  to point contributors to the new deployment path.

## Deploy

First replace `task-manager:latest` with a published registry image in the
selected overlay. Then render or apply exactly one environment:

```bash
kubectl kustomize overlays/dev
kubectl kustomize overlays/staging
kubectl kustomize overlays/prod
kubectl apply -k overlays/prod
```

When connected to a cluster, validate the base with
`kubectl apply --dry-run=client -k k8s`. Do not use `-f k8s/` for deployment:
that mode treats `kustomization.yaml` as an API object and also includes the
optional HPA that the base intentionally excludes.

The base preserves the existing disabled-autoscaling behavior. After human
review, enable the documented policy separately with:

```bash
kubectl apply -f k8s/hpa.yaml
```

## Human-review TODOs

- Publish the image to ECR or another registry and pin an immutable production
  tag or digest in the overlays.
- Supply an ACM certificate ARN and enable the HTTPS listener and SSL redirect
  annotations in `k8s/ingress.yaml`. Until then, the ALB serves HTTP, which
  does not fully preserve the original Route's edge TLS and redirect.
- Install the AWS Load Balancer Controller before applying the Ingress.
- Decide whether to enable `k8s/hpa.yaml`; install metrics-server first.
- Keep `k8s/secret.yaml` empty until real credentials exist, then source values
  from an external secret manager rather than committing them.
- Add a shared datastore before relying on consistent task state across
  workers, replicas, restarts, or autoscaling.

## Validation

Validation performed in the migration workspace:

- After installing the missing PyYAML module, the requested `yaml.safe_load`
  loop parses all nine YAML files without warnings.
- The eight Kubernetes resources in `k8s/` pass strict schema validation with
  kubeconform 0.7.0.
- `kubectl kustomize` renders the base and dev, staging, and prod overlays;
  each seven-resource render passes strict schema validation.
- The existing Helm chart passes `helm lint`; its four-resource
  `helm template .` output also passes strict schema validation.
- The requested `kubectl apply --dry-run=client` checks were attempted for both
  raw manifests and Helm output. Kubectl 1.37 still requested API discovery and
  OpenAPI from `localhost:8080`, so both apply stages were blocked because this
  workspace has no Kubernetes API server. The offline checks above cover YAML,
  Kustomize, and Kubernetes schemas.
- The Dockerfile passes hadolint 2.14.0. Its pinned dependencies install, the
  application compiles, the two-worker Gunicorn command starts, `/health`
  returns healthy, and a task can be created. A Buildah image build was also
  attempted, including root/chroot isolation, but the host denies the required
  `CLONE_NEWUSER` operation. No Docker-compatible daemon is available, so an
  actual image build remains to be run in CI or a container-enabled workspace.

## Rollback to OpenShift

The migration is additive. The original OpenShift specifications are preserved
under `openshift-task-manager/openshift-resources/`; only deprecation comments
were added, so they remain valid input to `oc`.

1. Remove the Kubernetes resources from the environment that was applied:

   ```bash
   # Run only if the optional HPA was applied separately.
   kubectl delete -f k8s/hpa.yaml --ignore-not-found

   # This also deletes the dedicated task-manager Namespace. Review first if
   # that Namespace contains anything not managed by these manifests.
   # Replace ENVIRONMENT with dev, staging, or prod.
   kubectl delete -k overlays/ENVIRONMENT
   ```

2. Against the OpenShift cluster, restore the project and cluster-scoped SCC,
   then process the preserved Template. The Template recreates the service
   account, DeploymentConfig, Service, Route, and ImageStream:

   ```bash
   oc apply -f openshift-task-manager/openshift-resources/project.yaml
   oc apply -f openshift-task-manager/openshift-resources/scc.yaml
   oc process -f openshift-task-manager/openshift-resources/template.yaml \
     | oc apply -f -
   ```

3. If OpenShift should also resume in-cluster image builds, restore the
   preserved ImageStream and BuildConfig after replacing the placeholder Git
   repository in `buildconfig.yaml`:

   ```bash
   oc apply -f openshift-task-manager/openshift-resources/imagestream.yaml
   oc apply -f openshift-task-manager/openshift-resources/buildconfig.yaml
   ```

The standalone preserved `deploymentconfig.yaml` is available as an alternative
to the Template-managed DeploymentConfig; do not apply both unless the two
separate workloads (`task-manager` and `task-manager-dc`) are intentional.
