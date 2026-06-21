#!/usr/bin/env bash
# Print the initial Argo CD admin password.

set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=../bin/common.sh
source "${ROOT_DIR}/bin/common.sh"

load_config

namespace="${ARGOCD_NAMESPACE:-argocd}"

if [[ -n "${KUBECONFIG:-}" ]]; then
  :
elif [[ -r /etc/rancher/k3s/k3s.yaml ]]; then
  export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
elif [[ -r "${HOME}/.kube/config-local-k8s" ]]; then
  export KUBECONFIG="${HOME}/.kube/config-local-k8s"
fi

require_command kubectl

password=$(kubectl get secret argocd-initial-admin-secret -n "$namespace" \
  -o jsonpath='{.data.password}' 2>/dev/null | base64 -d) || \
  die "Could not read admin password. Is Argo CD installed in namespace ${namespace}?"

echo "$password"
