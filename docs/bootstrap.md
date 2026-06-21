# Bootstrap without git clone

If a machine only has `curl` and `sudo`:

```bash
export LOCAL_K8S_REPO=https://github.com/eddymdz/local-k8s.git
curl -fsSL https://raw.githubusercontent.com/eddymdz/local-k8s/main/bootstrap.sh | sudo bash -s -- server
```

For a worker node, set URL and token first:

```bash
export LOCAL_K8S_REPO=https://github.com/eddymdz/local-k8s.git
export K3S_URL=https://192.168.1.10:6443
export K3S_TOKEN=K10abc...
curl -fsSL https://raw.githubusercontent.com/eddymdz/local-k8s/main/bootstrap.sh | sudo -E bash -s -- agent
```

The bootstrap script downloads the repository to `/opt/local-k8s` (override with `LOCAL_K8S_DIR`) and runs `install.sh`.
