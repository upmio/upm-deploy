#!/usr/bin/env bash

PLATFORM_KUBE_NAMESPACE="${PLATFORM_KUBE_NAMESPACE:-upm-system}"
INSTALL_LOG_PATH=/tmp/upm-platform_uninstall-$(date +'%Y-%m-%d_%H-%M-%S').log

info() {
  echo "[Info][$(date +'%Y-%m-%dT%H:%M:%S%z')]: $*" | tee -a "${INSTALL_LOG_PATH}"
}

error() {
  echo "[Error][$(date +'%Y-%m-%dT%H:%M:%S%z')]: $*" | tee -a "${INSTALL_LOG_PATH}"
  exit 1
}

installed() {
  command -v "$1" >/dev/null 2>&1
}

uninstall_upm_platform() {
  kubectl get node --no-headers -l 'upm.platform.node=enabled' -o custom-columns=NAME:.metadata.name | xargs -I {} kubectl label node {} upm.platform.node- || {
    error "remove upm.platform.node label error"
  }

  # check PLATFORM_KUBE_NAMESPACE exists
  if kubectl get namespace "${PLATFORM_KUBE_NAMESPACE}" 2>/dev/null; then
    if kubectl get job -n "${PLATFORM_KUBE_NAMESPACE}" -l 'app.kubernetes.io/instance=upm-platform' &> /dev/null; then
      kubectl delete job -n "${PLATFORM_KUBE_NAMESPACE}" -l 'app.kubernetes.io/instance=upm-platform' || {
        error "delete upm-platform job error"
      }
    fi

    if helm list -n "${PLATFORM_KUBE_NAMESPACE}" -q | grep upm-platform &> /dev/null; then
      helm uninstall upm-platform -n "${PLATFORM_KUBE_NAMESPACE}" || {
        error "uninstall upm-platform error"
      }
    fi
  else
    info "namespace ${PLATFORM_KUBE_NAMESPACE} not exists"
  fi
}

verify_supported() {
  installed helm || error "helm is required"
  installed kubectl || error "kubectl is required"
}

init_log() {
  touch "${INSTALL_LOG_PATH}" || error "Create log file ${INSTALL_LOG_PATH} error"
  info "Log file create in path ${INSTALL_LOG_PATH}"
}

main() {
  init_log
  verify_supported
  uninstall_upm_platform
  info "Uninstall upm-platform successfully"
}

main
