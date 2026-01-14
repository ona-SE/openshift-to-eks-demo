# AGENTS.md

AI agent guide for working with the OpenShift to EKS Migration Demo repository.

## Repository Overview

This is a demonstration repository showing how to migrate OpenShift applications to Amazon EKS. It contains:
- Example migrated Helm chart (EKS-compatible)
- Migration documentation and prompts
- Reference implementation for OpenShift-to-EKS conversion

**Source Application**: The demo uses the OpenShift Task Manager from [shift-eks](https://github.com/gitpod-samples/shift-eks)

## Key Directories

```
.
├── .devcontainer/          # Dev container configuration (Dockerfile, devcontainer.json)
├── migrated-helm-chart/    # Example EKS-compatible Helm chart
│   └── task-manager/       # Migrated task-manager application chart
│       ├── Chart.yaml      # Helm chart metadata
│       ├── values.yaml     # Default configuration values
│       └── templates/      # Kubernetes manifest templates
└── README.md               # Main documentation with migration prompt
```

## Setup Commands

This repository is documentation-focused and does not require build/install steps.

### Prerequisites

Required tools (should be pre-installed in dev container):
- `aws` - AWS CLI for interacting with AWS services
- `kubectl` - Kubernetes CLI for cluster management
- `helm` - Helm package manager for Kubernetes
- `eksctl` - EKS cluster management tool

### Environment Variables

Set these before running the migration:

```bash
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_SESSION_TOKEN="your-session-token"  # if using temporary credentials
export AWS_DEFAULT_REGION="us-east-2"  # or your preferred region
```

Verify AWS credentials:
```bash
aws sts get-caller-identity
```

## Working with the Migration

### Helm Chart Validation

Validate the migrated Helm chart:
```bash
helm lint migrated-helm-chart/task-manager
```

Template the chart to see generated manifests:
```bash
helm template task-manager migrated-helm-chart/task-manager
```

### EKS Cluster Operations

List existing clusters:
```bash
aws eks list-clusters --region $AWS_DEFAULT_REGION
```

Update kubeconfig for cluster access:
```bash
aws eks update-kubeconfig --name task-manager-eks --region $AWS_DEFAULT_REGION
```

Check cluster status:
```bash
kubectl cluster-info
kubectl get nodes
```

### Application Deployment

Deploy using Helm:
```bash
helm install task-manager migrated-helm-chart/task-manager -n task-manager --create-namespace
```

Check deployment status:
```bash
kubectl get pods -n task-manager
kubectl get ingress -n task-manager
kubectl get svc -n task-manager
```

View application logs:
```bash
kubectl logs -n task-manager -l app=task-manager
```

### Cleanup

Remove application:
```bash
helm uninstall task-manager -n task-manager
kubectl delete namespace task-manager
```

Delete EKS cluster (takes 10-15 minutes):
```bash
eksctl delete cluster --name task-manager-eks --region $AWS_DEFAULT_REGION
```

Delete ECR repository:
```bash
aws ecr delete-repository --repository-name task-manager --force --region $AWS_DEFAULT_REGION
```

## Git Workflow

### Branch Naming

No specific convention enforced. Default branch is `master`.

### Commit Format

Follow existing style (see recent commits):
```bash
git log --oneline -5
```

Example format:
```
Short descriptive message

Optional longer description if needed.
```

Always include co-author:
```
Co-authored-by: Ona <no-reply@ona.com>
```

### Making Changes

1. Check current status:
```bash
git status
git diff
```

2. Stage relevant files:
```bash
git add <files>
```

3. Commit with descriptive message:
```bash
git commit -m "Your message

Co-authored-by: Ona <no-reply@ona.com>"
```

4. Push changes:
```bash
git push origin master
```

## OpenShift to EKS Feature Mapping

When working with migrations, understand these conversions:

| OpenShift Feature | EKS Equivalent |
|-------------------|----------------|
| Routes | Kubernetes Ingress + AWS ALB Controller |
| DeploymentConfig | Kubernetes Deployment |
| ImageStreams | Amazon ECR |
| SecurityContextConstraints | Pod Security Standards |
| Projects | Kubernetes Namespaces |
| BuildConfig | External CI/CD |
| Templates | Helm Charts |

## Common Tasks

### Verify AWS Setup

```bash
# Check AWS credentials
aws sts get-caller-identity

# List EKS clusters
aws eks list-clusters

# List ECR repositories
aws ecr describe-repositories
```

### Debug Kubernetes Resources

```bash
# Check pod status
kubectl get pods -n task-manager

# Describe pod for events
kubectl describe pod <pod-name> -n task-manager

# View logs
kubectl logs <pod-name> -n task-manager

# Check ingress details
kubectl describe ingress task-manager -n task-manager
```

### Test Application

Health check:
```bash
curl http://<alb-url>/health
```

API operations:
```bash
# List tasks
curl http://<alb-url>/api/tasks

# Create task
curl -X POST http://<alb-url>/api/tasks -H "Content-Type: application/json" -d '{"title":"Test task"}'

# Complete task
curl -X PUT http://<alb-url>/api/tasks/1/complete

# Delete task
curl -X DELETE http://<alb-url>/api/tasks/1
```

## Important Notes

- This is a demo repository - no CI/CD pipeline configured
- No automated tests in this repository (tests are in the source application)
- Always clean up AWS resources after demos to avoid costs
- EKS cluster creation takes 15-20 minutes
- Cluster deletion takes 10-15 minutes
- Estimated AWS cost: ~$0.20-0.30/hour while running

## Resources

- [Main README](./README.md) - Full migration guide and prompt
- [shift-eks Repository](https://github.com/gitpod-samples/shift-eks) - Source OpenShift application
- [Migrated Helm Chart](./migrated-helm-chart/) - Example migration result
