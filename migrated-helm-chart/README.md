# Migrated Helm Chart - EKS Compatible

This directory contains an example of the OpenShift Helm chart after migration to EKS.

## What Changed

### Removed OpenShift-Specific Resources
- ❌ `route.yaml` - OpenShift Routes
- ❌ `deploymentconfig.yaml` - OpenShift DeploymentConfig
- ❌ `imagestream.yaml` - OpenShift ImageStreams
- ❌ `scc.yaml` - SecurityContextConstraints
- ❌ `template.yaml` - OpenShift Templates

### Added EKS-Compatible Resources
- ✅ `deployment.yaml` - Standard Kubernetes Deployment
- ✅ `ingress.yaml` - Kubernetes Ingress with AWS ALB annotations

### Modified Resources
- ✅ `values.yaml` - Updated with EKS-specific configuration
- ✅ `service.yaml` - No changes needed (standard Kubernetes)
- ✅ `serviceaccount.yaml` - No changes needed (standard Kubernetes)

## Key Changes in values.yaml

```yaml
# Image repository changed to ECR
image:
  repository: <account-id>.dkr.ecr.<region>.amazonaws.com/task-manager
  tag: "latest"

# Ingress enabled for EKS
ingress:
  enabled: true
  className: alb

# OpenShift features disabled
openshift:
  useDeploymentConfig: false
  useImageStream: false
  scc:
    enabled: false

# Route disabled
route:
  enabled: false
```

## Deployment Instructions

```bash
# Update kubeconfig for EKS cluster
aws eks update-kubeconfig --name task-manager-eks --region us-east-2

# Install the chart
helm install task-manager ./task-manager -n task-manager --create-namespace

# Check deployment
kubectl get all,ingress -n task-manager

# Get ALB URL
kubectl get ingress task-manager -n task-manager -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

## Source

This migrated chart is based on the OpenShift Helm chart from:
https://github.com/gitpod-samples/shift-eks/tree/main/openshift-task-manager/helm/task-manager
