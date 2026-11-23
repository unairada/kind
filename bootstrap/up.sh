#!/usr/bin/env bash
set -euo pipefail

if (( $# != 0 )); then
    printf 'Usage: %s\n' "$0" >&2
    exit 1
fi

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cluster_name=gitops-lab
context="kind-$cluster_name"
cilium_config_dir="$repo_dir/cilium-config"
envoy_helm_chart_version=v1.10.0
cilium_helm_chart_version=1.20.5
cilium_image="quay.io/cilium/cilium:v$cilium_helm_chart_version"
export KUBECONFIG="$HOME/.kube/config"

for tool in docker helm kind kubectl; do
    if ! command -v "$tool" >/dev/null; then
        printf 'Required command not found: %s\n' "$tool" >&2
        exit 1
    fi
done

clusters="$(kind get clusters)"
if grep -Fxq "$cluster_name" <<< "$clusters"; then
    kind export kubeconfig --name "$cluster_name"
    default_networking="$(kubectl --context "$context" --namespace kube-system \
        get daemonset kindnet kube-proxy --ignore-not-found -o name)"
    if [[ -n "$default_networking" ]]; then
        printf 'Cluster %s still has Kind default networking: %s\n' "$cluster_name" "$default_networking" >&2
        printf 'Use a cluster created with bootstrap/kind.yaml for this Cilium setup.\n' >&2
        exit 1
    fi
else
    echo "Creating Kind Cluster..."
    kind create cluster --name "$cluster_name" --config "$repo_dir/bootstrap/kind.yaml"
fi
kubectl --context "$context" label node "$cluster_name-worker" node-role.kubernetes.io/worker=worker --overwrite

echo "Installing Cilium CNI..."

docker pull "$cilium_image"
kind load docker-image "$cilium_image" --name "$cluster_name"

api_host="$(kubectl --context "$context" get node "$cluster_name-control-plane" \
    -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}')"
helm upgrade --install cilium cilium \
    --repo https://helm.cilium.io/ \
    --version "$cilium_helm_chart_version" \
    --kube-context "$context" \
    --namespace kube-system \
    --set image.pullPolicy=IfNotPresent \
    --set ipam.mode=kubernetes \
    --set kubeProxyReplacement=true \
    --set l2announcements.enabled=true \
    --set-string k8sServiceHost="$api_host" \
    --set k8sServicePort=6443

kubectl --context "$context" --namespace kube-system rollout status daemonset/cilium --timeout=120s
kubectl --context "$context" --namespace kube-system rollout status deployment/cilium-operator --timeout=120s
kubectl --context "$context" wait --for=condition=Ready nodes --all --timeout=120s
kubectl --context "$context" --namespace kube-system rollout status deployment/coredns --timeout=120s

kubectl --context "$context" wait --for=create --for=condition=Established --timeout=120s \
    crd/ciliumloadbalancerippools.cilium.io crd/ciliuml2announcementpolicies.cilium.io
kubectl --context "$context" apply -f "$cilium_config_dir"

echo "Installing Envoy Gateway CRDs..."
helm template eg oci://docker.io/envoyproxy/gateway-crds-helm \
    --version "$envoy_helm_chart_version" \
    --set crds.gatewayAPI.enabled=true \
    --set crds.gatewayAPI.channel=standard \
    --set crds.envoyGateway.enabled=true \
    | kubectl --context "$context" apply --server-side -f -

echo "Installing Envoy Gateway..."
helm upgrade --install eg oci://docker.io/envoyproxy/gateway-helm \
    --version "$envoy_helm_chart_version" \
    --kube-context "$context" \
    --namespace envoy-gateway-system \
    --create-namespace \
    --set crds.enabled=false \
    --wait --timeout 5m
