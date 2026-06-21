#!/usr/bin/env bash
# Bootstrap a root Application that syncs apps from your private GitOps repository.

set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=../bin/common.sh
source "${ROOT_DIR}/bin/common.sh"

load_config

namespace="${ARGOCD_NAMESPACE:-argocd}"
repo="${ARGOCD_GITOPS_REPO:-}"
template="${ROOT_DIR}/argocd/bootstrap/root-app.yaml.template"

[[ -n "$repo" ]] || die "Set ARGOCD_GITOPS_REPO in config/config.env."
[[ -f "$template" ]] || die "Missing template: ${template}"

if [[ -n "${KUBECONFIG:-}" ]]; then
  :
elif [[ -r /etc/rancher/k3s/k3s.yaml ]]; then
  export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
elif [[ -r "${HOME}/.kube/config-local-k8s" ]]; then
  export KUBECONFIG="${HOME}/.kube/config-local-k8s"
fi

require_command kubectl

if [[ -n "${ARGOCD_GIT_USERNAME:-}" && -n "${ARGOCD_GIT_PASSWORD:-}" ]]; then
  "${ROOT_DIR}/scripts/argocd-add-repo.sh"
fi

log "Creating root Application for ${repo}..."
sed \
  -e "s|__GITOPS_REPO__|${repo}|g" \
  -e "s|__GITOPS_BRANCH__|${ARGOCD_GITOPS_BRANCH:-main}|g" \
  -e "s|__GITOPS_PATH__|${ARGOCD_GITOPS_PATH:-argocd/applications}|g" \
  -e "s|__ARGOCD_NAMESPACE__|${namespace}|g" \
  "$template" | kubectl apply -f -

log "Root Application created."
log "Argo CD will sync Application CRs from: ${repo} (${ARGOCD_GITOPS_PATH:-argocd/applications})"
