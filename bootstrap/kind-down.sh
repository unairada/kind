#!/usr/bin/env bash

# Kill any lingering port-forwards for Keycloak
echo "Checking for background port-forwards..."
pkill -f "kubectl port-forward pod/keycloak-keycloakx-0" || true

echo "Destroying Kind cluster 'kind'..."
kind delete cluster --name kind

echo "Cleanup complete."
