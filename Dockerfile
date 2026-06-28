# Container image for the Task Manager service, targeting standard Kubernetes/EKS.
#
# Differences from the original OpenShift Dockerfile (shift-eks):
#   - OpenShift assigns an arbitrary UID at runtime and relies on group 0
#     ownership. Standard Kubernetes pins a fixed UID/GID, so this image creates a
#     dedicated 1001:1001 user/group that matches the Deployment securityContext
#     (runAsUser/fsGroup: 1001) in k8s/base/deployment.yaml.
#   - Group ownership is set to GID 1001 instead of 0.
FROM python:3.11-slim

WORKDIR /app

# Install dependencies first to leverage layer caching.
COPY app/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code.
COPY app/ .

# Create a fixed non-root user/group (1001:1001) matching the K8s securityContext.
RUN groupadd -g 1001 appgroup && \
    useradd -u 1001 -g 1001 -m -s /sbin/nologin -c "Application user" appuser && \
    chown -R 1001:1001 /app

USER 1001

EXPOSE 8080

# gunicorn binds to PORT (defaults to 8080); the value is supplied via the
# task-manager-config ConfigMap in Kubernetes.
CMD ["gunicorn", "--bind", "0.0.0.0:8080", "--workers", "2", "--timeout", "120", "app:app"]
