# Local K8s setup with Kind

This repository provides a local Kubernetes environment using Kind (Kubernetes in Docker). It disables the default CNI and installs kube-ovn.

## Setup steps

1) Create a kind cluster

```
$ kind create cluster --config kind-config.yaml
```

2) Update coredns ConfigMap

This step changes the forwarding configuration of CoreDNS to use public DNS servers.

```
$ ./update-coredns-corefile.sh
```

3) Install kube-ovn

This step labels the nodes and installs v1.13.3 of the kubeovn helm chart

```
$ ./kube-ovn.sh
```

4)  Wait for kubeovn pods to be ready

```
$ kubectl get pods -n kube-system -w
```
