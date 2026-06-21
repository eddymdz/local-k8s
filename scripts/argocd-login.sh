#!/usr/bin/env bash
# Log in to Argo CD with the CLI.

set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=../bin/common.sh
source "${ROOT_DIR}/bin/common.sh"

load_config

require_command argocd

namespace="${ARGOCD_NAMESPACE:-argocd}"
ip="${K3S_NODE_IP:-$(detect_primary_ip)}"
password=$("${ROOT_DIR}/scripts/argocd-admin-password.sh")

case "${ARGOCD_SERVER_EXPOSE:-nodeport}" in
  nodeport)
    if [[ "${ARGOCD_SERVER_INSECURE:-true}" == "true" ]]; then
      server="http://${ip}:${ARGOCD_NODEPORT_HTTP:-30080}"
    else
      server="https://${ip}:${ARGOCD_NODEPORT_HTTPS:-30443}"
    fi
    ;;
  ingress)
    server="http://${ARGOCD_INGRESS_HOST:-argocd.local}"
    ;;
  *)
    server="${ARGOCD_SERVER:-localhost:8080}"
    warn "Using ${server}. Start port-forward if needed:"
    warn "  kubectl port-forward svc/argocd-server -n ${namespace} 8080:80"
    ;;
esac

log "Logging in to Argo CD at ${server}..."
argocd login "$server" --username admin --password "$password" --insecure

log "Logged in. Try: argocd app list"
