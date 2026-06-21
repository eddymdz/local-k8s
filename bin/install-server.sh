#!/usr/bin/env bash
# Install k3s control plane (server).

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

require_root "$0"
load_config

if systemctl is-active --quiet k3s 2>/dev/null; then
  warn "k3s server is already running on this node."
  if token=$(read_server_token); then
    ip="${K3S_NODE_IP:-$(detect_primary_ip)}"
    print_server_summary "$ip" "$token"
  fi
  exit 0
fi

if [[ "${PREPARE_HOST:-true}" == "true" ]]; then
  "${SCRIPT_DIR}/prepare-host.sh" server
fi

node_ip="${K3S_NODE_IP:-$(detect_primary_ip)}"
node_name="${K3S_NODE_NAME:-$(hostname -s)}"
token="${K3S_TOKEN:-$(generate_token)}"

installer_args=(
  K3S_TOKEN="$token"
  K3S_NODE_NAME="$node_name"
)

if [[ "${K3S_CLUSTER_INIT:-false}" == "true" ]]; then
  installer_args+=(K3S_CLUSTER_INIT=true)
fi

server_cmd=(server
  --write-kubeconfig-mode 644
  --tls-san "$node_ip"
  --tls-san "$node_name"
  --node-name "$node_name"
  --node-ip "$node_ip"
)

if [[ -n "${K3S_SERVER_FLAGS:-}" ]]; then
  # shellcheck disable=SC2206
  extra_flags=(${K3S_SERVER_FLAGS})
  server_cmd+=("${extra_flags[@]}")
fi

install_k3s "${installer_args[@]}" "${server_cmd[@]}"
wait_for_k3s k3s
install_cli_tools

if saved_token=$(read_server_token); then
  token="$saved_token"
fi
save_token "$token"

if [[ "${INSTALL_ARGOCD:-true}" == "true" ]]; then
  "${SCRIPT_DIR}/install-argocd.sh"
fi

print_server_summary "$node_ip" "$token"
