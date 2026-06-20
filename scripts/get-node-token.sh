#!/usr/bin/env bash
# Print the k3s agent join token (run on the control plane node).

set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=../bin/common.sh
source "${ROOT_DIR}/bin/common.sh"

state_dir=$(ensure_state_dir)

if [[ -f "${state_dir}/node-token" ]]; then
  cat "${state_dir}/node-token"
  exit 0
fi

read_token_from_server() {
  local token_file=/var/lib/rancher/k3s/server/node-token
  [[ -f "$token_file" ]] || return 1
  awk '{print $NF}' "$token_file"
}

if token=$(read_token_from_server); then
  echo "$token"
  exit 0
fi

if token=$(sudo awk '{print $NF}' /var/lib/rancher/k3s/server/node-token 2>/dev/null); then
  echo "$token"
  exit 0
fi

die "Could not read node token. Is the control plane installed on this node?"
