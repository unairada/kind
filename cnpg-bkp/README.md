# CNPG

## Install cnpg operator
```
helm repo add cnpg https://cloudnative-pg.github.io/charts
helm repo update

helm upgrade --install cnpg cnpg/cloudnative-pg \
  --namespace cnpg-system \
  --create-namespace
```

## Create secret for keycloak
```
kubectl create secret generic keycloak-db-creds \
  --from-literal=username=keycloak \
  --from-literal=password="$(openssl rand -base64 24)" \
  -n default
```

## Apply cluster.yaml
`$ kubectl apply -f cluster.yaml`

`$ kubectl get pods -l cnpg.io/cluster=keycloak-postgres -w`

## Results

After running these commands, we will have a cnpg postgres cluster running named `keycloak-postgres` with a database named `keycloak`.

These resources will be created:
- `keycloak-postgres` cluster with a `keycloak` database.
- `keycloak-postgres-r`,  `keycloak-postgres-ro` and `keycloak-postgres-rw` services.
- `keycloak-postgres-1` persistent volume claim.
- `keycloak-postgres-ca`, `keycloak-postgres-replication` and `keycloak-postgres-server` secrets.
- `keycloak-postgres` service account.
- `keycloak-postgres` role.
- `keycloak-postgres` role binding.
