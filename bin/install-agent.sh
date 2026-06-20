#!/usr/bin/env bash
# Install k3s worker node (agent).

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

require_root "$0"
load_config

if systemctl is-active --quiet k3s-agent 2>/dev/null; then
  warn "k3s agent is already running on this node."
  print_agent_summary
  exit 0
fi

[[ -n "${K3S_URL:-}" ]] || die "K3S_URL is required for agent install. Set it in config/config.env"
[[ -n "${K3S_TOKEN:-}" ]] || die "K3S_TOKEN is required for agent install. Run ./scripts/get-node-token.sh on the server."

if [[ "${PREPARE_HOST:-true}" == "true" ]]; then
  "${SCRIPT_DIR}/prepare-host.sh" agent
fi

node_name="${K3S_NODE_NAME:-$(hostname -s)}"

installer_args=(
  K3S_URL="$K3S_URL"
  K3S_TOKEN="$K3S_TOKEN"
  K3S_NODE_NAME="$node_name"
)

agent_cmd=(agent --node-name "$node_name")

if [[ -n "${K3S_AGENT_FLAGS:-}" ]]; then
  # shellcheck disable=SC2206
  extra_flags=(${K3S_AGENT_FLAGS})
  agent_cmd+=("${extra_flags[@]}")
fi

install_k3s "${installer_args[@]}" "${agent_cmd[@]}"
wait_for_k3s k3s-agent

if [[ "${INSTALL_CLI_TOOLS_ON_AGENTS:-true}" == "true" ]]; then
  install_cli_tools
fi

print_agent_summary
