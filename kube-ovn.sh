#!/usr/bin/env bash
# set -o errexit
# set -o nounset
# set -o pipefail

kubectl label node kind-worker kube-ovn/role=master
kubectl label node kind-worker2 kube-ovn/role=master
kubectl label node kind-control-plane kube-ovn/role=master

helm repo add kubeovn https://kubeovn.github.io/kube-ovn/
helm upgrade kube-ovn kubeovn/kube-ovn \
  --namespace kube-system \
  --version v1.13.3 \
  --set ipv4.SVC_CIDR="10.100.0.0/16" \
  --set ipv4.CIDR="10.244.0.0/16" \
  --set ipv4.PINGER_EXTERNAL_ADDRESS="8.8.8.8" \
  --set ipv4.PINGER_EXTERNAL_DOMAIN="google.com." \
  --install
