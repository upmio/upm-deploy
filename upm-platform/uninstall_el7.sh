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
  helm uninstall "upm-platform" -n "${PLATFORM_KUBE_NAMESPACE}" || error "Uninstall upm-platform error"
  kubectl get node --no-headers -l 'upm.platform.node=enable' | awk '{print $1}' | xargs -I {} kubectl label node {} 'upm.platform.node-' || {
    error "remove label upm.platform.node error"
  }
  kubectl delete job -n "${PLATFORM_KUBE_NAMESPACE}" -l 'app.kubernetes.io/instance=upm-platform' || {
    error "delete upm-platform job error"
  }
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
}

main
