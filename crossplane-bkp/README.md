# Crossplane

## Installation
```
$ kubectl kustomize . --enable-helm  | kubectl apply -f -
```

The `kustomization.yaml` file is used to create a namespace specified in the file `namespace.yaml` and install crossplane using helm. It also sets up the provider for keycloak

## Keycloak provider definition

Uncomment the deployment runtime configutation and the providerConfig from the kustomization resources.

```
$ kubectl kustomize . --enable-helm  | kubectl apply -f -
```

## Composition for xbuiltinobjects

```
$ kubectl apply -f composition.yaml
$ kubectl apply -f functions-composition.yaml
$ kubectl apply -f xrd.yaml
```

##

Setup complete to run the codecentric/keycloakx helm chart using the crossplane-keycloak-realm-helm-values.yaml
