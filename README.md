# Local Kubernetes lab

Run a two-node Kind cluster with Cilium for networking and load balancing, and Envoy Gateway for HTTP routing.

## Start the cluster

Start your Docker engine and put `docker`, `kind`, `helm`, and `kubectl` on your `PATH`. Use `kubectl` 1.36 or later for the combined CRD readiness check.

From the repository root, use the command below. You can also invoke the script by its path from another directory.

```sh
./bootstrap/up.sh
```

The script creates or reuses `gitops-lab` with the topology in [bootstrap/kind.yaml](bootstrap/kind.yaml). New clusters use the default node image for your installed Kind release. Cilium replaces Kind's default CNI and kube-proxy. The script waits for Cilium, the nodes, and CoreDNS, then applies the Cilium load balancer configuration. It installs the Gateway API and Envoy Gateway CRDs before installing the Envoy Gateway controller.

The script writes the `kind-gitops-lab` context to `~/.kube/config`. If your shell points `KUBECONFIG` elsewhere, unset it before running the checks below.

```sh
kubectl --context kind-gitops-lab get nodes
kubectl --context kind-gitops-lab -n kube-system get daemonset cilium
kubectl --context kind-gitops-lab -n envoy-gateway-system get deployment envoy-gateway
```

Expect two Ready nodes, two Ready Cilium agents, and one available Envoy Gateway controller replica.

## Check the load balancer range

The [Cilium IP pool](cilium-config/lb-ippools.yaml) uses `192.168.97.100` through `192.168.97.200` for the local OrbStack `kind` bridge. Check the subnet before deploying a Gateway.

```sh
docker network inspect kind --format '{{json .IPAM.Config}}'
```

If your subnet differs, update the pool range and rerun the bootstrap. The pool does not reserve those addresses in Docker. To avoid collisions, configure the bridge so Docker allocates container IPs from a separate range.

## Deploy your first application

Deploy a backend and its Service, then create a GatewayClass, a Gateway named `eg`, and an HTTPRoute that points to the backend Service. Use the sample application in the [Envoy Gateway quickstart](https://gateway.envoyproxy.io/v1.10/tasks/quickstart/).

The IP pool and [L2 announcement policy](cilium-config/l2-announcement-policy.yaml) both select Services generated for a Gateway named `eg`. If you use a different name, update both selectors.

Attach an `EnvoyProxy` to the Gateway and set `spec.provider.kubernetes.envoyService.externalTrafficPolicy` to `Cluster`. The announcement policy selects worker nodes, and `Cluster` lets the announcing node forward requests to Envoy pods on other nodes. [EnvoyProxy configuration](https://gateway.envoyproxy.io/v1.10/tasks/operations/customize-envoyproxy/) · [Cilium L2 announcements](https://docs.cilium.io/en/stable/network/l2-announcements/)

Once the Gateway is programmed, look for an external IP on its generated Service.

```sh
kubectl --context kind-gitops-lab -n envoy-gateway-system get svc \
  -l gateway.envoyproxy.io/owning-gateway-name=eg
```

Test the external IP from a client on the Docker bridge. For macOS access, use [port forwarding to the generated Envoy Service](https://gateway.envoyproxy.io/v1.10/tasks/quickstart/#testing-the-configuration). Send the hostname from your HTTPRoute in the request.
