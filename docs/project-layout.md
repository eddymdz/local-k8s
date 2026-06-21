# Project layout

```
local-k8s/
├── install.sh              # Main entry point
├── bootstrap.sh            # curl-friendly wrapper
├── bin/
│   ├── common.sh
│   ├── prepare-host.sh
│   ├── install-cli-tools.sh
│   ├── install-argocd.sh
│   ├── install-server.sh
│   └── install-agent.sh
├── argocd/
│   └── bootstrap/          # Optional root-app template
├── config/
│   └── config.env.example
├── docs/
└── scripts/
    ├── get-kubeconfig.sh
    ├── get-node-token.sh
    ├── argocd-admin-password.sh
    ├── argocd-login.sh
    ├── argocd-add-repo.sh
    ├── argocd-bootstrap-apps.sh
    └── uninstall.sh
```
