# Configuration

Copy `config/config.env.example` to `config/config.env`. Environment variables override the config file.

## Cluster

| Variable | Default | Description |
|----------|---------|-------------|
| `K3S_VERSION` | *(latest)* | Pin a k3s release, e.g. `v1.32.3+k3s1` |
| `K3S_CHANNEL` | `stable` | Install channel: `stable`, `latest`, or a version channel |
| `K3S_TOKEN` | *(auto on server)* | Shared cluster secret; required on agents |
| `K3S_URL` | *(server IP)* | API server URL; required on agents |
| `K3S_NODE_NAME` | hostname | Kubernetes node name |
| `K3S_NODE_IP` | auto-detected | Advertised IP for the API server |
| `K3S_CLUSTER_INIT` | `false` | Set `true` for embedded etcd HA (first server) |
| `K3S_SERVER_FLAGS` | *(empty)* | Extra flags passed to `k3s server` |
| `K3S_AGENT_FLAGS` | *(empty)* | Extra flags passed to `k3s agent` |

## Host preparation

| Variable | Default | Description |
|----------|---------|-------------|
| `PREPARE_HOST` | `true` | Run host preparation before install |
| `DISABLE_SWAP` | `true` | Run `swapoff -a` before install |
| `PERSIST_SWAP_OFF` | `true` | Comment swap entries in `/etc/fstab` |
| `INSTALL_BASE_PACKAGES` | `true` | Install iptables, conntrack, etc. via apt |
| `CONFIGURE_FIREWALL` | `true` | Open k3s ports in UFW when active |
| `INSTALL_ISCSI` | `false` | Install `open-iscsi` for block storage |

See [host-preparation.md](host-preparation.md) for details.

## CLI tools

| Variable | Default | Description |
|----------|---------|-------------|
| `INSTALL_CLI_TOOLS` | `true` | Install admin CLI tools |
| `INSTALL_CLI_TOOLS_ON_AGENTS` | `true` | Install CLI tools on worker nodes |
| `INSTALL_KUBECTL` | `true` | Install `kubectl` |
| `KUBECTL_VERSION` | *(match k8s)* | kubectl version to install |
| `INSTALL_K9S` | `true` | Install [k9s](https://k9scli.io/) |
| `INSTALL_HELM` | `true` | Install [Helm](https://helm.sh/) |
| `INSTALL_KUSTOMIZE` | `true` | Install [Kustomize](https://kustomize.io/) |
| `INSTALL_STERN` | `true` | Install [stern](https://github.com/stern/stern) |
| `INSTALL_KUBECTX` | `true` | Install kubectx/kubens |
| `INSTALL_JQ` | `true` | Install jq |
| `INSTALL_YQ` | `true` | Install yq |
| `INSTALL_SHELL_COMPLETION` | `true` | Bash completion and KUBECONFIG helper |

See [cli-tools.md](cli-tools.md) for details.

## Argo CD

| Variable | Default | Description |
|----------|---------|-------------|
| `INSTALL_ARGOCD` | `true` | Install Argo CD after control plane setup |
| `ARGOCD_NAMESPACE` | `argocd` | Namespace for Argo CD |
| `ARGOCD_VERSION` | `stable` | Manifest version (`stable` or tag like `v2.14.5`) |
| `ARGOCD_SERVER_EXPOSE` | `nodeport` | `nodeport`, `ingress`, or `clusterip` |
| `ARGOCD_SERVER_INSECURE` | `true` | HTTP access for local NodePort/Ingress |
| `ARGOCD_NODEPORT_HTTP` | `30080` | NodePort for HTTP UI |
| `ARGOCD_NODEPORT_HTTPS` | `30443` | NodePort for HTTPS UI |
| `ARGOCD_INGRESS_HOST` | `argocd.local` | Hostname when using Ingress |
| `ARGOCD_BOOTSTRAP_GITOPS` | `false` | Auto-create root Application during install |
| `ARGOCD_GITOPS_REPO` | *(unset)* | Private GitOps repository URL |
| `ARGOCD_GITOPS_PATH` | `argocd/applications` | Path to Application CRs in that repo |
| `ARGOCD_GITOPS_BRANCH` | `main` | Git branch to track |
| `ARGOCD_GIT_USERNAME` | *(unset)* | Git username for private repos |
| `ARGOCD_GIT_PASSWORD` | *(unset)* | Git token for private repos |
| `INSTALL_ARGOCD_CLI` | `true` | Install `argocd` CLI binary |

See [argocd.md](argocd.md) for setup and GitOps workflow.
