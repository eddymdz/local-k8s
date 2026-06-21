# Argo CD

This project installs **Argo CD only**. Application manifests live in a **separate private GitOps repository**.

## Install

Argo CD runs automatically after the control plane when `INSTALL_ARGOCD=true` (default), or on its own:

```bash
./install.sh argocd
```

Skip it during server install and add it later:

```bash
INSTALL_ARGOCD=false sudo ./install.sh server
./install.sh argocd
```

## Access the UI

```bash
http://<control-plane-ip>:30080

./scripts/argocd-admin-password.sh   # user: admin
./scripts/argocd-login.sh
```

## Connect your private GitOps repo

Set credentials in `config/config.env`:

```bash
ARGOCD_GITOPS_REPO=https://github.com/YOUR_ORG/your-gitops.git
ARGOCD_GIT_USERNAME=your-user
ARGOCD_GIT_PASSWORD=ghp_your_token
```

Register the repo:

```bash
./scripts/argocd-add-repo.sh
```

## Bootstrap apps (optional)

To sync Application CRs from a folder in your private repo:

```bash
ARGOCD_GITOPS_PATH=argocd/applications
ARGOCD_GITOPS_BRANCH=main
./scripts/argocd-bootstrap-apps.sh
```

Or set `ARGOCD_BOOTSTRAP_GITOPS=true` in config before install.

## Suggested repo layout

```
your-gitops/
├── argocd/applications/   # Application CRs
└── apps/                  # Kubernetes manifests per app
```

Manage apps by creating Application CRs in your private repo or via the Argo CD UI/CLI.
