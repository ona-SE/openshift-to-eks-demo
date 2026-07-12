# Task Manager container image for Kubernetes (EKS).
#
# Migrated from the OpenShift build model (BuildConfig + ImageStream) to a
# standard Dockerfile built by external CI/CD and pushed to a registry (ECR).
# Runs as non-root UID 1001 to satisfy the Pod Security Standards "restricted"
# profile applied on the namespace (see k8s/namespace.yaml).
FROM python:3.11-slim

# Do not buffer stdout/stderr so logs stream to kubectl logs immediately.
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PORT=8080

WORKDIR /app

# Install dependencies first for better layer caching.
COPY app/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Application code.
COPY app/ .

# Non-root user. group 0 (root group) with g=u perms keeps the OpenShift
# arbitrary-UID compatibility while running as a fixed UID under Pod Security
# Standards on Kubernetes.
RUN useradd -u 1001 -r -g 0 -m -s /sbin/nologin \
    -c "Application user" appuser && \
    chown -R 1001:0 /app && \
    chmod -R g=u /app

USER 1001

EXPOSE 8080

# gunicorn serves the Flask app defined as `app` in app.py.
CMD ["gunicorn", "--bind", "0.0.0.0:8080", "--workers", "2", "--timeout", "120", "app:app"]
