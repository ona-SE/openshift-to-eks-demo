# OpenShift to EKS Migration Demo

This repository demonstrates how to use Ona AI to migrate an OpenShift application to Amazon EKS with a single prompt.

## Overview

This demo showcases:
- **One-shot migration**: A single prompt that migrates a complete OpenShift application to EKS
- **OpenShift feature conversion**: Automatic conversion of Routes, DeploymentConfigs, ImageStreams, and SecurityContextConstraints
- **AWS infrastructure setup**: Automated EKS cluster creation, ECR setup, and Load Balancer Controller installation
- **End-to-end deployment**: From source code to running application on EKS

## What's Included

- **`openshift-task-manager/`** - A Flask-based task management application using OpenShift-specific features
- **`OPENSHIFT_FEATURES_SUMMARY.md`** - Detailed documentation of OpenShift features that need migration
- **Migration prompt** - Ready-to-use prompt for Ona AI (see below)

## Prerequisites

### Required Environment Variables

Set these environment variables in your Gitpod/development environment:

```bash
# AWS Credentials (required)
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_DEFAULT_REGION="us-east-1"  # or your preferred region
```

### AWS Permissions Required

Your AWS credentials need permissions for:
- ✅ EKS cluster creation and management
- ✅ ECR repository creation and image push
- ✅ Application Load Balancer creation
- ✅ IAM role and policy management
- ✅ VPC and networking resources
- ✅ EC2 instance management (for EKS nodes)

### Recommended IAM Policies

Attach these AWS managed policies to your IAM user/role:
- `AmazonEKSClusterPolicy`
- `AmazonEKSWorkerNodePolicy`
- `AmazonEC2ContainerRegistryFullAccess`
- `ElasticLoadBalancingFullAccess`
- `IAMFullAccess` (or specific permissions for role creation)
- `AmazonVPCFullAccess`

## The Application

The **OpenShift Task Manager** is a demonstration application that uses these OpenShift-specific features:

| Feature | OpenShift API | EKS Equivalent |
|---------|---------------|----------------|
| Routes | `route.openshift.io/v1` | Kubernetes Ingress + AWS ALB Controller |
| DeploymentConfig | `apps.openshift.io/v1` | Kubernetes Deployment |
| ImageStreams | `image.openshift.io/v1` | Amazon ECR |
| SecurityContextConstraints | `security.openshift.io/v1` | Pod Security Standards |
| Projects | `project.openshift.io/v1` | Kubernetes Namespaces |
| BuildConfig | `build.openshift.io/v1` | External CI/CD |
| Templates | `template.openshift.io/v1` | Helm Charts |

See [`OPENSHIFT_FEATURES_SUMMARY.md`](./OPENSHIFT_FEATURES_SUMMARY.md) for detailed explanations.

## Quick Start

### 1. Set Environment Variables

```bash
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_DEFAULT_REGION="us-east-1"
```

### 2. Open in Gitpod

[![Open in Gitpod](https://gitpod.io/button/open-in-gitpod.svg)](https://gitpod.io/#https://github.com/jrcoak/openshift-to-eks-demo)

### 3. Run the Migration Prompt

Copy and paste this prompt to Ona AI:

---

## 🚀 MIGRATION PROMPT

```
I want to migrate an OpenShift application to Amazon EKS. Please do the following:

1. Examine the OpenShift task-manager application in the `openshift-task-manager/` directory
2. Review the OpenShift-specific features documented in `OPENSHIFT_FEATURES_SUMMARY.md`
3. Check if an EKS cluster already exists in AWS, otherwise create a new EKS cluster with:
   - Cluster name: `task-manager-eks`
   - Node group with 2 t3.medium instances
   - Use the AWS region from AWS_DEFAULT_REGION environment variable
4. Set up required AWS infrastructure:
   - Install AWS Load Balancer Controller on the EKS cluster
   - Create an ECR repository named `task-manager`
   - Configure IAM roles and policies as needed
5. Build and push the task-manager container image to ECR
6. Migrate the OpenShift task-manager application to work on EKS by:
   - Converting OpenShift Routes to Kubernetes Ingress with AWS Load Balancer Controller annotations
   - Converting DeploymentConfig to standard Kubernetes Deployment
   - Replacing ImageStreams with ECR image references
   - Replacing SecurityContextConstraints with Pod Security Standards
   - Updating the Helm chart in `openshift-task-manager/helm/task-manager/` to remove OpenShift-specific resources
   - Keep the same namespace: `task-manager`
7. Deploy the migrated application to EKS using the updated Helm chart
8. Iterate on the deployment until the application is successfully running and accessible
9. Verify the application works by:
   - Testing the health endpoint (`/health`)
   - Creating a test task via the API
   - Listing tasks
   - Completing and deleting tasks

Migration Guidelines:
- Review the migration documentation in the `docs/` folder for best practices
- Use AWS Load Balancer Controller for ingress
- Use Amazon ECR for container images
- Apply Pod Security Standards for security policies
- Maintain the same application functionality as the OpenShift version
- Use the existing Helm chart structure, just update the templates to remove OpenShift-specific resources
- Ensure proper security context (non-root user, dropped capabilities)

Testing Requirements:
- Application must be accessible via the ALB/ingress endpoint
- Health endpoint (`/health`) must return 200 status with proper JSON response
- API endpoints must be functional:
  - `GET /api/tasks` - List all tasks
  - `POST /api/tasks` - Create a new task
  - `PUT /api/tasks/{id}/complete` - Mark task as complete
  - `DELETE /api/tasks/{id}` - Delete a task
- Application must run with non-root user (UID 1001) and proper security context

Important Notes:
- If you encounter AWS authentication or permission issues, ask me to configure the necessary credentials or permissions
- Document all changes made to the Helm chart and Kubernetes manifests
- Keep track of the ALB/ingress URL for testing

Use the AWS CLI, kubectl, and helm to interact with AWS and EKS.
```

---

## Expected Outcome

After running the prompt, you should have:

1. ✅ EKS cluster created and configured (`task-manager-eks`)
2. ✅ AWS Load Balancer Controller installed on the cluster
3. ✅ ECR repository created with the task-manager image
4. ✅ Application Helm chart migrated to remove OpenShift-specific resources
5. ✅ Application deployed and running on EKS in the `task-manager` namespace
6. ✅ Application Load Balancer provisioned and accessible
7. ✅ Application verified working (health check and API tests passing)

## What Gets Migrated

The migration converts OpenShift-specific resources to their Kubernetes/EKS equivalents:

- **Routes** → Kubernetes Ingress with AWS Load Balancer Controller
- **DeploymentConfig** → Standard Kubernetes Deployment
- **ImageStreams** → Direct ECR image references
- **SecurityContextConstraints** → Pod Security Standards
- **Projects** → Kubernetes Namespaces
- **BuildConfig** → External CI/CD (not needed for deployment)
- **Templates** → Helm Charts (already available)

See `OPENSHIFT_FEATURES_SUMMARY.md` for detailed conversion information.

## Troubleshooting

### AWS Authentication Issues
```bash
# Verify AWS credentials
aws sts get-caller-identity

# Check region
echo $AWS_DEFAULT_REGION
```

### EKS Cluster Issues
```bash
# List clusters
aws eks list-clusters

# Get cluster info
aws eks describe-cluster --name task-manager-eks

# Update kubeconfig
aws eks update-kubeconfig --name task-manager-eks --region $AWS_DEFAULT_REGION
```

### Application Issues
```bash
# Check pods
kubectl get pods -n task-manager

# Check logs
kubectl logs -n task-manager -l app=task-manager

# Check ingress
kubectl get ingress -n task-manager

# Describe ingress for ALB details
kubectl describe ingress task-manager -n task-manager
```

## Cleanup

To remove all AWS resources created during the demo:

```bash
# Delete the application
helm uninstall task-manager -n task-manager
kubectl delete namespace task-manager

# Delete the EKS cluster (this will take several minutes)
aws eks delete-cluster --name task-manager-eks

# Delete node group first
aws eks delete-nodegroup --cluster-name task-manager-eks --nodegroup-name <nodegroup-name>

# Delete ECR repository
aws ecr delete-repository --repository-name task-manager --force

# Or use eksctl if available
eksctl delete cluster --name task-manager-eks
```

## Cost Considerations

Running this demo will incur AWS costs:
- **EKS Cluster**: ~$0.10/hour for the control plane
- **EC2 Instances**: ~$0.08/hour for 2x t3.medium instances
- **Application Load Balancer**: ~$0.025/hour + data transfer
- **ECR Storage**: Minimal for a single image

**Estimated cost**: ~$0.20-0.30/hour while running

**💡 Tip**: Delete resources when not in use to minimize costs.

## Learn More

- [OpenShift to EKS Migration Guide](./openshift-task-manager/OPENSHIFT_TO_EKS_MIGRATION.md)
- [OpenShift Features Summary](./OPENSHIFT_FEATURES_SUMMARY.md)
- [Quick Start Guide](./docs/QUICKSTART.md)
- [Architecture Documentation](./docs/ARCHITECTURE.md)
- [Final Summary](./docs/FINAL_SUMMARY.md)

## License

This is a demonstration project for educational purposes.

## Support

For issues or questions:
1. Check the troubleshooting section above
2. Review the detailed migration guide in `openshift-task-manager/OPENSHIFT_TO_EKS_MIGRATION.md`
3. Consult AWS EKS documentation
