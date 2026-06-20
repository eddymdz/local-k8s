#!/usr/bin/env bash
# Prepare a Debian-based host for k3s (swap, kernel modules, sysctl, packages, firewall).

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

NODE_ROLE=${1:-all}

require_root "$0"
load_config

[[ "${PREPARE_HOST:-true}" == "true" ]] || {
  log "Host preparation skipped (PREPARE_HOST=false)."
  exit 0
}

SYSCTL_FILE=/etc/sysctl.d/99-local-k8s.conf
MODULES_FILE=/etc/modules-load.d/local-k8s.conf
MARKER="# managed by local-k8s"

disable_swap() {
  [[ "${DISABLE_SWAP:-true}" == "true" ]] || return 0

  if swapon --show 2>/dev/null | grep -q .; then
    log "Disabling active swap (swapoff -a)..."
    swapoff -a
  else
    log "Swap is already off."
  fi

  [[ "${PERSIST_SWAP_OFF:-true}" == "true" ]] || return 0

  if grep -qE '^[^#].*\sswap\s' /etc/fstab 2>/dev/null; then
    log "Commenting swap entries in /etc/fstab..."
    cp -a /etc/fstab /etc/fstab.bak-local-k8s-"$(date +%Y%m%d%H%M%S)"
    sed -i 's/^\([^#].*\sswap\s.*\)/# \1/' /etc/fstab
  fi

  for unit in swap.target $(systemctl list-units --type=swap --no-legend 2>/dev/null | awk '{print $1}'); do
    [[ "$unit" == "swap.target" ]] && continue
    if systemctl is-enabled "$unit" >/dev/null 2>&1; then
      log "Disabling swap unit: ${unit}"
      systemctl stop "$unit" 2>/dev/null || true
      systemctl disable "$unit" 2>/dev/null || true
    fi
  done
}

load_kernel_modules() {
  local modules=(overlay br_netfilter)
  local mod

  for mod in "${modules[@]}"; do
    if ! lsmod | awk '{print $1}' | grep -qx "$mod"; then
      log "Loading kernel module: ${mod}"
      modprobe "$mod"
    fi
  done

  log "Persisting kernel modules in ${MODULES_FILE}..."
  cat >"$MODULES_FILE" <<EOF
${MARKER}
overlay
br_netfilter
EOF
}

configure_sysctl() {
  log "Applying sysctl settings in ${SYSCTL_FILE}..."
  cat >"$SYSCTL_FILE" <<EOF
${MARKER}
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
net.ipv4.conf.all.forwarding        = 1
net.ipv6.conf.all.forwarding        = 1
fs.inotify.max_user_instances       = 512
fs.inotify.max_user_watches         = 524288
EOF

  sysctl --system >/dev/null 2>&1 || sysctl -p "$SYSCTL_FILE"
}

install_base_packages() {
  [[ "${INSTALL_BASE_PACKAGES:-true}" == "true" ]] || return 0
  command -v apt-get >/dev/null 2>&1 || {
    warn "apt-get not found; skipping base package install. k3s installer will pull what it can."
    return 0
  }

  local packages=(
    curl
    ca-certificates
    gnupg
    iproute2
    iptables
    kmod
    socat
    conntrack
    ebtables
    ethtool
  )

  if [[ "${INSTALL_ISCSI:-false}" == "true" ]]; then
    packages+=(open-iscsi)
  fi

  local missing=()
  local pkg
  for pkg in "${packages[@]}"; do
    dpkg -s "$pkg" >/dev/null 2>&1 || missing+=("$pkg")
  done

  if ((${#missing[@]} == 0)); then
    log "Base packages already installed."
    return 0
  fi

  log "Installing base packages: ${missing[*]}"
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -qq
  apt-get install -y -qq --no-install-recommends "${missing[@]}"
}

configure_firewall() {
  [[ "${CONFIGURE_FIREWALL:-true}" == "true" ]] || return 0
  command -v ufw >/dev/null 2>&1 || return 0
  ufw status 2>/dev/null | grep -qi active || return 0

  local rules=()
  case "$NODE_ROLE" in
    server)
      rules=(
        "6443/tcp"
        "8472/udp"
        "10250/tcp"
        "2379:2380/tcp"
      )
      ;;
    agent)
      rules=(
        "8472/udp"
        "10250/tcp"
      )
      ;;
    *)
      rules=(
        "6443/tcp"
        "8472/udp"
        "10250/tcp"
        "2379:2380/tcp"
      )
      ;;
  esac

  local rule
  for rule in "${rules[@]}"; do
    if ufw status | grep -qE "[[:space:]]${rule//\//\/}[[:space:]]"; then
      continue
    fi
    log "Opening UFW port: ${rule}"
    ufw allow "$rule" >/dev/null
  done
}

check_cgroups() {
  if [[ -f /sys/fs/cgroup/cgroup.controllers ]]; then
    log "cgroups v2 detected."
    return 0
  fi

  if mount | grep -q cgroup; then
    log "cgroups v1 detected."
    return 0
  fi

  warn "cgroups do not appear to be available. k3s may fail to start."
}

check_hostname() {
  local name
  name=$(hostname -s)
  if [[ -z "$name" || "$name" == "localhost" ]]; then
    warn "Hostname is '${name:-unset}'. Set a unique K3S_NODE_NAME before joining the cluster."
  fi
}

check_memory() {
  local mem_kb
  mem_kb=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
  if [[ "$mem_kb" -lt 1048576 ]]; then
    warn "Less than 1 GiB RAM detected. k3s may be unstable for production workloads."
  fi
}

main() {
  log "Preparing host for k3s (role: ${NODE_ROLE})..."

  check_hostname
  check_memory
  disable_swap
  load_kernel_modules
  configure_sysctl
  install_base_packages
  configure_firewall
  check_cgroups

  log "Host preparation complete."
}

main "$@"
