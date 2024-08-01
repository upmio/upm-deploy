#!/usr/bin/env bash

# You must be prepared as follows before run install.sh:
#
# 1. LOCAL_PATH_CONTROLLER_NODE_NAMES MUST be set as environment variable, for an example:
#
#        export LOCAL_PATH_CONTROLLER_NODE_NAMES="master01,master02"
#
#
# 2. LOCAL_PATH_STORAGECLASS_NAME MUST be set as environment variable, for an example:
#
#        export LOCAL_PATH_STORAGECLASS_NAME="local-path"
#
# 3. LOCAL_PATH_NODE_PATH MUST be set as environment variable, for an example:
#
#        export LOCAL_PATH_NODE_PATH="/opt/local-path-provisioner"
#

readonly CHART="containeroo/local-path-provisioner"
readonly RELEASE="local-path-provisioner"
readonly TIME_OUT_SECOND="600s"
readonly CHART_VERSION="0.0.30"
readonly APP_VERSION="v0.0.28"

OFFLINE_INSTALL="${OFFLINE_INSTALL:-false}"
LOCAL_PATH_KUBE_NAMESPACE="${LOCAL_PATH_KUBE_NAMESPACE:-local-path-storage}"
INSTALL_LOG_PATH=/tmp/local-path-provisioner_install-$(date +'%Y-%m-%d_%H-%M-%S').log

LOCAL_PATH_CONTROLLER_RESOURCE_LIMITS_CPU="${LOCAL_PATH_CONTROLLER_RESOURCE_LIMITS_CPU:-500m}"
LOCAL_PATH_CONTROLLER_RESOURCE_LIMITS_MEMORY="${LOCAL_PATH_CONTROLLER_RESOURCE_LIMITS_MEMORY:-512Mi}"
LOCAL_PATH_CONTROLLER_RESOURCE_REQUESTS_CPU="${LOCAL_PATH_CONTROLLER_RESOURCE_REQUESTS_CPU:-500m}"
LOCAL_PATH_CONTROLLER_RESOURCE_REQUESTS_MEMORY="${LOCAL_PATH_CONTROLLER_RESOURCE_REQUESTS_MEMORY:-512Mi}"

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

online_install_local_path() {
  # check if local-path-provisioner already installed
  if helm status ${RELEASE} -n "${LOCAL_PATH_KUBE_NAMESPACE}" &>/dev/null; then
    error "${RELEASE} already installed. Use helm remove it first"
  fi

  info "Start add helm local-path-provisioner repo"
  helm repo add containeroo https://charts.containeroo.ch &>/dev/null || error "Helm add local-path-provisioner repo error."
  info "Start update helm local-path-provisioner repo"
  helm repo update containeroo 2>/dev/null || error "Helm update local-path-provisioner repo error."

  info "Install local-path-provisioner, It might take a long time..."
  helm install ${RELEASE} ${CHART} \
    --version "${CHART_VERSION}" \
    --namespace "${LOCAL_PATH_KUBE_NAMESPACE}" \
    --create-namespace \
    --set-string image.tag="${APP_VERSION}" \
    --set storageClass.create=true \
    --set-string storageClass.name="${LOCAL_PATH_STORAGECLASS_NAME}" \
    --set-string storageClass.reclaimPolicy="Delete" \
    --set-string nodePathMap[0].paths[0]="${LOCAL_PATH_NODE_PATH}" \
    --set nodeSelector."local-path-provisioner/control-plane"="enable" \
    --set resources.limits.cpu="${LOCAL_PATH_CONTROLLER_RESOURCE_LIMITS_CPU}" \
    --set resources.limits.memory="${LOCAL_PATH_CONTROLLER_RESOURCE_LIMITS_MEMORY}" \
    --set resources.requests.cpu="${LOCAL_PATH_CONTROLLER_RESOURCE_REQUESTS_CPU}" \
    --set resources.requests.memory="${LOCAL_PATH_CONTROLLER_RESOURCE_REQUESTS_MEMORY}" \
    --timeout $TIME_OUT_SECOND \
    --wait 2>&1 | tee -a "${INSTALL_LOG_PATH}" || {
    error "Fail to install ${RELEASE}."
  }

  #TODO: check more resources after install
}

offline_install_local_path() {
  # check if local-path-provisioner already installed
  if helm status ${RELEASE} -n "${LOCAL_PATH_KUBE_NAMESPACE}" &>/dev/null; then
    error "${RELEASE} already installed. Use helm remove it first"
  fi

  [[ -d "${LOCAL_PATH_CHART_DIR}" ]] || error "LOCAL_PATH_CHART_DIR not exist."
  [[ -n "${LOCAL_PATH_REGISTRY_URL}" ]] || error "LOCAL_PATH_REGISTRY_URL MUST set in environment variable."

  info "Install local-path-provisioner, It might take a long time..."
  helm install ${RELEASE} "${LOCAL_PATH_CHART_DIR}" \
    --version "${CHART_VERSION}" \
    --namespace "${LOCAL_PATH_KUBE_NAMESPACE}" \
    --create-namespace \
    --set-string privateRegistry.registryUrl="${LOCAL_PATH_REGISTRY_URL}" \
    --set-string image.tag="${APP_VERSION}" \
    --set storageClass.create=true \
    --set-string storageClass.name="${LOCAL_PATH_STORAGECLASS_NAME}" \
    --set-string storageClass.reclaimPolicy="Delete" \
    --set-string nodePathMap.paths="${LOCAL_PATH_NODE_PATH}" \
    --set nodeSelector."local-path-provisioner/control-plane"="enable" \
    --set resources.limits.cpu="${LOCAL_PATH_CONTROLLER_RESOURCE_LIMITS_CPU}" \
    --set resources.limits.memory="${LOCAL_PATH_CONTROLLER_RESOURCE_LIMITS_MEMORY}" \
    --set resources.requests.cpu="${LOCAL_PATH_CONTROLLER_RESOURCE_REQUESTS_CPU}" \
    --set resources.requests.memory="${LOCAL_PATH_CONTROLLER_RESOURCE_REQUESTS_MEMORY}" \
    --timeout $TIME_OUT_SECOND \
    --wait 2>&1 | tee -a "${INSTALL_LOG_PATH}" || {
    error "Fail to install ${RELEASE}."
  }

  #TODO: check more resources after install
}

verify_supported() {
  installed helm || error "helm is required"
  installed kubectl || error "kubectl is required"

  [[ -n "${LOCAL_PATH_STORAGECLASS_NAME}" ]] || error "LOCAL_PATH_STORAGECLASS_NAME MUST set in environment variable."
  [[ -n "${LOCAL_PATH_NODE_PATH}" ]] || error "LOCAL_PATH_NODE_PATH MUST set in environment variable."

  [[ -n "${LOCAL_PATH_CONTROLLER_NODE_NAMES}" ]] || error "LOCAL_PATH_CONTROLLER_NODE_NAMES MUST set in environment variable."
  local node
  local control_node_array
  IFS="," read -r -a control_node_array <<<"${LOCAL_PATH_CONTROLLER_NODE_NAMES}"
  for node in "${control_node_array[@]}"; do
    kubectl label node "${node}" 'local-path-provisioner/control-plane=enable' --overwrite &>/dev/null || {
      error "kubectl label node ${node} 'local-path-provisioner/control-plane' failed, use kubectl to check reason"
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
  status=$(helm status "${RELEASE}" -n "${LOCAL_PATH_KUBE_NAMESPACE}" | grep ^STATUS: | awk '{print $2}')
  [[ "${status}" == "deployed" ]] || {
    error "Helm release ${RELEASE} status is not deployed, use helm to check reason"
  }

  info "${RELEASE} Deployment Completed!"
}

main() {
  init_log
  verify_supported
  if [[ ${OFFLINE_INSTALL} == "false" ]]; then
    online_install_local_path
  elif [[ ${OFFLINE_INSTALL} == "true" ]]; then
    offline_install_local_path
  fi
  verify_installed
}

main
