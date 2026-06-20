#!/usr/bin/env bash
# local-k8s — install k3s control plane or worker nodes on Debian-based systems.
#
# Usage:
#   sudo ./install.sh server
#   sudo ./install.sh agent
#   sudo ./install.sh uninstall

set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
export LOCAL_K8S_ROOT="$ROOT_DIR"

# shellcheck source=bin/common.sh
source "${ROOT_DIR}/bin/common.sh"

usage() {
  cat <<EOF
Usage: sudo $0 <command>

Commands:
  prepare    Prepare this host for k3s (swap, sysctl, modules, packages)
  server     Install k3s control plane on this node
  agent      Join this node to an existing cluster as a worker
  tools      Install kubectl, k9s, helm, and other admin CLI tools
  uninstall  Remove k3s from this node

Configuration:
  Copy config/config.env.example to config/config.env and edit as needed.
  Environment variables override the config file.

Examples:
  sudo $0 prepare
  sudo $0 server
  sudo $0 agent
  sudo $0 tools
  sudo $0 uninstall
EOF
}

main() {
  check_prerequisites

  local cmd=${1:-}
  case "$cmd" in
    prepare)
      require_root "$0"
      load_config
      exec "${ROOT_DIR}/bin/prepare-host.sh" all
      ;;
    server)
      exec "${ROOT_DIR}/bin/install-server.sh"
      ;;
    agent)
      exec "${ROOT_DIR}/bin/install-agent.sh"
      ;;
    tools)
      require_root "$0"
      load_config
      exec "${ROOT_DIR}/bin/install-cli-tools.sh"
      ;;
    uninstall)
      exec "${ROOT_DIR}/scripts/uninstall.sh"
      ;;
    -h|--help|help|"")
      usage
      [[ -z "$cmd" ]] && exit 1
      ;;
    *)
      die "Unknown command: $cmd. Run '$0 --help' for usage."
      ;;
  esac
}

main "$@"
