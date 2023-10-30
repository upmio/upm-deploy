#!/usr/bin/env bash

# You must be prepared as follows before run install.sh:
#
# 1. CLUSTERPEDIA_CONTROLLER_NODE_NAMES MUST be set as environment variable, for an example:
#
#        export CLUSTERPEDIA_CONTROLLER_NODE_NAMES="master01,master02"
#
# 2. CLUSTERPEDIA_WORKER_NODE_NAMES MUST be set as environment variable, for an example:
#
#        export CLUSTERPEDIA_WORKER_NODE_NAMES="worker01,worker02"
#
# 3. CLUSTERPEDIA_MYSQL_HOST MUST be set as environment variable, for an example:
#
#        export CLUSTERPEDIA_MYSQL_HOST="192.168.1.100"
#
# 4. CLUSTERPEDIA_MYSQL_PORT MUST be set as environment variable, for an example:
#
#        export CLUSTERPEDIA_MYSQL_PORT="3306"
#
# 5. CLUSTERPEDIA_MYSQL_USER MUST be set as environment variable, for an example:
#
#        export CLUSTERPEDIA_MYSQL_USER="clusterpedia"
#
# 6. CLUSTERPEDIA_MYSQL_PASSWORD MUST be set as environment variable, for an example:
#
#        export CLUSTERPEDIA_MYSQL_PASSWORD="password"
#

readonly CHART="clusterpedia/clusterpedia"
readonly RELEASE="clusterpedia"
readonly TIME_OUT_SECOND="600s"
readonly CHART_VERSION="1.9.1"

OFFLINE_INSTALL="${OFFLINE_INSTALL:-false}"
CLUSTERPEDIA_KUBE_NAMESPACE="${CLUSTERPEDIA_KUBE_NAMESPACE:-clusterpedia}"
CLUSTERPEDIA_MYSQL_DATABASE="${CLUSTERPEDIA_MYSQL_DATABASE:-clusterpedia}"
CLUSTERPEDIA_RESOURCE_LIMITS="${CLUSTERPEDIA_RESOURCE_LIMITS:-1}"
CLUSTERPEDIA_CREATE_SYNCRESOURCES="${CLUSTERPEDIA_CREATE_SYNCRESOURCES:-false}"
CLUSTERPEDIA_CREATE_PEDIACLUSTERS="${CLUSTERPEDIA_CREATE_PEDIACLUSTERS:-false}"
INSTALL_LOG_PATH=/tmp/clusterpedia_install-$(date +'%Y-%m-%d_%H-%M-%S').log

if [[ ${CLUSTERPEDIA_RESOURCE_LIMITS} -eq 0 ]]; then
  CLUSTERPEDIA_APISERVER_RESOURCE_LIMITS_CPU="0"
  CLUSTERPEDIA_APISERVER_RESOURCE_LIMITS_MEMORY="0"
  CLUSTERPEDIA_APISERVER_RESOURCE_REQUESTS_CPU="0"
  CLUSTERPEDIA_APISERVER_RESOURCE_REQUESTS_MEMORY="0"
  CLUSTERPEDIA_SYBCHRO_RESOURCE_LIMITS_CPU="0"
  CLUSTERPEDIA_SYBCHRO_RESOURCE_LIMITS_MEMORY="0"
  CLUSTERPEDIA_SYBCHRO_RESOURCE_REQUESTS_CPU="0"
  CLUSTERPEDIA_SYBCHRO_RESOURCE_REQUESTS_MEMORY="0"
elif [[ ${CLUSTERPEDIA_RESOURCE_LIMITS} -gt 0 && ${CLUSTERPEDIA_RESOURCE_LIMITS} -le 4 ]]; then
  CLUSTERPEDIA_APISERVER_RESOURCE_LIMITS_CPU="1000m"
  CLUSTERPEDIA_APISERVER_RESOURCE_LIMITS_MEMORY="${CLUSTERPEDIA_RESOURCE_LIMITS}Gi"
  CLUSTERPEDIA_APISERVER_RESOURCE_REQUESTS_CPU="1000m"
  CLUSTERPEDIA_APISERVER_RESOURCE_REQUESTS_MEMORY="${CLUSTERPEDIA_RESOURCE_LIMITS}Gi"
  CLUSTERPEDIA_SYBCHRO_RESOURCE_LIMITS_CPU="1000m"
  CLUSTERPEDIA_SYBCHRO_RESOURCE_LIMITS_MEMORY="${CLUSTERPEDIA_RESOURCE_LIMITS}Gi"
  CLUSTERPEDIA_SYBCHRO_RESOURCE_REQUESTS_CPU="1000m"
  CLUSTERPEDIA_SYBCHRO_RESOURCE_REQUESTS_MEMORY="${CLUSTERPEDIA_RESOURCE_LIMITS}Gi"
elif [[ ${CLUSTERPEDIA_RESOURCE_LIMITS} -gt 4 ]]; then
  CLUSTERPEDIA_APISERVER_RESOURCE_LIMITS_CPU="2000m"
  CLUSTERPEDIA_APISERVER_RESOURCE_LIMITS_MEMORY="${CLUSTERPEDIA_RESOURCE_LIMITS}Gi"
  CLUSTERPEDIA_APISERVER_RESOURCE_REQUESTS_CPU="2000m"
  CLUSTERPEDIA_APISERVER_RESOURCE_REQUESTS_MEMORY="${CLUSTERPEDIA_RESOURCE_LIMITS}Gi"
  CLUSTERPEDIA_SYBCHRO_RESOURCE_LIMITS_CPU="2000m"
  CLUSTERPEDIA_SYBCHRO_RESOURCE_LIMITS_MEMORY="${CLUSTERPEDIA_RESOURCE_LIMITS}Gi"
  CLUSTERPEDIA_SYBCHRO_RESOURCE_REQUESTS_CPU="2000m"
  CLUSTERPEDIA_SYBCHRO_RESOURCE_REQUESTS_MEMORY="${CLUSTERPEDIA_RESOURCE_LIMITS}Gi"
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

online_install_clusterpedia() {
  info "Install clusterpedia..."
  # check if clusterpedia already installed
  if helm status "${RELEASE}" -n "${CLUSTERPEDIA_KUBE_NAMESPACE}" &>/dev/null; then
    error "${RELEASE} already installed. Use helm remove it first"
  fi

  info "Start init helm clusterpedia repo"
  helm repo add clusterpedia https://clusterpedia-io.github.io/clusterpedia-helm/ &>/dev/null || {
    error "Helm repo add clusterpedia error."
  }
  info "Start update helm clusterpedia repo"
  if ! helm repo update clusterpedia 2>/dev/null; then
    error "Helm update clusterpedia repo error."
  fi

  info "Install ${RELEASE}, It might take a long time..."
  helm install "${RELEASE}" "${CHART}" \
    --version "${CHART_VERSION}" \
    --namespace "${CLUSTERPEDIA_KUBE_NAMESPACE}" \
    --create-namespace \
    --set installCRDs=true \
    --set postgresql.enabled=false \
    --set mysql.enabled=false \
    --set-string mysql.image.repository="bitnami/mysql" \
    --set-string mysql.image.tag="8.0.34-debian-11-r75" \
    --set persistenceMatchNode=None \
    --set storageInstallMode="external" \
    --set externalStorage.createDatabase=true \
    --set externalStorage.type="mysql" \
    --set externalStorage.host="${CLUSTERPEDIA_MYSQL_HOST}" \
    --set externalStorage.port="${CLUSTERPEDIA_MYSQL_PORT}" \
    --set externalStorage.user="${CLUSTERPEDIA_MYSQL_USER}" \
    --set externalStorage.password="${CLUSTERPEDIA_MYSQL_PASSWORD}" \
    --set externalStorage.database="${CLUSTERPEDIA_MYSQL_DATABASE}" \
    --set controllerManager.replicaCount="${CLUSTERPEDIA_CONTROLLER_NODE_COUNT}" \
    --set controllerManager.nodeSelector."clusterpedia\.io/control-plane"="enable" \
    --set apiserver.replicaCount="${CLUSTERPEDIA_CONTROLLER_NODE_COUNT}" \
    --set apiserver.nodeSelector."clusterpedia\.io/control-plane"="enable" \
    --set-string apiserver.resources.limits.cpu="${CLUSTERPEDIA_APISERVER_RESOURCE_LIMITS_CPU}" \
    --set-string apiserver.resources.limits.memory="${CLUSTERPEDIA_APISERVER_RESOURCE_LIMITS_MEMORY}" \
    --set-string apiserver.resources.requests.cpu="${CLUSTERPEDIA_APISERVER_RESOURCE_REQUESTS_CPU}" \
    --set-string apiserver.resources.requests.memory="${CLUSTERPEDIA_APISERVER_RESOURCE_REQUESTS_MEMORY}" \
    --set clustersynchroManager.replicaCount="${CLUSTERPEDIA_WORKER_NODE_COUNT}" \
    --set clustersynchroManager.nodeSelector."clusterpedia\.io/worker"="enable" \
    --set clustersynchroManager.featureGates."AllowSyncAllCustomResources"="true" \
    --set clustersynchroManager.featureGates."AllowSyncAllResources"="true" \
    --set-string clustersynchroManager.resources.limits.cpu="${CLUSTERPEDIA_SYBCHRO_RESOURCE_LIMITS_CPU}" \
    --set-string clustersynchroManager.resources.limits.memory="${CLUSTERPEDIA_SYBCHRO_RESOURCE_LIMITS_MEMORY}" \
    --set-string clustersynchroManager.resources.requests.cpu="${CLUSTERPEDIA_SYBCHRO_RESOURCE_REQUESTS_CPU}" \
    --set-string clustersynchroManager.resources.requests.memory="${CLUSTERPEDIA_SYBCHRO_RESOURCE_REQUESTS_MEMORY}" \
    --timeout $TIME_OUT_SECOND \
    --wait 2>&1 | tee -a "${INSTALL_LOG_PATH}" || {
    error "Fail to install ${RELEASE}."
  }

  #TODO: check more resources after install
}

offline_install_clusterpedia() {
  info "Install clusterpedia..."
  # check if clusterpedia already installed
  if helm status "${RELEASE}" -n "${CLUSTERPEDIA_KUBE_NAMESPACE}" &>/dev/null; then
    error "${RELEASE} already installed. Use helm remove it first"
  fi

  [[ -d "${CLUSTERPEDIA_CHART_DIR}" ]] || error "CLUSTERPEDIA_CHART_DIR not exist."
  [[ -n "${IMAGE_REGISTRY}" ]] || error "IMAGE_REGISTRY MUST set in environment variable."

  info "Install ${RELEASE}, It might take a long time..."
  helm install "${RELEASE}" "${CLUSTERPEDIA_CHART_DIR}" \
    --namespace "${CLUSTERPEDIA_KUBE_NAMESPACE}" \
    --create-namespace \
    --set installCRDs=true \
    --set postgresql.enabled=false \
    --set mysql.enabled=false \
    --set-string mysql.image.repository="bitnami/mysql" \
    --set-string mysql.image.tag="8.0.34-debian-11-r75" \
    --set persistenceMatchNode=None \
    --set storageInstallMode="external" \
    --set externalStorage.createDatabase=true \
    --set externalStorage.type="mysql" \
    --set externalStorage.host="${CLUSTERPEDIA_MYSQL_HOST}" \
    --set externalStorage.port="${CLUSTERPEDIA_MYSQL_PORT}" \
    --set externalStorage.user="${CLUSTERPEDIA_MYSQL_USER}" \
    --set externalStorage.password="${CLUSTERPEDIA_MYSQL_PASSWORD}" \
    --set externalStorage.database="${CLUSTERPEDIA_MYSQL_DATABASE}" \
    --set controllerManager.replicaCount="${CLUSTERPEDIA_CONTROLLER_NODE_COUNT}" \
    --set controllerManager.nodeSelector."clusterpedia\.io/control-plane"="enable" \
    --set apiserver.replicaCount="${CLUSTERPEDIA_CONTROLLER_NODE_COUNT}" \
    --set apiserver.nodeSelector."clusterpedia\.io/control-plane"="enable" \
    --set-string apiserver.resources.limits.cpu="${CLUSTERPEDIA_APISERVER_RESOURCE_LIMITS_CPU}" \
    --set-string apiserver.resources.limits.memory="${CLUSTERPEDIA_APISERVER_RESOURCE_LIMITS_MEMORY}" \
    --set-string apiserver.resources.requests.cpu="${CLUSTERPEDIA_APISERVER_RESOURCE_REQUESTS_CPU}" \
    --set-string apiserver.resources.requests.memory="${CLUSTERPEDIA_APISERVER_RESOURCE_REQUESTS_MEMORY}" \
    --set clustersynchroManager.replicaCount="${CLUSTERPEDIA_WORKER_NODE_COUNT}" \
    --set clustersynchroManager.nodeSelector."clusterpedia\.io/worker"="enable" \
    --set clustersynchroManager.featureGates."AllowSyncAllCustomResources"="true" \
    --set clustersynchroManager.featureGates."AllowSyncAllResources"="true" \
    --set-string clustersynchroManager.resources.limits.cpu="${CLUSTERPEDIA_SYBCHRO_RESOURCE_LIMITS_CPU}" \
    --set-string clustersynchroManager.resources.limits.memory="${CLUSTERPEDIA_SYBCHRO_RESOURCE_LIMITS_MEMORY}" \
    --set-string clustersynchroManager.resources.requests.cpu="${CLUSTERPEDIA_SYBCHRO_RESOURCE_REQUESTS_CPU}" \
    --set-string clustersynchroManager.resources.requests.memory="${CLUSTERPEDIA_SYBCHRO_RESOURCE_REQUESTS_MEMORY}" \
    --timeout $TIME_OUT_SECOND \
    --wait 2>&1 | tee -a "${INSTALL_LOG_PATH}" || {
    error "Fail to install ${RELEASE}."
  }

  #TODO: check more resources after install
}

verify_supported() {
  installed helm || error "helm is required"
  installed kubectl || error "kubectl is required"
  installed curl || error "curl is required"

  [[ -n "${CLUSTERPEDIA_MYSQL_HOST}" ]] || error "CLUSTERPEDIA_MYSQL_HOST MUST set in environment variable."
  [[ -n "${CLUSTERPEDIA_MYSQL_PORT}" ]] || error "CLUSTERPEDIA_MYSQL_PORT MUST set in environment variable."
  [[ -n "${CLUSTERPEDIA_MYSQL_USER}" ]] || error "CLUSTERPEDIA_MYSQL_USER MUST set in environment variable."
  [[ -n "${CLUSTERPEDIA_MYSQL_PASSWORD}" ]] || error "CLUSTERPEDIA_MYSQL_PASSWORD MUST set in environment variable."

  [[ -n "${CLUSTERPEDIA_CONTROLLER_NODE_NAMES}" ]] || error "CLUSTERPEDIA_CONTROLLER_NODE_NAMES MUST set in environment variable."
  [[ -n "${CLUSTERPEDIA_WORKER_NODE_NAMES}" ]] || error "CLUSTERPEDIA_WORKER_NODE_NAMES MUST set in environment variable."

  local control_node
  local control_node_array
  IFS="," read -r -a control_node_array <<<"${CLUSTERPEDIA_CONTROLLER_NODE_NAMES}"
  CLUSTERPEDIA_CONTROLLER_NODE_COUNT=0
  for control_node in "${control_node_array[@]}"; do
    kubectl label node "${control_node}" 'clusterpedia.io/control-plane=enable' --overwrite &>/dev/null || {
      error "kubectl label node ${control_node} 'clusterpedia.io/control-plane=enable' failed, use kubectl to check reason"
    }
    ((CLUSTERPEDIA_CONTROLLER_NODE_COUNT++))
  done

  local worker_node
  local worker_node_array
  IFS="," read -r -a worker_node_array <<<"${CLUSTERPEDIA_WORKER_NODE_NAMES}"
  CLUSTERPEDIA_WORKER_NODE_COUNT=0
  for worker_node in "${worker_node_array[@]}"; do
    kubectl label node "${worker_node}" 'clusterpedia.io/worker=enable' --overwrite &>/dev/null || {
      error "kubectl label node ${worker_node} 'clusterpedia.io/worker=enable' failed, use kubectl to check reason"
    }
    ((CLUSTERPEDIA_WORKER_NODE_COUNT++))
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
  status=$(helm status "${RELEASE}" -n "${CLUSTERPEDIA_KUBE_NAMESPACE}" -o yaml | yq -r '.info.status')
  [[ "${status}" == "deployed" ]] || error "Helm release ${RELEASE} status is not deployed, use helm to check reason"

  info "${RELEASE} Deployment Completed!"
}

create_clustersyncresources() {
  if [[ ${CLUSTERPEDIA_CREATE_SYNCRESOURCES} == "false" ]]; then
    info "CLUSTERPEDIA_CREATE_SYNCRESOURCES is false, skip create clustersyncresources."
    return
  fi

  [[ -f ${CLUSTERPEDIA_SYNCRESOURCES_YAML} ]] || {
    local download_url="https://raw.githubusercontent.com/upmio/upm-deploy/main/addons/clusterpedia/yaml/clustersyncresources.yaml"
    curl -sSL "${download_url}" -o "${CLUSTERPEDIA_SYNCRESOURCES_YAML}" || {
      error "curl get clustersyncresources.yaml failed"
    }
  }
  kubectl apply -f "${CLUSTERPEDIA_SYNCRESOURCES_YAML}" || {
    error "kubectl create clustersyncresources failed, check log use kubectl."
  }

  info "create clustersyncresources successful!"
}

create_pediaclusters() {
  if [[ ${CLUSTERPEDIA_CREATE_PEDIACLUSTERS} == "false" ]]; then
    info "CLUSTERPEDIA_CREATE_PEDIACLUSTERS is false, skip create pediaclusters."
    return
  fi

  [[ -f ${CLUSTERPEDIA_PEDIACLUSTERS_YAML} ]] || {
    error "curl get pediaclusters.yaml failed"
  }
  kubectl apply -f "${CLUSTERPEDIA_PEDIACLUSTERS_YAML}" || {
    error "kubectl create pediaclusters failed, check log use kubectl."
  }

  info "create pediaclusters successful!"
}

main() {
  init_log
  verify_supported
  if [[ ${OFFLINE_INSTALL} == "false" ]]; then
    online_install_clusterpedia
  elif [[ ${OFFLINE_INSTALL} == "true" ]]; then
    offline_install_clusterpedia
  fi
  verify_installed
  create_clustersyncresources
  create_pediaclusters
}

main
