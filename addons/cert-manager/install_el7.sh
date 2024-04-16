#!/usr/bin/env bash

# You must be prepared as follows before run install.sh:
#
# 1. CERT_MANAGER_NODE_NAMES MUST be set as environment variable, for an example:
#
#        export CERT_MANAGER_NODE_NAMES="master01,master02"
#

readonly CHART="bitnami/cert-manager"
readonly RELEASE="cert-manager"
readonly TIME_OUT_SECOND="600s"
readonly CHART_VERSION="1.1.1"

CERT_MANAGER_KUBE_NAMESPACE="${CERT_MANAGER_KUBE_NAMESPACE:-cert-manager}"
CERT_MANAGER_RESOURCE_LIMITS_CPU="${CERT_MANAGER_RESOURCE_LIMITS_CPU:-500m}"
CERT_MANAGER_RESOURCE_LIMITS_MEMORY="${CERT_MANAGER_RESOURCE_LIMITS_MEMORY:-512Mi}"
CERT_MANAGER_RESOURCE_REQUESTS_CPU="${CERT_MANAGER_RESOURCE_REQUESTS_CPU:-500m}"
CERT_MANAGER_RESOURCE_REQUESTS_MEMORY="${CERT_MANAGER_RESOURCE_REQUESTS_MEMORY:-512Mi}"
CERT_MANAGER_WEBHOOK_RESOURCE_LIMITS_CPU="${CERT_MANAGER_WEBHOOK_RESOURCE_LIMITS_CPU:-100m}"
CERT_MANAGER_WEBHOOK_RESOURCE_LIMITS_MEMORY="${CERT_MANAGER_WEBHOOK_RESOURCE_LIMITS_MEMORY:-128Mi}"
CERT_MANAGER_WEBHOOK_RESOURCE_REQUESTS_CPU="${CERT_MANAGER_WEBHOOK_RESOURCE_REQUESTS_CPU:-100m}"
CERT_MANAGER_WEBHOOK_RESOURCE_REQUESTS_MEMORY="${CERT_MANAGER_WEBHOOK_RESOURCE_REQUESTS_MEMORY:-128Mi}"
CERT_MANAGER_CAINJECTOR_RESOURCE_LIMITS_CPU="${CERT_MANAGER_CAINJECTOR_RESOURCE_LIMITS_CPU:-100m}"
CERT_MANAGER_CAINJECTOR_RESOURCE_LIMITS_MEMORY="${CERT_MANAGER_CAINJECTOR_RESOURCE_LIMITS_MEMORY:-128Mi}"
CERT_MANAGER_CAINJECTOR_RESOURCE_REQUESTS_CPU="${CERT_MANAGER_CAINJECTOR_RESOURCE_REQUESTS_CPU:-100m}"
CERT_MANAGER_CAINJECTOR_RESOURCE_REQUESTS_MEMORY="${CERT_MANAGER_CAINJECTOR_RESOURCE_REQUESTS_MEMORY:-128Mi}"
INSTALL_LOG_PATH=/tmp/cert-manager_install-$(date +'%Y-%m-%d_%H-%M-%S').log

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

online_install_cert_manager() {
  # check if cert-manager already installed
  if helm status ${RELEASE} -n "${CERT_MANAGER_KUBE_NAMESPACE}" &>/dev/null; then
    error "${RELEASE} already installed. Use helm remove it first"
  fi

  info "Start add helm bitnami repo"
  helm repo add bitnami https://charts.bitnami.com/bitnami &>/dev/null || error "Helm add bitnami repo error."
  info "Start update helm bitnami repo"
  helm repo update bitnami 2>/dev/null || error "Helm update bitnami repo error."

  info "Install cert-manager, It might take a long time..."
  helm install ${RELEASE} ${CHART} \
    --version "${CHART_VERSION}" \
    --namespace "${CERT_MANAGER_KUBE_NAMESPACE}" \
    --create-namespace \
    --set installCRDs=true \
    --set controller.nodeSelector."cert-manager/node"="enable" \
    --set-string controller.resources.limits.cpu="${CERT_MANAGER_RESOURCE_LIMITS_CPU}" \
    --set-string controller.resources.limits.memory="${CERT_MANAGER_RESOURCE_LIMITS_MEMORY}" \
    --set-string controller.resources.requests.cpu="${CERT_MANAGER_RESOURCE_REQUESTS_CPU}" \
    --set-string controller.resources.requests.memory="${CERT_MANAGER_RESOURCE_REQUESTS_MEMORY}" \
    --set 'controller.extraArgs={--enable-certificate-owner-ref=true}' \
    --set webhook.nodeSelector."cert-manager/node"="enable" \
    --set-string webhook.resources.limits.cpu="${CERT_MANAGER_WEBHOOK_RESOURCE_LIMITS_CPU}" \
    --set-string webhook.resources.limits.memory="${CERT_MANAGER_WEBHOOK_RESOURCE_LIMITS_MEMORY}" \
    --set-string webhook.resources.requests.cpu="${CERT_MANAGER_WEBHOOK_RESOURCE_REQUESTS_CPU}" \
    --set-string webhook.resources.requests.memory="${CERT_MANAGER_WEBHOOK_RESOURCE_REQUESTS_MEMORY}" \
    --set cainjector.nodeSelector."cert-manager/node"="enable" \
    --set-string cainjector.resources.limits.cpu="${CERT_MANAGER_CAINJECTOR_RESOURCE_LIMITS_CPU}" \
    --set-string cainjector.resources.limits.memory="${CERT_MANAGER_CAINJECTOR_RESOURCE_LIMITS_MEMORY}" \
    --set-string cainjector.resources.requests.cpu="${CERT_MANAGER_CAINJECTOR_RESOURCE_REQUESTS_CPU}" \
    --set-string cainjector.resources.requests.memory="${CERT_MANAGER_CAINJECTOR_RESOURCE_REQUESTS_MEMORY}" \
    --timeout $TIME_OUT_SECOND \
    --wait 2>&1 | tee -a "${INSTALL_LOG_PATH}" || {
    error "Fail to install ${RELEASE}."
  }

  #TODO: check more resources after install
}

offline_install_cert_manager() {
  # check if cert-manager already installed
  if helm status ${RELEASE} -n "${CERT_MANAGER_KUBE_NAMESPACE}" &>/dev/null; then
    error "${RELEASE} already installed. Use helm remove it first"
  fi

  [[ -d "${CERT_MANAGER_CHART_DIR}" ]] || error "CERT_MANAGER_CHART_DIR not exist."

  info "Install cert-manager, It might take a long time..."
  helm install ${RELEASE} "${CERT_MANAGER_CHART_DIR}" \
    --version "${CHART_VERSION}" \
    --namespace "${CERT_MANAGER_KUBE_NAMESPACE}" \
    --create-namespace \
    --set-string global.imageRegistry="${CERT_MANAGER_IMAGE_REGISTRY}" \
    --set installCRDs=true \
    --set controller.nodeSelector."cert-manager/node"="enable" \
    --set-string controller.resources.limits.cpu="${CERT_MANAGER_RESOURCE_LIMITS_CPU}" \
    --set-string controller.resources.limits.memory="${CERT_MANAGER_RESOURCE_LIMITS_MEMORY}" \
    --set-string controller.resources.requests.cpu="${CERT_MANAGER_RESOURCE_REQUESTS_CPU}" \
    --set-string controller.resources.requests.memory="${CERT_MANAGER_RESOURCE_REQUESTS_MEMORY}" \
    --set 'controller.extraArgs={--enable-certificate-owner-ref=true}' \
    --set webhook.nodeSelector."cert-manager/node"="enable" \
    --set-string webhook.resources.limits.cpu="${CERT_MANAGER_WEBHOOK_RESOURCE_LIMITS_CPU}" \
    --set-string webhook.resources.limits.memory="${CERT_MANAGER_WEBHOOK_RESOURCE_LIMITS_MEMORY}" \
    --set-string webhook.resources.requests.cpu="${CERT_MANAGER_WEBHOOK_RESOURCE_REQUESTS_CPU}" \
    --set-string webhook.resources.requests.memory="${CERT_MANAGER_WEBHOOK_RESOURCE_REQUESTS_MEMORY}" \
    --set cainjector.nodeSelector."cert-manager/node"="enable" \
    --set-string cainjector.resources.limits.cpu="${CERT_MANAGER_CAINJECTOR_RESOURCE_LIMITS_CPU}" \
    --set-string cainjector.resources.limits.memory="${CERT_MANAGER_CAINJECTOR_RESOURCE_LIMITS_MEMORY}" \
    --set-string cainjector.resources.requests.cpu="${CERT_MANAGER_CAINJECTOR_RESOURCE_REQUESTS_CPU}" \
    --set-string cainjector.resources.requests.memory="${CERT_MANAGER_CAINJECTOR_RESOURCE_REQUESTS_MEMORY}" \
    --timeout $TIME_OUT_SECOND \
    --wait 2>&1 | tee -a "${INSTALL_LOG_PATH}" || {
    error "Fail to install ${RELEASE}."
  }

  #TODO: check more resources after install
}

verify_supported() {
  [[ -n "${CERT_MANAGER_NODE_NAMES}" ]] || error "CERT_MANAGER_NODE_NAMES MUST set in environment variable."

  local node
  local node_array
  IFS="," read -r -a node_array <<<"${CERT_MANAGER_NODE_NAMES}"
  for node in "${node_array[@]}"; do
    kubectl label node "${node}" 'cert-manager/node=enable' --overwrite &>/dev/null || {
      error "kubectl label node ${node} 'cert-manager/node=enable' failed, use kubectl to check reason"
    }
  done
}

init_log() {
  touch "${INSTALL_LOG_PATH}" || error "Create log file ${INSTALL_LOG_PATH} error"
  info "Log file create in path ${INSTALL_LOG_PATH}"
}

############################################
# Check if helm release deployment correctly
# Arguments:
#   release
#   namespace
############################################
verify_installed() {
  local status
  status=$(helm status "${RELEASE}" -n "${CERT_MANAGER_KUBE_NAMESPACE}" -o yaml | yq -r '.info.status')
  [[ "${status}" == "deployed" ]] || {
    error "Helm release ${RELEASE} status is not deployed, use helm to check reason"
  }

  info "${RELEASE} Deployment Completed!"
}

main() {
  init_log
  verify_supported
  if [[ ${OFFLINE_INSTALL} == "false" ]]; then
    online_install_cert_manager
  elif [[ ${OFFLINE_INSTALL} == "true" ]]; then
    offline_install_cert_manager
  fi
  verify_installed
}

main
