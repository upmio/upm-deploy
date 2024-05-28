#!/usr/bin/env bash

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

  local operators_ns=openshift-operators
  local marketplace_ns=openshift-marketplace
  local MAX_ATTEMPTS=24

  #delete import job
  if [[ -n "$(kubectl get job -n ${operators_ns} upm-engine-import-configmaps)" ]]; then
    kubectl delete job -n ${operators_ns} upm-engine-import-configmaps || {
      error "delete job upm-engine-import-configmaps error"
    }
  fi

  #delete kauntlet
  if [[ -n "$(kubectl get csv -n ${operators_ns} kauntlet."${KAUNTLET_VERSION}")" ]]; then
    kubectl delete csv -n ${operators_ns} kauntlet."${KAUNTLET_VERSION}" || {
      error "delete csv kauntlet error "
    }
  fi

  if [[ -n "$(kubectl get catalogsources -n ${marketplace_ns} kauntlet-catalog)" ]]; then
    kubectl delete catalogsources -n ${marketplace_ns} kauntlet-catalog || {
      error "delete catalogsource kauntlet-catalog error"
    }
  fi

  if [[ -n "$(kubectl get subscriptions -n ${operators_ns} kauntlet-operator)" ]]; then
    kubectl delete subscriptions -n ${operators_ns} kauntlet-operator || {
      error "delete subscription kauntlet-operator error"
    }
  fi

  #delete tesseract-cube
  if [[ -n "$(kubectl get csv -n ${operators_ns} tesseract-cube."${TESSERACT_CUBE_VERSION}")" ]]; then
    kubectl delete csv -n ${operators_ns} tesseract-cube."${TESSERACT_CUBE_VERSION}" || {
      error "delete csv tesseract-cube error "
    }
  fi

  if [[ -n "$(kubectl get catalogsources -n ${marketplace_ns} tesseract-cube-catalog)" ]]; then
    kubectl delete catalogsources -n ${marketplace_ns} tesseract-cube-catalog || {
      error "delete catalogsource tesseract-cube-catalog error"
    }
  fi

  if [[ -n "$(kubectl get subscriptions -n ${operators_ns} tesseract-cube-operator)" ]]; then
    kubectl delete subscriptions -n ${operators_ns} tesseract-cube-operator || {
      error "delete subscription kauntlet-operator error"
    }
  fi

  for ((i = 1; i <= "${MAX_ATTEMPTS}"; i++)); do

    if ! kubectl get job -n ${operators_ns} | grep 'upm-engine-import-configmaps'; then
      echo "job deleted successfully."
    else
      echo "Delete job failed, retrying."
    fi

    if ! kubectl get csv -n ${operators_ns} | grep -qE 'tesseract-cube|kauntlet'; then
      echo "CSV deleted successfully."
    else
      echo "Delete csv failed, retrying."
    fi

    # check CatalogSources
    if ! kubectl get catalogsources -n ${marketplace_ns} | grep -qE 'tesseract-cube|kauntlet'; then
      echo "CatalogSources deleted successfully."
    else
      echo "Delete CatalogSources failed, retrying."
    fi

    # check Subscriptions
    if ! kubectl get subscriptions -n ${operators_ns} | grep -qE 'tesseract-cube|kauntlet'; then
      echo "Subscriptions deleted successfully."
      break
    else
      echo "Delete Subscriptions failed, retrying"
    fi

    sleep 5
  done

}

uninstall_upm_engine_on_k8s() {
  kubectl get node --no-headers -l 'upm.engine.node=enable' | awk '{print $1}' | xargs -I {} kubectl label nodes {} 'upm.engine.node-' || {
    error "remove label upm-engine/node error"
  }

  # check ENGINE_KUBE_NAMESPACE exists
  if [[ -n "$(kubectl get namespace "${ENGINE_KUBE_NAMESPACE}")" ]]; then
    if [[ -n "$(kubectl get job -n "${ENGINE_KUBE_NAMESPACE}" upm-engine-import-configmaps)" ]]; then
      kubectl delete job -n "${ENGINE_KUBE_NAMESPACE}" upm-engine-import-configmaps || {
        error "delete job upm-engine-import-configmaps error"
      }
    fi

    if [[ -n "$(helm list -n "${ENGINE_KUBE_NAMESPACE}" upm-engine)" ]]; then
      helm uninstall upm-engine -n "${ENGINE_KUBE_NAMESPACE}" upm-engine || {
        error "uninstall upm-engine error"
      }
    fi
  else
    info "namespace ${ENGINE_KUBE_NAMESPACE} not exists"
  fi
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

  info "Uninstall upm-engine successfully"
}

main
