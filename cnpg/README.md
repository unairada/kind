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
