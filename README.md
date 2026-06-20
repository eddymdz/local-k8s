# local-k8s

Bootstrap a local Kubernetes cluster with [k3s](https://k3s.io/) on Debian-based Linux. You only need common tools already present on most systems: `curl`, `git`, `bash`, and `sudo`.

## Quick start

### 1. Clone and configure

```bash
git clone https://github.com/YOUR_USER/local-k8s.git
cd local-k8s
cp config/config.env.example config/config.env
# Edit config/config.env for your environment
```

### 2. Install the control plane (first node)

On the machine that will run the API server and etcd:

```bash
sudo ./install.sh server
```

When it finishes, save the join token printed at the end (also stored in `/var/lib/local-k8s/node-token` on the server).

### 3. Install worker nodes

On each additional machine:

```bash
git clone https://github.com/YOUR_USER/local-k8s.git
cd local-k8s
cp config/config.env.example config/config.env
```

Set these in `config/config.env`:

```bash
K3S_URL=https://<control-plane-ip>:6443
K3S_TOKEN=<token-from-server>
```

Then run:

```bash
sudo ./install.sh agent
```

### 4. Use the cluster

On the control plane node:

```bash
./scripts/get-kubeconfig.sh
export KUBECONFIG=$HOME/.kube/config-local-k8s
kubectl get nodes
k9s
```

### Admin tools installed on the VM

After `server` or `tools`, these CLI utilities are available:

| Tool | Purpose |
|------|---------|
| `kubectl` | Kubernetes command line |
| `k9s` | Terminal UI to browse and manage the cluster |
| `helm` | Install and manage Helm charts |
| `kustomize` | Build Kubernetes manifests without templates |
| `stern` | Tail logs from multiple pods at once |
| `kubectx` / `kubens` | Switch contexts and namespaces quickly |
| `jq` / `yq` | Parse JSON and YAML output |

Reinstall or update tools anytime:

```bash
sudo ./install.sh tools
```

Set `INSTALL_CLI_TOOLS_ON_AGENTS=false` in `config/config.env` if you only want admin tools on the control plane.

## One-liner bootstrap (no git clone)

If you only have `curl` and `sudo`, you can fetch and run the installer directly:

```bash
curl -fsSL https://raw.githubusercontent.com/YOUR_USER/local-k8s/main/bootstrap.sh | sudo bash -s -- server
```

For a worker (set URL and token first):

```bash
export K3S_URL=https://192.168.1.10:6443
export K3S_TOKEN=K10abc...
curl -fsSL https://raw.githubusercontent.com/YOUR_USER/local-k8s/main/bootstrap.sh | sudo -E bash -s -- agent
```

## Project layout

```
local-k8s/
├── install.sh              # Main entry point (server | agent | uninstall)
├── bootstrap.sh            # curl-friendly wrapper (downloads repo, runs install)
├── bin/
│   ├── common.sh           # Shared helpers and prerequisite checks
│   ├── prepare-host.sh     # Swap, sysctl, modules, packages, firewall
│   ├── install-cli-tools.sh # kubectl, k9s, helm, and other admin tools
│   ├── install-server.sh   # Control plane installation
│   └── install-agent.sh    # Worker node installation
├── config/
│   └── config.env.example  # Configuration template
└── scripts/
    ├── get-kubeconfig.sh   # Copy kubeconfig for local kubectl use
    ├── get-node-token.sh   # Print the agent join token (server only)
    └── uninstall.sh        # Remove k3s from this node
```

## Configuration

Copy `config/config.env.example` to `config/config.env` and adjust values. Environment variables override the config file.

| Variable | Default | Description |
|----------|---------|-------------|
| `K3S_VERSION` | *(latest)* | Pin a k3s release, e.g. `v1.32.3+k3s1` |
| `K3S_CHANNEL` | `stable` | Install channel: `stable`, `latest`, or a version channel |
| `K3S_TOKEN` | *(auto on server)* | Shared cluster secret; required on agents |
| `K3S_URL` | *(server IP)* | API server URL; required on agents |
| `K3S_NODE_NAME` | hostname | Kubernetes node name |
| `K3S_CLUSTER_INIT` | `false` | Set `true` for embedded etcd HA (first server) |
| `K3S_SERVER_FLAGS` | *(empty)* | Extra flags passed to `k3s server` |
| `K3S_AGENT_FLAGS` | *(empty)* | Extra flags passed to `k3s agent` |
| `INSTALL_KUBECTL` | `true` | Install standalone `kubectl` on the node |
| `KUBECTL_VERSION` | *(match k8s)* | kubectl version to install |
| `INSTALL_CLI_TOOLS` | `true` | Install admin CLI tools (kubectl, k9s, helm, etc.) |
| `INSTALL_CLI_TOOLS_ON_AGENTS` | `true` | Install CLI tools on worker nodes |
| `INSTALL_K9S` | `true` | Install [k9s](https://k9scli.io/) terminal UI |
| `INSTALL_HELM` | `true` | Install [Helm](https://helm.sh/) package manager |
| `INSTALL_KUSTOMIZE` | `true` | Install [Kustomize](https://kustomize.io/) |
| `INSTALL_STERN` | `true` | Install [stern](https://github.com/stern/stern) log tailer |
| `INSTALL_KUBECTX` | `true` | Install kubectx/kubens context switchers |
| `INSTALL_JQ` | `true` | Install jq for JSON parsing |
| `INSTALL_YQ` | `true` | Install yq for YAML parsing |
| `INSTALL_SHELL_COMPLETION` | `true` | kubectl/helm bash completion and KUBECONFIG helper |
| `PREPARE_HOST` | `true` | Run host preparation before install |
| `DISABLE_SWAP` | `true` | Run `swapoff -a` before install |
| `PERSIST_SWAP_OFF` | `true` | Comment swap entries in `/etc/fstab` |
| `INSTALL_BASE_PACKAGES` | `true` | Install iptables, conntrack, etc. via apt |
| `CONFIGURE_FIREWALL` | `true` | Open k3s ports in UFW when active |
| `INSTALL_ISCSI` | `false` | Install `open-iscsi` for block storage |

## Commands

```bash
# Prepare host only (optional; also runs before server/agent install)
sudo ./install.sh prepare

# Control plane
sudo ./install.sh server

# Worker node
sudo ./install.sh agent

# Admin CLI tools only (kubectl, k9s, helm, kustomize, stern, kubectx, jq, yq)
sudo ./install.sh tools

# Remove k3s from this machine
sudo ./install.sh uninstall

# Show join token (run on server)
./scripts/get-node-token.sh

# Copy kubeconfig to ~/.kube/config-local-k8s
./scripts/get-kubeconfig.sh
```

## Prerequisites

- Debian, Ubuntu, or another Debian-based distribution
- `curl`, `git`, `bash`, `sudo`
- Root or passwordless sudo
- Control plane reachable on TCP **6443** from worker nodes
- Unique hostname per node (recommended)

### Host preparation (automatic)

Before installing k3s, `server` and `agent` run host preparation automatically. You can also run it alone:

```bash
sudo ./install.sh prepare
```

This applies the standard Kubernetes/k3s requirements:

| Step | Action |
|------|--------|
| Swap | `swapoff -a` and disable swap in `/etc/fstab` |
| Kernel modules | Load `overlay`, `br_netfilter`; persist in `/etc/modules-load.d/local-k8s.conf` |
| Sysctl | Enable IP forwarding and bridge netfilter in `/etc/sysctl.d/99-local-k8s.conf` |
| Packages | Install `iptables`, `conntrack`, `socat`, `kmod`, `iproute2`, and related tools via apt |
| Firewall | Open k3s ports in UFW when it is active (6443, 8472, 10250, 2379–2380 on servers) |
| Checks | Verify cgroups, hostname, and available memory |

Set `PREPARE_HOST=false` in `config/config.env` to skip automatic preparation.

Additional dependencies (container runtime, etc.) are installed by the official k3s installer when needed.

## High availability (optional)

For a multi-server control plane with embedded etcd:

1. On the **first** server: set `K3S_CLUSTER_INIT=true` in `config/config.env`, then run `sudo ./install.sh server`.
2. On **additional** servers: set `K3S_URL` and `K3S_TOKEN`, add server flags such as `--cluster-init=false`, and run `sudo ./install.sh server`.
3. Join workers with `sudo ./install.sh agent` as usual.

See the [k3s HA documentation](https://docs.k3s.io/datastore/ha-embedded) for details.

## Troubleshooting

**Agent cannot join**

- Confirm `K3S_URL` uses the control plane IP/hostname, not `127.0.0.1`.
- Open port 6443 on the server firewall.
- Verify the token with `./scripts/get-node-token.sh` on the server.

**kubectl connection refused**

- Run `./scripts/get-kubeconfig.sh` and set `KUBECONFIG`.
- On the server, check `sudo systemctl status k3s`.

**Check logs**

```bash
sudo journalctl -u k3s -f          # control plane
sudo journalctl -u k3s-agent -f    # worker
```

## License

MIT
