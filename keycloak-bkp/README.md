# Keycloak

This installs Keycloak using the codecentric/keycloakx Helm chart and wires it to the existing CloudNativePG (CNPG) PostgreSQL cluster via the provided values file.

## Prerequisites

- A CNPG PostgreSQL cluster named `keycloak-postgres` is running (see `cnpg/README.md`).
- The database secret `keycloak-db-creds` exists in the `default` namespace with:
  - `username: keycloak`
  - `password: <generated password>`
- kubectl is configured to point to your cluster.
- Helm v3 is installed.

## Create admin secret for Keycloak

Create the Keycloak admin password secret. The username is set via values (`KEYCLOAK_ADMIN=admin`), only the password is stored in the secret.

```
kubectl create secret generic keycloak-admin \
  --from-literal=username="admin" \
  --from-literal=password="admin" \
  -n default
```

## Install Keycloak with Helm

```
helm repo add codecentric https://codecentric.github.io/helm-charts
helm repo update

helm upgrade --install keycloak codecentric/keycloakx \
  --namespace default \
  -f keycloakx-cnpg-values.yaml \
  --wait --timeout 10m
```

## Port-forward to Keycloak

```
export POD_NAME=$(kubectl get pods --namespace default -l "app.kubernetes.io/name=keycloakx,app.kubernetes.io/instance=keycloak" -o name)
kubectl --namespace default port-forward "$POD_NAME" 8080
# Visit http://127.0.0.1:8080
```

## Results

After running these commands, we will have a Keycloak instance connected to the CNPG PostgreSQL cluster.

These resources will be created:
- A Keycloak workload in the `default` namespace (managed by the `codecentric/keycloakx` chart).
- A ClusterIP Service for HTTP access (and a headless Service for pod discovery).
- Keycloak configured to use:
  - Database host: `keycloak-postgres-rw.default.svc.cluster.local`
  - Port: `5432`
  - Database: `keycloak`
  - Username: `keycloak`
  - Password from the existing secret `keycloak-db-creds` (key: `password`)
- Admin credentials:
  - Username: `admin`
  - Password from the secret `keycloak-admin` (key: `password`)
