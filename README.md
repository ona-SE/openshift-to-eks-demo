# OpenShift to EKS Migration Demo

This repository demonstrates how to use Ona AI to migrate an OpenShift application to Amazon EKS with a single prompt.

## Overview

This demo showcases:
- **One-shot migration**: A single prompt that migrates a complete OpenShift application to EKS
- **OpenShift feature conversion**: Automatic conversion of Routes, DeploymentConfigs, ImageStreams, and SecurityContextConstraints
- **AWS infrastructure setup**: Automated EKS cluster creation, ECR setup, and Load Balancer Controller installation
- **End-to-end deployment**: From source code to running application on EKS

## Source Application

The demo uses the **OpenShift Task Manager** application from the [shift-eks](https://github.com/gitpod-samples/shift-eks) repository, which includes:
- A Flask-based task management application using OpenShift-specific features
- Complete documentation of OpenShift features that need migration
- Helm charts with OpenShift-specific resources

## What's Included

- **`migrated-helm-chart/`** - Example of the migrated Helm chart (EKS-compatible)
- **Migration prompt** - Ready-to-use prompt for Ona AI (see below)
- **Documentation** - This README with setup instructions

## Prerequisites

### Required Environment Variables

Set these environment variables in your development environment:

```bash
# AWS Credentials (required)
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_SESSION_TOKEN="your-session-token"  # if using temporary credentials
export AWS_DEFAULT_REGION="us-east-2"  # or your preferred region
```

### AWS Permissions Required

Your AWS credentials need permissions for:
- ✅ EKS cluster creation and management (`eksctl`)
- ✅ ECR repository creation and image push
- ✅ Application Load Balancer creation
- ✅ IAM role and policy management (for OIDC provider and service accounts)
- ✅ VPC and networking resources
- ✅ EC2 instance management (for EKS nodes)
- ✅ CloudFormation stack management

### Recommended IAM Policies

Attach these AWS managed policies to your IAM user/role:
- `AmazonEKSClusterPolicy`
- `AmazonEKSWorkerNodePolicy`
- `AmazonEC2ContainerRegistryFullAccess`
- `ElasticLoadBalancingFullAccess`
- `IAMFullAccess` (or specific permissions for role creation)
- `AmazonVPCFullAccess`
- `AWSCloudFormationFullAccess`

**Note**: For production use, create a custom IAM policy with least-privilege permissions.

## OpenShift to EKS Feature Mapping

The migration converts these OpenShift-specific features to EKS equivalents:

| Feature | OpenShift API | EKS Equivalent |
|---------|---------------|----------------|
| Routes | `route.openshift.io/v1` | Kubernetes Ingress + AWS ALB Controller |
| DeploymentConfig | `apps.openshift.io/v1` | Kubernetes Deployment |
| ImageStreams | `image.openshift.io/v1` | Amazon ECR |
| SecurityContextConstraints | `security.openshift.io/v1` | Pod Security Standards |
| Projects | `project.openshift.io/v1` | Kubernetes Namespaces |
| BuildConfig | `build.openshift.io/v1` | External CI/CD |
| Templates | `template.openshift.io/v1` | Helm Charts |

See the [shift-eks repository](https://github.com/gitpod-samples/shift-eks) for detailed documentation of OpenShift features.

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

1. Clone the repository https://github.com/gitpod-samples/shift-eks to examine the OpenShift task-manager application
2. Review the OpenShift-specific features documented in `OPENSHIFT_FEATURES_SUMMARY.md` and the application in `openshift-task-manager/`
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
- Review the migration documentation in the shift-eks `docs/` folder for best practices
- Use AWS Load Balancer Controller for ingress (will be installed automatically)
- Use Amazon ECR for container images
- Apply Pod Security Standards for security policies
- Maintain the same application functionality as the OpenShift version
- Use the existing Helm chart structure from shift-eks, just update the templates to remove OpenShift-specific resources
- Ensure proper security context (non-root user, dropped capabilities)
- Build and push the container image to ECR before deploying
- Save the migrated Helm chart to this repository for reference

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
- If you encounter AWS authentication or permission issues, verify your credentials and IAM permissions
- The migration will take approximately 20-30 minutes (mostly EKS cluster creation)
- Document all changes made to the Helm chart and Kubernetes manifests
- Keep track of the ALB/ingress URL for testing
- Remember to clean up AWS resources after the demo to avoid ongoing costs

Use the AWS CLI, kubectl, helm, and eksctl to interact with AWS and EKS.
```

---

## Expected Outcome

After running the prompt, you should have:

1. ✅ EKS cluster created and configured (`task-manager-eks`)
2. ✅ AWS Load Balancer Controller installed on the cluster with IAM OIDC provider
3. ✅ ECR repository created (`task-manager`)
4. ✅ Container image built and pushed to ECR
5. ✅ Application Helm chart migrated to remove OpenShift-specific resources
6. ✅ Application deployed and running on EKS in the `task-manager` namespace
7. ✅ Application Load Balancer provisioned and accessible
8. ✅ Application verified working (health check and API tests passing)

**Note**: The entire migration process takes approximately 20-30 minutes, with most time spent on EKS cluster creation (15-20 minutes).

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

⚠️ **Important**: Always clean up AWS resources after the demo to avoid ongoing costs.

To remove all AWS resources created during the demo:

```bash
# 1. Delete the Helm release and namespace
helm uninstall task-manager -n task-manager
kubectl delete namespace task-manager

# 2. Delete the EKS cluster (takes 10-15 minutes)
eksctl delete cluster --name task-manager-eks --region us-east-2

# 3. Delete ECR repository
aws ecr delete-repository --repository-name task-manager --force --region us-east-2

# 4. Delete IAM policy
aws iam delete-policy --policy-arn arn:aws:iam::<account-id>:policy/AWSLoadBalancerControllerIAMPolicy
```

**Note**: The `eksctl delete cluster` command will automatically clean up:
- Node groups
- IAM roles and service accounts
- OIDC provider
- VPC and networking resources
- CloudFormation stacks

## Known Limitations

### Container Image Build

The demo may encounter issues building the container image in certain environments (e.g., Gitpod) due to Docker daemon availability. If this occurs:

1. **Build locally**: Use a machine with Docker installed
2. **Use AWS CodeBuild**: Set up a build pipeline
3. **Use GitHub Actions**: Automate builds on commit

See the application's `Dockerfile` in `openshift-task-manager/` for build instructions.

### Time Requirements

- **EKS Cluster Creation**: 15-20 minutes
- **Cluster Deletion**: 10-15 minutes
- **Total Migration Time**: ~30 minutes

## Cost Considerations

Running this demo will incur AWS costs:
- **EKS Cluster**: ~$0.10/hour for the control plane
- **EC2 Instances**: ~$0.08/hour for 2x t3.medium instances
- **Application Load Balancer**: ~$0.025/hour + data transfer
- **ECR Storage**: Minimal for a single image

**Estimated cost**: ~$0.20-0.30/hour while running

**💡 Tip**: Always delete resources immediately after the demo to minimize costs. The cleanup process takes 10-15 minutes.

## Learn More

- [shift-eks Repository](https://github.com/gitpod-samples/shift-eks) - Source OpenShift application
- [OpenShift to EKS Migration Guide](https://github.com/gitpod-samples/shift-eks/blob/main/openshift-task-manager/OPENSHIFT_TO_EKS_MIGRATION.md)
- [OpenShift Features Summary](https://github.com/gitpod-samples/shift-eks/blob/main/OPENSHIFT_FEATURES_SUMMARY.md)
- [Migrated Helm Chart](./migrated-helm-chart/) - Example result of the migration

## License

This is a demonstration project for educational purposes.

## Support

For issues or questions:
1. Check the troubleshooting section above
2. Review the detailed migration guide in `openshift-task-manager/OPENSHIFT_TO_EKS_MIGRATION.md`
3. Consult AWS EKS documentation
