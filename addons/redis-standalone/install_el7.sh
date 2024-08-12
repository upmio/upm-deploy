#!/usr/bin/env bash

set -o nounset
# You must be prepared as follows before run install.sh:
#
# 1. REDIS_PWD MUST be set as environment variable, for an example:
#
#        export REDIS_PWD="passwords"
#
# 2. REDIS_NODE_NAMES MUST be set as environment variable, for an example:
#
#        export REDIS_NODE_NAMES="kube-node01"
#

readonly CHART="bitnami/redis"
readonly RELEASE="redis"
readonly TIME_OUT_SECOND="600s"
readonly CHART_VERSION="20.0.1"

OFFLINE_INSTALL="${OFFLINE_INSTALL:-false}"
REDIS_SERVICE_TYPE="${REDIS_SERVICE_TYPE:-ClusterIP}"
REDIS_PORT="${REDIS_PORT:-6379}"
REDIS_KUBE_NAMESPACE="${REDIS_KUBE_NAMESPACE:-default}"
REDIS_RESOURCE_LIMITS="${REDIS_RESOURCE_LIMITS:-1}"
INSTALL_LOG_PATH=/tmp/redis-install-$(date +'%Y-%m-%d_%H-%M-%S').log

if [[ ${REDIS_SERVICE_TYPE} == "NodePort" ]]; then
  REDIS_NODEPORT="${REDIS_NODEPORT:-32007}"
elif [[ ${REDIS_SERVICE_TYPE} == "ClusterIP" ]] || [[ ${REDIS_SERVICE_TYPE} == "LoadBalancer" ]]; then
  REDIS_NODEPORT=null
else
  error "REDIS_SERVICE_TYPE must be NodePort or ClusterIP or LoadBalancer"
fi

if [[ ${REDIS_RESOURCE_LIMITS} -eq 0 ]]; then
  REDIS_RESOURCE_LIMITS_CPU="0"
  REDIS_RESOURCE_LIMITS_MEMORY="0"
  REDIS_RESOURCE_REQUESTS_CPU="0"
  REDIS_RESOURCE_REQUESTS_MEMORY="0"
elif [[ ${REDIS_RESOURCE_LIMITS} -gt 0 && ${REDIS_RESOURCE_LIMITS} -le 8 ]]; then
  REDIS_RESOURCE_LIMITS_CPU="1000m"
  REDIS_RESOURCE_LIMITS_MEMORY="${REDIS_RESOURCE_LIMITS}Gi"
  REDIS_RESOURCE_REQUESTS_CPU="1000m"
  REDIS_RESOURCE_REQUESTS_MEMORY="${REDIS_RESOURCE_LIMITS}Gi"
elif [[ ${REDIS_RESOURCE_LIMITS} -gt 8 ]]; then
  REDIS_RESOURCE_LIMITS_CPU="2000m"
  REDIS_RESOURCE_LIMITS_MEMORY="${REDIS_RESOURCE_LIMITS}Gi"
  REDIS_RESOURCE_REQUESTS_CPU="2000m"
  REDIS_RESOURCE_REQUESTS_MEMORY="${REDIS_RESOURCE_LIMITS}Gi"
fi

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

online_install_redis() {
  # check if redis already installed
  if helm status "${RELEASE}" -n "${REDIS_KUBE_NAMESPACE}" &>/dev/null; then
    error "${RELEASE} already installed. Use helm remove it first"
  fi

  info "Start add helm bitnami repo"
  helm repo add bitnami https://charts.bitnami.com/bitnami &>/dev/null || error "Helm add bitnami repo error."

  info "Start update helm bitnami repo"
  helm repo update bitnami 2>/dev/null || error "Helm update bitnami repo error."

  info "Install redis, It might take a long time..."
  helm install "${RELEASE}" "${CHART}" \
    --debug \
    --version "${CHART_VERSION}" \
    --namespace "${REDIS_KUBE_NAMESPACE}" \
    --create-namespace \
    --set-string global.redis.password="${REDIS_PWD}" \
    --set-string architecture="standalone" \
    --set-string master.resources.limits.cpu="${REDIS_RESOURCE_LIMITS_CPU}" \
    --set-string master.resources.limits.memory="${REDIS_RESOURCE_LIMITS_MEMORY}" \
    --set-string master.resources.requests.cpu="${REDIS_RESOURCE_REQUESTS_CPU}" \
    --set-string master.resources.requests.memory="${REDIS_RESOURCE_REQUESTS_MEMORY}" \
    --set master.count=1 \
    --set master.service.type="${REDIS_SERVICE_TYPE}" \
    --set master.service.nodePorts.redis=${REDIS_NODEPORT} \
    --set master.service.ports.redis="${REDIS_PORT}" \
    --set master.containerPorts.redis="${REDIS_PORT}" \
    --set master.persistence.enabled=false \
    --set master.nodeAffinityPreset.type="hard" \
    --set master.nodeAffinityPreset.key="redis\.standalone\.node" \
    --set master.nodeAffinityPreset.values='{enable}' \
    --timeout $TIME_OUT_SECOND \
    --wait 2>&1 | grep "\[debug\]" | awk '{$1="[Helm]"; $2=""; print }' | tee -a "${INSTALL_LOG_PATH}" || {
    error "Fail to install ${RELEASE}."
  }

  #TODO: check more resources after install
}

offline_install_redis() {
  # check if redis already installed
  if helm status "${RELEASE}" -n "${REDIS_KUBE_NAMESPACE}" &>/dev/null; then
    error "${RELEASE} already installed. Use helm remove it first"
  fi

  [[ -d "${REDIS_CHART_DIR}" ]] || error "REDIS_CHART_DIR not exist."

  info "Install redis, It might take a long time..."
  helm install "${RELEASE}" "${REDIS_CHART_DIR}" \
    --debug \
    --namespace "${REDIS_KUBE_NAMESPACE}" \
    --create-namespace \
    --set-string global.imageRegistry="${REDIS_IMAGE_REGISTRY}" \
    --set-string global.redis.password="${REDIS_PWD}" \
    --set-string architecture="standalone" \
    --set-string master.resources.limits.cpu="${REDIS_RESOURCE_LIMITS_CPU}" \
    --set-string master.resources.limits.memory="${REDIS_RESOURCE_LIMITS_MEMORY}" \
    --set-string master.resources.requests.cpu="${REDIS_RESOURCE_REQUESTS_CPU}" \
    --set-string master.resources.requests.memory="${REDIS_RESOURCE_REQUESTS_MEMORY}" \
    --set master.count=1 \
    --set master.service.type="${REDIS_SERVICE_TYPE}" \
    --set master.service.nodePorts.redis=${REDIS_NODEPORT} \
    --set master.service.ports.redis="${REDIS_PORT}" \
    --set master.containerPorts.redis="${REDIS_PORT}" \
    --set master.persistence.enabled=false \
    --set master.nodeAffinityPreset.type="hard" \
    --set master.nodeAffinityPreset.key="redis\.standalone\.node" \
    --set master.nodeAffinityPreset.values='{enable}' \
    --timeout $TIME_OUT_SECOND \
    --wait 2>&1 | grep "\[debug\]" | awk '{$1="[Helm]"; $2=""; print }' | tee -a "${INSTALL_LOG_PATH}" || {
    error "Fail to install ${RELEASE}."
  }

  #TODO: check more resources after install
}

verify_supported() {
  installed helm || error "helm is required"
  installed kubectl || error "kubectl is required"

  [[ -n "${REDIS_PWD}" ]] || error "REDIS_PWD MUST set in environment variable."
  [[ -n "${REDIS_NODE_NAMES}" ]] || error "REDIS_NODE_NAMES MUST set in environment variable."

  local node
  local redis_node_array
  IFS="," read -r -a redis_node_array <<<"${REDIS_NODE_NAMES}"
  for node in "${redis_node_array[@]}"; do
    kubectl label node "${node}" 'redis.standalone.node=enable' --overwrite &>/dev/null || {
      error "kubectl label node ${node} 'redis.standalone.node=enable' failed, use kubectl to check reason"
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
  status=$(helm status "${RELEASE}" -n "${REDIS_KUBE_NAMESPACE}" -o yaml | yq -r '.info.status')
  [[ "${status}" == "deployed" ]] || error "Helm release ${RELEASE} status is not deployed, use helm to check reason"

  info "${RELEASE} Deployment Completed!"
}

main() {
  init_log
  verify_supported
  if [[ ${OFFLINE_INSTALL} == "false" ]]; then
    online_install_redis
  elif [[ ${OFFLINE_INSTALL} == "true" ]]; then
    offline_install_redis
  fi
  verify_installed
}

main
