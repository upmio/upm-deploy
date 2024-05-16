#!/usr/bin/env bash

readonly RELEASE="upm-engine"
readonly TESSERACT_CUBE_VERSION="v1.1.0"
readonly KAUNTLET_VERSION="v1.1.0"

ENGINE_KUBE_NAMESPACE="${ENGINE_KUBE_NAMESPACE:-upm-system}"
INSTALL_LOG_PATH=/tmp/upm-engine-uninstall-$(date +'%Y-%m-%d_%H-%M-%S').log

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

uninstall_upm_engine_on_openshift() {
  if [ -n "$(kubectl get job -n "${ENGINE_KUBE_NAMESPACE}" -l 'app.kubernetes.io/name=upm-engine')" ]; then
    kubectl delete job -n "${ENGINE_KUBE_NAMESPACE}" -l 'app.kubernetes.io/name=upm-engine'
  else
    echo "delete job upm-engine error"
  fi

  kubectl delete roles -n "${ENGINE_KUBE_NAMESPACE}" "${RELEASE}-import-configmaps-role" || {
    error "delete roles upm-engine error"
  }
  kubectl delete rolebindings -n "${ENGINE_KUBE_NAMESPACE}" "${RELEASE}-import-configmaps-rolebinding" || {
    error "delete rolebindings upm-engine error"
  }
  kubectl delete serviceaccounts -n "${ENGINE_KUBE_NAMESPACE}" "${RELEASE}-import-configmaps-sa" || {
    error "delete serviceaccounts upm-engine error"
  }

  kubectl delete catalogsources -n openshift-marketplace tesseract-cube-catalog kauntlet-catalog || {
    error "delete catalogsources upm-engine error"
  }

  kubectl delete subscriptions -n openshift-operators kauntlet-operator tesseract-cube-operator || {
    error "delete subscriptions upm-engine error"
  }

  kubectl delete csv -n openshift-operators "kauntlet.${KAUNTLET_VERSION}" "tesseract-cube.${TESSERACT_CUBE_VERSION}" || {
    error "delete csv upm-engine error"
  }
}

uninstall_upm_engine_on_k8s() {
  helm uninstall "upm-engine" -n "${ENGINE_KUBE_NAMESPACE}" || {
    error "Uninstall upm-engine failed"
  }
  kubectl get node --no-headers -l 'upm.engine.node=enable' | awk '{print $1}' | xargs -I {} kubectl label nodes {} 'upm.engine.node-' || {
    error "remove label upm-engine/node error"
  }

  if [ -n "$(kubectl get job -n "${ENGINE_KUBE_NAMESPACE}" -l 'app.kubernetes.io/name=upm-engine')" ]; then
    kubectl delete job -n "${ENGINE_KUBE_NAMESPACE}" -l 'app.kubernetes.io/name=upm-engine'
  else
    echo "delete job upm-engine error"
  fi

  kubectl delete roles -n "${ENGINE_KUBE_NAMESPACE}" -l 'app.kubernetes.io/name=upm-engine' || {
    error "delete roles upm-engine error"
  }
  kubectl delete rolebindings -n "${ENGINE_KUBE_NAMESPACE}" -l 'app.kubernetes.io/name=upm-engine' || {
    error "delete rolebindings upm-engine error"
  }
  kubectl delete serviceaccounts -n "${ENGINE_KUBE_NAMESPACE}" -l 'app.kubernetes.io/name=upm-engine' || {
    error "delete serviceaccounts upm-engine error"
  }
}

init_log() {
  touch "${INSTALL_LOG_PATH}" || error "Create log file ${INSTALL_LOG_PATH} error"
  info "Log file create in path ${INSTALL_LOG_PATH}"
}

verify_supported() {
  installed helm || error "helm is required"
  installed kubectl || error "kubectl is required"
}

main() {
  init_log
  verify_supported

  if kubectl api-resources | grep security.openshift.io/v1 &>/dev/null; then
    uninstall_upm_engine_on_openshift
  else
    uninstall_upm_engine_on_k8s
  fi
}

main
