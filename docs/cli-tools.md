# CLI tools

After `server` or `tools`, these utilities are installed on the node:

| Tool | Purpose |
|------|---------|
| `kubectl` | Kubernetes command line |
| `k9s` | Terminal UI for the cluster |
| `helm` | Helm chart manager |
| `kustomize` | Manifest builder |
| `stern` | Multi-pod log tailing |
| `kubectx` / `kubens` | Context and namespace switching |
| `jq` / `yq` | JSON and YAML parsing |
| `argocd` | Argo CD CLI (when Argo CD is installed) |

Install or update:

```bash
sudo ./install.sh tools
```

Install on control plane only — set in `config/config.env`:

```bash
INSTALL_CLI_TOOLS_ON_AGENTS=false
```

Toggle individual tools with `INSTALL_K9S=false`, `INSTALL_HELM=false`, etc. See [configuration.md](configuration.md).

Shell completion and a `KUBECONFIG` helper are written to `/etc/profile.d/local-k8s-cli.sh` when `INSTALL_SHELL_COMPLETION=true`.
