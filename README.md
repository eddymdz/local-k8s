# local-k8s

Bootstrap a [k3s](https://k3s.io/) cluster on Debian-based Linux. Requires only `curl`, `git`, `bash`, and `sudo`.

## Quick start

```bash
git clone https://github.com/eddymdz/local-k8s
cd local-k8s
cp config/config.env.example config/config.env

sudo ./install.sh server          # control plane
sudo ./install.sh agent           # worker nodes (set K3S_URL + K3S_TOKEN first)

./scripts/get-kubeconfig.sh
export KUBECONFIG=$HOME/.kube/config-local-k8s
kubectl get nodes
```

On worker nodes, set in `config/config.env` before running `agent`:

```bash
K3S_URL=https://<control-plane-ip>:6443
K3S_TOKEN=<token-from-server>     # ./scripts/get-node-token.sh on the server
```

## Commands

| Command | Description |
|---------|-------------|
| `sudo ./install.sh prepare` | Prepare the host (swap, sysctl, packages) |
| `sudo ./install.sh server` | Install control plane |
| `sudo ./install.sh agent` | Join as worker |
| `sudo ./install.sh tools` | Install kubectl, k9s, helm, etc. |
| `./install.sh argocd` | Install Argo CD |
| `sudo ./install.sh uninstall` | Remove k3s from this node |

Helper scripts: `scripts/get-kubeconfig.sh`, `scripts/get-node-token.sh`, `scripts/argocd-add-repo.sh`

## Documentation

| Topic | Guide |
|-------|-------|
| Configuration options | [docs/configuration.md](docs/configuration.md) |
| Argo CD & private GitOps repo | [docs/argocd.md](docs/argocd.md) |
| CLI tools (kubectl, k9s, helm…) | [docs/cli-tools.md](docs/cli-tools.md) |
| Host preparation | [docs/host-preparation.md](docs/host-preparation.md) |
| Install without git clone | [docs/bootstrap.md](docs/bootstrap.md) |
| High availability | [docs/high-availability.md](docs/high-availability.md) |
| Troubleshooting | [docs/troubleshooting.md](docs/troubleshooting.md) |
| Project layout | [docs/project-layout.md](docs/project-layout.md) |

## License

MIT
