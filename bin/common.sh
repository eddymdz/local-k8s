#!/usr/bin/env bash
# Shared helpers for local-k8s install scripts.

set -euo pipefail

LOCAL_K8S_ROOT="${LOCAL_K8S_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
CONFIG_FILE="${LOCAL_K8S_STATE_DIR:-$HOME/.local-k8s}/config.env"
PROJECT_CONFIG="${LOCAL_K8S_ROOT}/config/config.env"
K3S_INSTALL_URL="${K3S_INSTALL_URL:-https://get.k3s.io}"

log() {
  printf '[local-k8s] %s\n' "$*"
}

warn() {
  printf '[local-k8s] WARNING: %s\n' "$*" >&2
}

die() {
  printf '[local-k8s] ERROR: %s\n' "$*" >&2
  exit 1
}

require_root() {
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    die "This command must be run as root (try: sudo $0 $*)"
  fi
}

require_command() {
  local cmd=$1
  command -v "$cmd" >/dev/null 2>&1 || die "Required command not found: $cmd"
}

check_prerequisites() {
  local missing=()
  for cmd in curl bash; do
    command -v "$cmd" >/dev/null 2>&1 || missing+=("$cmd")
  done

  if ((${#missing[@]} > 0)); then
    die "Missing required commands: ${missing[*]}"
  fi

  if ! command -v sudo >/dev/null 2>&1 && [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    die "sudo is required when not running as root"
  fi
}

load_config() {
  if [[ -f "$PROJECT_CONFIG" ]]; then
    # shellcheck disable=SC1090
    set -a
    source "$PROJECT_CONFIG"
    set +a
  fi

  if [[ -f "$CONFIG_FILE" ]]; then
    # shellcheck disable=SC1090
    set -a
    source "$CONFIG_FILE"
    set +a
  fi
}

ensure_state_dir() {
  local dir
  if [[ -n "${LOCAL_K8S_STATE_DIR:-}" ]]; then
    dir="$LOCAL_K8S_STATE_DIR"
  elif [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
    dir=/var/lib/local-k8s
  else
    dir="$HOME/.local-k8s"
  fi
  mkdir -p "$dir"
  chmod 700 "$dir"
  echo "$dir"
}

detect_arch() {
  case "$(uname -m)" in
    x86_64|amd64) echo amd64 ;;
    aarch64|arm64) echo arm64 ;;
    armv7l|armv6l) echo arm ;;
    *) die "Unsupported architecture: $(uname -m)" ;;
  esac
}

detect_primary_ip() {
  local ip=""
  ip=$(ip -4 route get 1.1.1.1 2>/dev/null | awk '{for (i=1;i<=NF;i++) if ($i=="src") {print $(i+1); exit}}') || true
  if [[ -z "$ip" ]]; then
    ip=$(hostname -I 2>/dev/null | awk '{print $1}') || true
  fi
  [[ -n "$ip" ]] || die "Could not detect primary IP. Set K3S_NODE_IP in config/config.env"
  echo "$ip"
}

generate_token() {
  if command -v openssl >/dev/null 2>&1; then
    openssl rand -hex 16
  else
    # Fallback when openssl is unavailable
    tr -dc 'A-Za-z0-9' </dev/urandom | head -c 32
  fi
}

read_server_token() {
  local token_file=/var/lib/rancher/k3s/server/node-token
  [[ -f "$token_file" ]] || return 1
  awk '{print $NF}' "$token_file"
}

save_token() {
  local token=$1
  local state_dir
  state_dir=$(ensure_state_dir)
  printf '%s\n' "$token" >"${state_dir}/node-token"
  chmod 600 "${state_dir}/node-token"
}

install_k3s() {
  local -a env_vars=()
  local -a cmd=()
  local arg

  for arg in "$@"; do
    if [[ "$arg" == *=* && "$arg" != -* ]]; then
      env_vars+=("$arg")
    else
      cmd+=("$arg")
    fi
  done

  local -a installer_env=()
  [[ -n "${K3S_VERSION:-}" ]] && installer_env+=(INSTALL_K3S_VERSION="$K3S_VERSION")
  [[ -n "${K3S_CHANNEL:-}" ]] && installer_env+=(INSTALL_K3S_CHANNEL="$K3S_CHANNEL")

  log "Installing k3s (${cmd[*]:-server}) from ${K3S_INSTALL_URL}..."
  curl -sfL "$K3S_INSTALL_URL" | env "${installer_env[@]}" "${env_vars[@]}" sh -s - "${cmd[@]}"
}

install_cli_tools() {
  "${LOCAL_K8S_ROOT}/bin/install-cli-tools.sh"
}

install_kubectl() {
  install_cli_tools
}

wait_for_k3s() {
  local unit=$1
  local attempts=${2:-60}
  local i

  for ((i = 1; i <= attempts; i++)); do
    if systemctl is-active --quiet "$unit"; then
      return 0
    fi
    sleep 2
  done

  die "Timed out waiting for ${unit}. Check: journalctl -u ${unit} -e"
}

print_server_summary() {
  local ip=${1:-}
  local token=${2:-}
  local state_dir
  state_dir=$(ensure_state_dir)

  cat <<EOF

================================================================================
Control plane is ready.

  API server:  https://${ip}:6443
  Node token:  ${token}
  Token file:  ${state_dir}/node-token

On worker nodes, set in config/config.env:

  K3S_URL=https://${ip}:6443
  K3S_TOKEN=${token}

Then run:

  sudo ./install.sh agent

Kubeconfig (on this node):

  ./scripts/get-kubeconfig.sh
  export KUBECONFIG=\$HOME/.kube/config-local-k8s
  kubectl get nodes
  k9s
================================================================================

EOF
}

print_agent_summary() {
  cat <<EOF

================================================================================
Worker node joined the cluster.

  Node name: ${K3S_NODE_NAME:-$(hostname -s)}

On the control plane:

  export KUBECONFIG=\$HOME/.kube/config-local-k8s
  kubectl get nodes
================================================================================

EOF
}
