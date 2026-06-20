#!/usr/bin/env bash
# Copy k3s kubeconfig for use with a local kubectl client.

set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=../bin/common.sh
source "${ROOT_DIR}/bin/common.sh"

KUBECONFIG_SRC=/etc/rancher/k3s/k3s.yaml
KUBECONFIG_DEST="${KUBECONFIG_DEST:-$HOME/.kube/config-local-k8s}"

read_kubeconfig() {
  if [[ -r "$KUBECONFIG_SRC" ]]; then
    cat "$KUBECONFIG_SRC"
    return 0
  fi
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    sudo cat "$KUBECONFIG_SRC"
    return 0
  fi
  return 1
}

[[ -f "$KUBECONFIG_SRC" || "${EUID:-$(id -u)}" -ne 0 ]] || die "kubeconfig not found at ${KUBECONFIG_SRC}. Is k3s server installed?"

mkdir -p "$(dirname "$KUBECONFIG_DEST")"
read_kubeconfig >"$KUBECONFIG_DEST"
chmod 600 "$KUBECONFIG_DEST"

log "Kubeconfig written to ${KUBECONFIG_DEST}"
log "Run: export KUBECONFIG=${KUBECONFIG_DEST}"
