#!/usr/bin/env bash
set -e # Exit on error

# --- Path Configuration ---
# This ensures the script works no matter where you run it from
GIT_ROOT=$(git rev-parse --show-toplevel)
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
CONFIG_DIR="${GIT_ROOT}/config-infra"

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
# 3. HELMFILE LAYER (Helmfiles)
# ====================================================
echo "Installing Operators..."
helmfile -f "${CONFIG_DIR}/helmfiles/operators-helmfile.yaml" apply

echo "Waiting for CNPG Operator..."
kubectl wait --for=condition=Available deployment -l app.kubernetes.io/name=cloudnative-pg -n cnpg-system --timeout=300s

echo "Waiting for Crossplane..."
kubectl wait --for=condition=Available deployment -l app.kubernetes.io/instance=crossplane -n crossplane-system --timeout=300s

echo "Installing Crossplane Keycloak Provider..."
kubectl apply -f "${CONFIG_DIR}/provider-keycloak.yaml"
kubectl wait --for=condition=Healthy provider.pkg.crossplane.io/provider-keycloak --timeout=300s

echo "Deploying Database Infrastructure..."
kubectl create secret generic keycloak-db-creds \
  --from-literal=username="keycloak" \
  --from-literal=password="keycloak" \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl apply -f "${GIT_ROOT}/apps/keycloak-db/cluster.yaml"

echo "Waiting for Postgres Cluster to be Ready..."
# Wait for the cluster status to report 'Phase: Cluster in healthy state' or similar readiness
# The most reliable way for CNPG is checking the 'Ready' condition on the Cluster resource if available,
# or waiting for the primary instance pod.
kubectl wait --for=condition=Ready cluster.postgresql.cnpg.io/keycloak-postgres -n default --timeout=300s

echo "Deploying Keycloak..."
# Create admin credentials for Keycloak
kubectl create secret generic keycloak-admin \
  --from-literal=password="admin" \
  --dry-run=client -o yaml | kubectl apply -f -

helmfile -f "${CONFIG_DIR}/helmfiles/apps-helmfile.yaml" apply

echo "Waiting for Keycloak to be Ready..."
kubectl wait --for=condition=Ready pod/keycloak-keycloakx-0 -n default --timeout=300s

echo "Setup complete!"

echo "Port forwarding Keycloak..."
kubectl port-forward pod/keycloak-keycloakx-0 8080:8080 -n default > /dev/null 2>&1 &
PF_PID=$!

echo "===================================================="
echo "Keycloak is now available at http://localhost:8080"
echo "Admin Console: http://localhost:8080/admin"
echo "Credentials: admin / admin"
echo "----------------------------------------------------"
echo "Port-forwarding is running in the background (PID: $PF_PID)."
echo "You can stop it with: kill $PF_PID"
echo "===================================================="
