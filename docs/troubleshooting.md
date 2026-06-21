# Troubleshooting

## Agent cannot join

- Confirm `K3S_URL` uses the control plane IP/hostname, not `127.0.0.1`.
- Open port 6443 on the server firewall.
- Verify the token: `./scripts/get-node-token.sh` on the server.

## kubectl connection refused

- Run `./scripts/get-kubeconfig.sh` and set `KUBECONFIG`.
- On the server: `sudo systemctl status k3s`.

## Argo CD cannot reach private repo

- Run `./scripts/argocd-add-repo.sh` with `ARGOCD_GIT_USERNAME` and `ARGOCD_GIT_PASSWORD` set in config.
- Use a personal access token as the password, not your account password.

## Logs

```bash
sudo journalctl -u k3s -f          # control plane
sudo journalctl -u k3s-agent -f    # worker
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server
```
