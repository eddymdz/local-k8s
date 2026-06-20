#!/usr/bin/env bash
# Bootstrap local-k8s without git: download the project and run install.sh.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/YOUR_USER/local-k8s/main/bootstrap.sh | sudo bash -s -- server
#   curl -fsSL ... | sudo -E bash -s -- agent
#
# Environment (optional):
#   LOCAL_K8S_REPO   Git clone URL (default: set in script or via env)
#   LOCAL_K8S_BRANCH Branch or tag to checkout (default: main)
#   LOCAL_K8S_DIR    Install directory (default: /opt/local-k8s)

set -euo pipefail

REPO="${LOCAL_K8S_REPO:-}"
BRANCH="${LOCAL_K8S_BRANCH:-main}"
INSTALL_DIR="${LOCAL_K8S_DIR:-/opt/local-k8s}"
TMP_DIR=""

cleanup() {
  [[ -n "$TMP_DIR" && -d "$TMP_DIR" ]] && rm -rf "$TMP_DIR"
}
trap cleanup EXIT

log() {
  printf '[bootstrap] %s\n' "$*"
}

die() {
  printf '[bootstrap] ERROR: %s\n' "$*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"
}

download_with_curl() {
  local dest=$1
  require_command curl
  require_command tar

  [[ -n "$REPO" ]] || die "Set LOCAL_K8S_REPO to your git repository URL, or clone the repo manually."

  local archive_url
  if [[ "$REPO" =~ github\.com[:/]([^/]+)/([^/.]+)(\.git)?$ ]]; then
    local owner="${BASH_REMATCH[1]}"
    local repo="${BASH_REMATCH[2]}"
    archive_url="https://github.com/${owner}/${repo}/archive/refs/heads/${BRANCH}.tar.gz"
  else
    die "Cannot derive archive URL from LOCAL_K8S_REPO. Clone with git instead: git clone ${REPO} ${INSTALL_DIR}"
  fi

  TMP_DIR=$(mktemp -d)
  log "Downloading ${archive_url}..."
  curl -fsSL --retry 3 -o "${TMP_DIR}/local-k8s.tar.gz" "$archive_url"
  tar -xzf "${TMP_DIR}/local-k8s.tar.gz" -C "$TMP_DIR"

  local extracted
  extracted=$(find "$TMP_DIR" -mindepth 1 -maxdepth 1 -type d | head -1)
  [[ -n "$extracted" ]] || die "Archive extraction failed"

  mkdir -p "$(dirname "$INSTALL_DIR")"
  rm -rf "$INSTALL_DIR"
  mv "$extracted" "$INSTALL_DIR"
}

download_with_git() {
  require_command git
  [[ -n "$REPO" ]] || die "Set LOCAL_K8S_REPO to your git repository URL."

  if [[ -d "${INSTALL_DIR}/.git" ]]; then
    log "Updating existing clone in ${INSTALL_DIR}..."
    git -C "$INSTALL_DIR" fetch --depth 1 origin "$BRANCH"
    git -C "$INSTALL_DIR" checkout "$BRANCH"
    git -C "$INSTALL_DIR" pull --ff-only origin "$BRANCH" 2>/dev/null || true
  else
    mkdir -p "$(dirname "$INSTALL_DIR")"
    log "Cloning ${REPO} into ${INSTALL_DIR}..."
    git clone --depth 1 --branch "$BRANCH" "$REPO" "$INSTALL_DIR"
  fi
}

main() {
  require_command curl
  require_command bash

  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    die "Run as root: curl ... | sudo bash -s -- server"
  fi

  if command -v git >/dev/null 2>&1 && [[ -n "$REPO" ]]; then
    download_with_git
  else
    download_with_curl
  fi

  if [[ ! -f "${INSTALL_DIR}/config/config.env" && -f "${INSTALL_DIR}/config/config.env.example" ]]; then
    cp "${INSTALL_DIR}/config/config.env.example" "${INSTALL_DIR}/config/config.env"
    log "Created ${INSTALL_DIR}/config/config.env from example."
  fi

  chmod +x "${INSTALL_DIR}/install.sh" "${INSTALL_DIR}/bin/"*.sh "${INSTALL_DIR}/scripts/"*.sh 2>/dev/null || true

  log "Running install from ${INSTALL_DIR}..."
  exec "${INSTALL_DIR}/install.sh" "$@"
}

main "$@"
