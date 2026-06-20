#!/usr/bin/env bash
# Install kubectl, k9s, helm, and other cluster administration tools.

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

require_root "$0"
load_config

tool_enabled() {
  local var=$1
  [[ "${!var:-true}" == "true" ]]
}

install_apt_packages() {
  local -a packages=("$@")
  command -v apt-get >/dev/null 2>&1 || return 0

  local missing=()
  local pkg
  for pkg in "${packages[@]}"; do
    dpkg -s "$pkg" >/dev/null 2>&1 || missing+=("$pkg")
  done
  ((${#missing[@]} == 0)) && return 0

  log "Installing apt packages: ${missing[*]}"
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -qq
  apt-get install -y -qq --no-install-recommends "${missing[@]}"
}

install_binary() {
  local name=$1
  local url=$2
  local dest=${3:-/usr/local/bin/${name}}

  if [[ -x "$dest" ]]; then
    log "${name} already installed at ${dest}"
    return 0
  fi

  local tmp
  tmp=$(mktemp)
  log "Installing ${name}..."
  curl -fsSL --retry 3 -o "$tmp" "$url"
  install -m 0755 "$tmp" "$dest"
  rm -f "$tmp"
}

install_kubectl() {
  tool_enabled INSTALL_KUBECTL || return 0

  local version="${KUBECTL_VERSION:-}"
  if [[ -z "$version" && -n "${K3S_VERSION:-}" ]]; then
    version="v${K3S_VERSION%%+*}"
  fi
  if [[ -z "$version" ]]; then
    version=$(curl -fsSL --retry 3 "https://dl.k8s.io/release/stable.txt")
  fi

  local arch
  arch=$(detect_arch)
  install_binary kubectl \
    "https://dl.k8s.io/release/${version}/bin/linux/${arch}/kubectl"
}

install_k9s() {
  tool_enabled INSTALL_K9S || return 0

  local arch
  arch=$(detect_arch)
  local version="${K9S_VERSION:-}"
  local url

  if [[ -n "$version" ]]; then
    url="https://github.com/derailed/k9s/releases/download/${version}/k9s_Linux_${arch}.tar.gz"
  else
    url="https://github.com/derailed/k9s/releases/latest/download/k9s_Linux_${arch}.tar.gz"
  fi

  local tmpdir
  tmpdir=$(mktemp -d)
  log "Installing k9s..."
  curl -fsSL --retry 3 -o "${tmpdir}/k9s.tar.gz" "$url"
  tar -xzf "${tmpdir}/k9s.tar.gz" -C "$tmpdir" k9s
  install -m 0755 "${tmpdir}/k9s" /usr/local/bin/k9s
  rm -rf "$tmpdir"
}

install_helm() {
  tool_enabled INSTALL_HELM || return 0
  command -v helm >/dev/null 2>&1 && return 0

  local version="${HELM_VERSION:-}"
  local args=()
  [[ -n "$version" ]] && args=(--version "$version")

  log "Installing helm..."
  curl -fsSL --retry 3 https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | \
    bash -s -- "${args[@]}"
}

install_kustomize() {
  tool_enabled INSTALL_KUSTOMIZE || return 0
  command -v kustomize >/dev/null 2>&1 && return 0

  local arch
  arch=$(detect_arch)
  local version="${KUSTOMIZE_VERSION:-}"

  if [[ -z "$version" ]]; then
    version=$(curl -fsSL --retry 3 \
      "https://api.github.com/repos/kubernetes-sigs/kustomize/releases/latest" \
      | sed -n 's/.*"tag_name": *"kustomize\/\(v[^"]*\)".*/\1/p' \
      | head -1)
  fi
  [[ -n "$version" ]] || die "Could not determine kustomize version"

  local tmpdir
  tmpdir=$(mktemp -d)
  log "Installing kustomize ${version}..."
  curl -fsSL --retry 3 -o "${tmpdir}/kustomize.tar.gz" \
    "https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize%2F${version}/kustomize_${version}_linux_${arch}.tar.gz"
  tar -xzf "${tmpdir}/kustomize.tar.gz" -C "$tmpdir" kustomize
  install -m 0755 "${tmpdir}/kustomize" /usr/local/bin/kustomize
  rm -rf "$tmpdir"
}

install_stern() {
  tool_enabled INSTALL_STERN || return 0
  command -v stern >/dev/null 2>&1 && return 0

  local arch
  arch=$(detect_arch)
  local version="${STERN_VERSION:-}"
  local url

  if [[ -n "$version" ]]; then
    url="https://github.com/stern/stern/releases/download/${version}/stern_${version#v}_linux_${arch}.tar.gz"
  else
    url="https://github.com/stern/stern/releases/latest/download/stern_latest_linux_${arch}.tar.gz"
  fi

  local tmpdir
  tmpdir=$(mktemp -d)
  log "Installing stern..."
  curl -fsSL --retry 3 -o "${tmpdir}/stern.tar.gz" "$url"
  tar -xzf "${tmpdir}/stern.tar.gz" -C "$tmpdir" stern
  install -m 0755 "${tmpdir}/stern" /usr/local/bin/stern
  rm -rf "$tmpdir"
}

install_kubectx_tools() {
  tool_enabled INSTALL_KUBECTX || return 0

  if command -v kubectx >/dev/null 2>&1 && command -v kubens >/dev/null 2>&1; then
    return 0
  fi

  if command -v apt-get >/dev/null 2>&1; then
    install_apt_packages kubectx
    command -v kubectx >/dev/null 2>&1 && return 0
  fi

  local version="${KUBECTX_VERSION:-}"
  if [[ -z "$version" ]]; then
    version=$(curl -fsSL --retry 3 \
      "https://api.github.com/repos/ahmetb/kubectx/releases/latest" \
      | sed -n 's/.*"tag_name": *"\([^"]*\)".*/\1/p' \
      | head -1)
  fi
  [[ -n "$version" ]] || die "Could not determine kubectx version"

  local arch
  arch=$(detect_arch)
  if [[ "$arch" != "amd64" ]]; then
    warn "kubectx binary install skipped on ${arch}; install manually if needed."
    return 0
  fi

  local tmpdir
  tmpdir=$(mktemp -d)
  log "Installing kubectx and kubens ${version}..."
  curl -fsSL --retry 3 -o "${tmpdir}/kubectx.tar.gz" \
    "https://github.com/ahmetb/kubectx/releases/download/${version}/kubectx_${version#v}_linux_x86_64.tar.gz"
  tar -xzf "${tmpdir}/kubectx.tar.gz" -C "$tmpdir"
  install -m 0755 "${tmpdir}/kubectx" /usr/local/bin/kubectx
  install -m 0755 "${tmpdir}/kubens" /usr/local/bin/kubens
  rm -rf "$tmpdir"
}

install_yq() {
  tool_enabled INSTALL_YQ || return 0
  command -v yq >/dev/null 2>&1 && return 0

  local arch
  arch=$(detect_arch)
  local version="${YQ_VERSION:-latest}"
  local url="https://github.com/mikefarah/yq/releases/${version}/download/yq_linux_${arch}"

  install_binary yq "$url"
}

install_jq() {
  tool_enabled INSTALL_JQ || return 0
  command -v jq >/dev/null 2>&1 && return 0
  install_apt_packages jq
}

install_shell_completion() {
  tool_enabled INSTALL_SHELL_COMPLETION || return 0
  command -v kubectl >/dev/null 2>&1 || return 0

  install_apt_packages bash-completion

  local profile=/etc/profile.d/local-k8s-cli.sh
  log "Writing shell helpers to ${profile}..."
  cat >"$profile" <<'EOF'
# local-k8s cluster administration helpers
if command -v kubectl >/dev/null 2>&1; then
  if [[ -z "${KUBECONFIG:-}" && -f "$HOME/.kube/config-local-k8s" ]]; then
    export KUBECONFIG="$HOME/.kube/config-local-k8s"
  fi
  source <(kubectl completion bash) 2>/dev/null || true
fi
if command -v helm >/dev/null 2>&1; then
  source <(helm completion bash) 2>/dev/null || true
fi
EOF
}

print_tools_summary() {
  cat <<EOF

Installed cluster tools:
  kubectl   - Kubernetes CLI
  k9s       - Terminal UI for the cluster
  helm      - Package manager for Kubernetes
  kustomize - Template-free Kubernetes manifests
  stern     - Tail logs from multiple pods
  kubectx   - Switch between contexts
  kubens    - Switch between namespaces
  jq / yq   - JSON and YAML processing

Quick start (control plane):
  ./scripts/get-kubeconfig.sh
  export KUBECONFIG=\$HOME/.kube/config-local-k8s
  kubectl get nodes
  k9s

EOF
}

main() {
  [[ "${INSTALL_CLI_TOOLS:-true}" == "true" ]] || {
    log "CLI tool installation skipped (INSTALL_CLI_TOOLS=false)."
    exit 0
  }

  log "Installing cluster administration tools..."
  install_apt_packages curl ca-certificates tar
  install_kubectl
  install_k9s
  install_helm
  install_kustomize
  install_stern
  install_kubectx_tools
  install_jq
  install_yq
  install_shell_completion
  print_tools_summary
}

main "$@"
