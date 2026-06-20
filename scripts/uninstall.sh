#!/usr/bin/env bash
# Remove k3s from this node.

set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=../bin/common.sh
source "${ROOT_DIR}/bin/common.sh"

require_root "$0"

if [[ -x /usr/local/bin/k3s-uninstall.sh ]]; then
  log "Running k3s server uninstall..."
  /usr/local/bin/k3s-uninstall.sh
elif [[ -x /usr/local/bin/k3s-agent-uninstall.sh ]]; then
  log "Running k3s agent uninstall..."
  /usr/local/bin/k3s-agent-uninstall.sh
else
  die "No k3s uninstall script found. Is k3s installed on this node?"
fi

log "k3s removed from this node."
