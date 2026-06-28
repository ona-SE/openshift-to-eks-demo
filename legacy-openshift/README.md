# Legacy OpenShift Orchestrator Configs (DEPRECATED)

These are the original OpenShift-specific deployment descriptors, kept for
reference during the migration to standard Kubernetes. **Do not apply these to
the EKS cluster** — they depend on OpenShift-only APIs.

| Legacy file | OpenShift kind | Kubernetes replacement |
|---|---|---|
| `deploymentconfig.yaml` | DeploymentConfig | `k8s/base/deployment.yaml` |
| `route` (in `template.yaml`) | Route | `k8s/base/ingress.yaml` |
| `imagestream.yaml` | ImageStream | ECR image refs in `k8s/base/deployment.yaml` + overlays |
| `scc.yaml` | SecurityContextConstraints | Pod Security Standards (`k8s/base/namespace.yaml`) + container securityContext |
| `project.yaml` | Project | `k8s/base/namespace.yaml` |
| `buildconfig.yaml` | BuildConfig | External CI/CD using root `Dockerfile` |
| `template.yaml` | Template | Kustomize overlays (`k8s/overlays/*`) |

Once the EKS deployment is verified and these are no longer needed for
reference, this directory can be removed in a follow-up change.
