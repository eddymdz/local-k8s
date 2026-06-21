#!/usr/bin/env bash
# Install Argo CD on the cluster (no applications — those live in your private GitOps repo).

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

load_config

ensure_kubeconfig() {
  if [[ -n "${KUBECONFIG:-}" && -r "${KUBECONFIG}" ]]; then
    return 0
  fi
  if [[ -r /etc/rancher/k3s/k3s.yaml ]]; then
    export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
    return 0
  fi
  local user_config
  if [[ -n "${SUDO_USER:-}" ]]; then
    user_config=$(eval echo "~${SUDO_USER}/.kube/config-local-k8s")
  else
    user_config="${KUBECONFIG_DEST:-$HOME/.kube/config-local-k8s}"
  fi
  if [[ -r "$user_config" ]]; then
    export KUBECONFIG="$user_config"
    return 0
  fi
  die "kubeconfig not found. Run ./scripts/get-kubeconfig.sh first."
}

require_kubectl() {
  require_command kubectl
  ensure_kubeconfig
  kubectl cluster-info >/dev/null 2>&1 || die "Cannot reach the Kubernetes API. Is k3s running?"
}

argocd_manifest_url() {
  local version="${ARGOCD_VERSION:-stable}"
  echo "https://raw.githubusercontent.com/argoproj/argo-cd/${version}/manifests/install.yaml"
}

wait_for_argocd() {
  local namespace="${ARGOCD_NAMESPACE:-argocd}"
  log "Waiting for Argo CD pods in ${namespace}..."
  kubectl wait pods --all \
    -n "$namespace" \
    --for=condition=Ready \
    --timeout="${ARGOCD_READY_TIMEOUT:-600}s"
}

patch_insecure_server() {
  local namespace="${ARGOCD_NAMESPACE:-argocd}"
  [[ "${ARGOCD_SERVER_INSECURE:-true}" == "true" ]] || return 0

  log "Enabling insecure HTTP mode for local access..."
  kubectl patch configmap argocd-cmd-params-cm -n "$namespace" --type merge \
    -p '{"data":{"server.insecure":"true"}}' 2>/dev/null || \
  kubectl create configmap argocd-cmd-params-cm -n "$namespace" \
    --from-literal server.insecure=true --dry-run=client -o yaml | kubectl apply -f -

  kubectl rollout restart deployment argocd-server -n "$namespace"
  kubectl rollout status deployment argocd-server -n "$namespace" --timeout=300s
}

expose_nodeport() {
  local namespace="${ARGOCD_NAMESPACE:-argocd}"
  local http_port="${ARGOCD_NODEPORT_HTTP:-30080}"
  local https_port="${ARGOCD_NODEPORT_HTTPS:-30443}"

  log "Exposing argocd-server via NodePort (${http_port}/${https_port})..."
  kubectl patch svc argocd-server -n "$namespace" --type merge -p "$(cat <<EOF
{
  "spec": {
    "type": "NodePort",
    "ports": [
      {"name": "http", "port": 80, "protocol": "TCP", "targetPort": 8080, "nodePort": ${http_port}},
      {"name": "https", "port": 443, "protocol": "TCP", "targetPort": 8080, "nodePort": ${https_port}}
    ]
  }
}
EOF
)"
}

expose_ingress() {
  local namespace="${ARGOCD_NAMESPACE:-argocd}"
  local host="${ARGOCD_INGRESS_HOST:-argocd.local}"

  log "Creating Traefik Ingress for ${host}..."
  kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: argocd-server
  namespace: ${namespace}
  annotations:
    traefik.ingress.kubernetes.io/router.entrypoints: web
spec:
  rules:
    - host: ${host}
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: argocd-server
                port:
                  number: 80
EOF
}

expose_server() {
  case "${ARGOCD_SERVER_EXPOSE:-nodeport}" in
    nodeport) expose_nodeport ;;
    ingress) expose_ingress ;;
    clusterip|none)
      log "Argo CD server left as ClusterIP (use kubectl port-forward)."
      ;;
    *)
      die "Unknown ARGOCD_SERVER_EXPOSE: ${ARGOCD_SERVER_EXPOSE}"
      ;;
  esac
}

get_admin_password() {
  local namespace="${ARGOCD_NAMESPACE:-argocd}"
  kubectl get secret argocd-initial-admin-secret -n "$namespace" \
    -o jsonpath='{.data.password}' 2>/dev/null | base64 -d || true
}

print_argocd_summary() {
  local ip
  ip="${K3S_NODE_IP:-$(detect_primary_ip)}"
  local namespace="${ARGOCD_NAMESPACE:-argocd}"
  local password
  password=$(get_admin_password)

  local ui_url
  case "${ARGOCD_SERVER_EXPOSE:-nodeport}" in
    nodeport)
      if [[ "${ARGOCD_SERVER_INSECURE:-true}" == "true" ]]; then
        ui_url="http://${ip}:${ARGOCD_NODEPORT_HTTP:-30080}"
      else
        ui_url="https://${ip}:${ARGOCD_NODEPORT_HTTPS:-30443}"
      fi
      ;;
    ingress)
      ui_url="http://${ARGOCD_INGRESS_HOST:-argocd.local}"
      ;;
    *)
      ui_url="(run: kubectl port-forward svc/argocd-server -n ${namespace} 8080:80)"
      ;;
  esac

  cat <<EOF

================================================================================
Argo CD is ready.

  UI:        ${ui_url}
  Username:  admin
  Password:  ${password:-run ./scripts/argocd-admin-password.sh}

CLI login:
  ./scripts/argocd-login.sh

Connect your private GitOps repo:
  ./scripts/argocd-add-repo.sh

Optional — bootstrap apps from that repo automatically:
  Set ARGOCD_BOOTSTRAP_GITOPS=true in config/config.env, then:
  ./scripts/argocd-bootstrap-apps.sh
================================================================================

EOF
}

main() {
  [[ "${INSTALL_ARGOCD:-true}" == "true" ]] || {
    log "Argo CD installation skipped (INSTALL_ARGOCD=false)."
    exit 0
  }

  require_kubectl
  local namespace="${ARGOCD_NAMESPACE:-argocd}"
  local manifest_url
  manifest_url=$(argocd_manifest_url)

  if kubectl get namespace "$namespace" >/dev/null 2>&1; then
    warn "Namespace ${namespace} already exists. Applying manifest updates only."
  fi

  log "Installing Argo CD from ${manifest_url}..."
  kubectl create namespace "$namespace" --dry-run=client -o yaml | kubectl apply -f -
  kubectl apply -n "$namespace" --server-side --force-conflicts -f "$manifest_url"

  wait_for_argocd
  patch_insecure_server
  expose_server

  if [[ "${ARGOCD_BOOTSTRAP_GITOPS:-false}" == "true" ]]; then
    "${LOCAL_K8S_ROOT}/scripts/argocd-bootstrap-apps.sh"
  fi

  if [[ "${INSTALL_ARGOCD_CLI:-true}" == "true" ]]; then
    if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
      INSTALL_CLI_TOOLS=false "${LOCAL_K8S_ROOT}/bin/install-cli-tools.sh" --argocd-only
    else
      sudo INSTALL_CLI_TOOLS=false "${LOCAL_K8S_ROOT}/bin/install-cli-tools.sh" --argocd-only
    fi
  fi

  print_argocd_summary
}

main "$@"
