#!/usr/bin/env bash
# Register the private GitOps repository in Argo CD.

set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=../bin/common.sh
source "${ROOT_DIR}/bin/common.sh"

load_config

namespace="${ARGOCD_NAMESPACE:-argocd}"
repo="${ARGOCD_GITOPS_REPO:-}"
secret_name="${ARGOCD_GIT_SECRET_NAME:-gitops-repo}"

[[ -n "$repo" ]] || die "Set ARGOCD_GITOPS_REPO in config/config.env to your private GitOps repository URL."
[[ -n "${ARGOCD_GIT_USERNAME:-}" ]] || die "Set ARGOCD_GIT_USERNAME in config/config.env."
[[ -n "${ARGOCD_GIT_PASSWORD:-}" ]] || die "Set ARGOCD_GIT_PASSWORD in config/config.env (use a personal access token)."

if [[ -n "${KUBECONFIG:-}" ]]; then
  :
elif [[ -r /etc/rancher/k3s/k3s.yaml ]]; then
  export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
elif [[ -r "${HOME}/.kube/config-local-k8s" ]]; then
  export KUBECONFIG="${HOME}/.kube/config-local-k8s"
fi

require_command kubectl

log "Registering GitOps repository in Argo CD..."
kubectl create secret generic "$secret_name" \
  -n "$namespace" \
  --from-literal=type=git \
  --from-literal=url="$repo" \
  --from-literal=username="$ARGOCD_GIT_USERNAME" \
  --from-literal=password="$ARGOCD_GIT_PASSWORD" \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl label secret "$secret_name" \
  -n "$namespace" \
  argocd.argoproj.io/secret-type=repository \
  --overwrite

log "Repository registered: ${repo}"
log "Add Application CRs in your GitOps repo, or run ./scripts/argocd-bootstrap-apps.sh to deploy a root app."
