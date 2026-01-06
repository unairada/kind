#!/usr/bin/env bash
set -e # Exit on error

# --- Path Configuration ---
# This ensures the script works no matter where you run it from
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
CONFIG_DIR="${SCRIPT_DIR}/../config"

echo "Starting Platform Bootstrap..."

# ====================================================
# 1. INFRASTRUCTURE LAYER (Kind)
# ====================================================
if kind get clusters | grep -q "^kind$"; then
    echo "Cluster 'kind' already exists."
else
    echo "Creating Kind cluster..."
    kind create cluster --config "${CONFIG_DIR}/kind-config.yaml"
fi

# ====================================================
# 2. NETWORK LAYER (Kube-OVN & CoreDNS)
# ====================================================
echo "Installing Kube-OVN..."

# Label nodes
kubectl label node kind-worker kube-ovn/role=master --overwrite > /dev/null
kubectl label node kind-worker2 kube-ovn/role=master --overwrite > /dev/null
kubectl label node kind-control-plane kube-ovn/role=master --overwrite > /dev/null

# Install Kube-OVN Helm Chart
helm repo add kubeovn https://kubeovn.github.io/kube-ovn/ > /dev/null
helm repo update > /dev/null
helm upgrade --install kube-ovn kubeovn/kube-ovn \
  --namespace kube-system \
  --version v1.13.3 \
  --set ipv4.SVC_CIDR="10.100.0.0/16" \
  --set ipv4.CIDR="10.244.0.0/16" \
  --set ipv4.PINGER_EXTERNAL_ADDRESS="8.8.8.8" \
  --set ipv4.PINGER_EXTERNAL_DOMAIN="google.com." \
  --wait

# CRITICAL WAIT: Wait for Nodes to be Ready before proceeding
echo "Waiting for Network (Nodes to become Ready)..."
kubectl wait --for=condition=Ready nodes --all --timeout=300s
echo "Network is Up."

echo "Patching CoreDNS..."
kubectl apply -f "${CONFIG_DIR}/coredns-patch.yaml"
kubectl -n kube-system rollout restart deployment coredns
kubectl -n kube-system rollout status deployment coredns --timeout=60s

# ====================================================
# 3. GITOPS LAYER (ArgoCD)
# ====================================================
echo "Installing ArgoCD..."
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo "Waiting for ArgoCD Server..."
kubectl wait --for=condition=Available deployment/argocd-server -n argocd --timeout=300s

echo "Patching ArgoCD Service to access locally..."
kubectl patch svc argocd-server -n argocd -p \
  '{"spec": {"type": "NodePort", "ports": [{"name": "http", "nodePort": 30080, "port": 80, "protocol": "TCP", "targetPort": 8080}, {"name": "https", "nodePort": 30443, "port": 443, "protocol": "TCP", "targetPort": 8080}]}}'
