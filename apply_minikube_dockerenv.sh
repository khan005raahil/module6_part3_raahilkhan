#!/usr/bin/env bash

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
K8S_DIR="$PROJECT_DIR/k8s"

print_step() {
  echo
  echo "============================================================"
  echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
  echo "============================================================"
}

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "ERROR: Required command '$1' is not installed."
    exit 1
  fi
}

print_step "Checking required tools"

require_command docker
require_command kubectl
require_command minikube

if ! docker info >/dev/null 2>&1; then
  echo "ERROR: Docker Desktop is not running."
  exit 1
fi

if [ ! -d "$K8S_DIR" ]; then
  echo "ERROR: Kubernetes directory not found: $K8S_DIR"
  exit 1
fi

print_step "Starting Minikube"

if ! minikube status >/dev/null 2>&1; then
  minikube start --driver=docker
else
  echo "Minikube is already running."
fi

print_step "Enabling Metrics Server"

minikube addons enable metrics-server || true

print_step "Connecting to Minikube Docker daemon"

eval "$(minikube docker-env)"

print_step "Building backend image"

docker build -t backend:latest "$PROJECT_DIR/backend"

print_step "Building transactions image"

docker build -t transactions:latest "$PROJECT_DIR/transactions"

print_step "Building studentportfolio image"

docker build -t studentportfolio:latest "$PROJECT_DIR/studentportfolio"

print_step "Verifying images inside Minikube"

docker image inspect backend:latest >/dev/null
docker image inspect transactions:latest >/dev/null
docker image inspect studentportfolio:latest >/dev/null

docker images | grep -E 'backend|transactions|studentportfolio'

print_step "Validating Kubernetes manifests"

kubectl apply --dry-run=client -f "$K8S_DIR"

print_step "Applying Kubernetes manifests"

kubectl apply -f "$K8S_DIR"

print_step "Restarting deployments"

kubectl rollout restart deployment/backend
kubectl rollout restart deployment/transactions
kubectl rollout restart deployment/studentportfolio
kubectl rollout restart deployment/nginx

print_step "Waiting for MongoDB"

kubectl rollout status statefulset/mongo --timeout=300s

print_step "Waiting for backend"

kubectl rollout status deployment/backend --timeout=300s

print_step "Waiting for transactions"

kubectl rollout status deployment/transactions --timeout=300s

print_step "Waiting for studentportfolio"

kubectl rollout status deployment/studentportfolio --timeout=300s

print_step "Waiting for nginx"

kubectl rollout status deployment/nginx --timeout=300s

print_step "Kubernetes pods"

kubectl get pods

print_step "Kubernetes services"

kubectl get services

print_step "Horizontal Pod Autoscalers"

kubectl get hpa

print_step "Deployment completed successfully"

echo
echo "Open the application using:"
echo "minikube service nginx"