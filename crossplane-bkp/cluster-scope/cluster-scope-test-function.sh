#!/usr/bin/env bash
#

kubectl patch xbuiltinobjects.keycloak.crossplane.io keycloak-builtin-objects-prod -p '{"metadata":{"finalizers":[]}}' --type=merge

kubectl delete xbuiltinobjects.keycloak.crossplane.io keycloak-builtin-objects-prod

kubectl delete deploymentruntimeconfigs.pkg.crossplane.io enable-management-policies

kubectl delete function function-keycloak-builtin-objects

kubectl delete composition keycloak-builtin-objects && kubectl delete xrd xbuiltinobjects.keycloak.crossplane.io


kubectl apply -f kustomize-resources/deployment-runtime-config.yaml

kubectl apply -f functions-composition.yaml

sleep 15

kubectl apply -f cluster-scope/composition.yaml
kubectl apply -f cluster-scope/xrd.yaml
kubectl apply -f cluster-scope/xbuiltinobjects.yaml
