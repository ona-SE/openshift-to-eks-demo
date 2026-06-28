# Kubernetes Manifests

Standard Kubernetes manifests for the Task Manager service, migrated from the
OpenShift orchestrator descriptors in `../legacy-openshift/`. See `../MIGRATION.md`
for the full migration record.

## Layout

This uses the Kustomize base + overlays pattern:

```
k8s/
├── base/                # environment-agnostic manifests
│   ├── namespace.yaml
│   ├── serviceaccount.yaml
│   ├── configmap.yaml
│   ├── secret.yaml      # scaffold only — no real values committed
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── ingress.yaml
│   ├── hpa.yaml
│   └── kustomization.yaml
└── overlays/
    ├── dev/             # 1 replica, no HPA
    ├── staging/         # HPA min 2 / max 4
    └── prod/            # HPA min 2 / max 5
```

## How to apply

Manifests live in subdirectories, so a flat `kubectl apply -f k8s/` will NOT
find them. Use Kustomize (`-k`) or recursive file mode (`-f ... -R`):

```bash
# Render an environment (review before applying)
kubectl kustomize k8s/overlays/prod

# Dry-run (server-side; requires cluster access)
kubectl apply -k k8s/overlays/prod --dry-run=server

# Apply
kubectl apply -k k8s/overlays/prod
```

## How to validate offline (no cluster)

```bash
# Schema-validate any single base manifest
kubeconform -strict k8s/base/deployment.yaml

# Schema-validate a fully rendered overlay
kubectl kustomize k8s/overlays/prod | kubeconform -strict -summary
```

`kubectl apply --dry-run=client` performs server API discovery and therefore
needs a reachable cluster; use `kubeconform` for offline schema validation.
