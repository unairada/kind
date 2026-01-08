#!/usr/bin/env bash

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <namespace>" >&2
  exit 1
fi

ns="$1"

echo "Running function-keycloak-builtin-objects test in namespace ${ns}"

kubectl patch xbuiltinobjects.keycloak.crossplane.io keycloak-builtin-objects-prod \
    -n "$ns" \
    -p '{"metadata":{"finalizers":[]}}' \
    --type=merge

kubectl delete -n "$ns" xbuiltinobjects.keycloak.crossplane.io keycloak-builtin-objects-prod

kubectl delete deploymentruntimeconfigs.pkg.crossplane.io enable-management-policies

kubectl delete function function-keycloak-builtin-objects

kubectl delete composition keycloak-builtin-objects && kubectl delete xrd xbuiltinobjects.keycloak.crossplane.io


kubectl apply -f ../kustomize-resources/deployment-runtime-config.yaml

kubectl apply -f ../functions-composition.yaml

sleep 15

kubectl apply -f ./composition.yaml
kubectl apply -f ./xrd.yaml
kubectl apply -f ./xbuiltinobjects.yaml

kubectl get xbuiltinobjects.keycloak.crossplane.io -n "$ns"
