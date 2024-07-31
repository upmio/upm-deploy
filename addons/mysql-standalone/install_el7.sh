#!/usr/bin/env bash

# You must be prepared as follows before run install.sh:
#
# 1. MYSQL_PWD MUST be set as environment variable, for an example:
#
#        export MYSQL_PWD="password"
#
#
# 2. MYSQL_STORAGECLASS_NAME MUST be set as environment variable, for an example:
#
#        export MYSQL_STORAGECLASS_NAME="openebs-lvmsc-hdd"
#
# 3. MYSQL_NODE_NAMES MUST be set as environment variable, for an example:
#
#        export MYSQL_NODE_NAMES="kube-node01"
#

readonly CHART="bitnami/mysql"
readonly RELEASE="mysql"
readonly TIME_OUT_SECOND="600s"
readonly CHART_VERSION="10.1.1"

OFFLINE_INSTALL="${OFFLINE_INSTALL:-false}"
MYSQL_PVC_SIZE_G="${MYSQL_PVC_SIZE_G:-20}"
MYSQL_SERVICE_TYPE="${MYSQL_SERVICE_TYPE:-ClusterIP}"
MYSQL_KUBE_NAMESPACE="${MYSQL_KUBE_NAMESPACE:-default}"
MYSQL_INITDB_CONFIGMAP="${MYSQL_INITDB_CONFIGMAP:-}"
MYSQL_RESOURCE_LIMITS="${MYSQL_RESOURCE_LIMITS:-1}"
INSTALL_LOG_PATH=/tmp/mysql-install-$(date +'%Y-%m-%d_%H-%M-%S').log

if [[ ${MYSQL_SERVICE_TYPE} == "NodePort" ]]; then
  MYSQL_NODEPORT="${MYSQL_NODEPORT:-32006}"
elif [[ ${MYSQL_SERVICE_TYPE} == "ClusterIP" ]] || [[ ${MYSQL_SERVICE_TYPE} == "LoadBalancer" ]]; then
  MYSQL_NODEPORT=null
else
  error "MYSQL_SERVICE_TYPE must be NodePort or ClusterIP or LoadBalancer"
fi

if [[ ${MYSQL_RESOURCE_LIMITS} -eq 0 ]]; then
  MYSQL_RESOURCE_LIMITS_CPU="0"
  MYSQL_RESOURCE_LIMITS_MEMORY="0"
  MYSQL_RESOURCE_REQUESTS_CPU="0"
  MYSQL_RESOURCE_REQUESTS_MEMORY="0"
elif [[ ${MYSQL_RESOURCE_LIMITS} -gt 0 && ${MYSQL_RESOURCE_LIMITS} -le 8 ]]; then
  MYSQL_RESOURCE_LIMITS_CPU="1000m"
  MYSQL_RESOURCE_LIMITS_MEMORY="${MYSQL_RESOURCE_LIMITS}Gi"
  MYSQL_RESOURCE_REQUESTS_CPU="1000m"
  MYSQL_RESOURCE_REQUESTS_MEMORY="${MYSQL_RESOURCE_LIMITS}Gi"
elif [[ ${MYSQL_RESOURCE_LIMITS} -gt 8 && ${MYSQL_RESOURCE_LIMITS} -le 16 ]]; then
  MYSQL_RESOURCE_LIMITS_CPU="2000m"
  MYSQL_RESOURCE_LIMITS_MEMORY="${MYSQL_RESOURCE_LIMITS}Gi"
  MYSQL_RESOURCE_REQUESTS_CPU="2000m"
  MYSQL_RESOURCE_REQUESTS_MEMORY="${MYSQL_RESOURCE_LIMITS}Gi"
elif [[ ${MYSQL_RESOURCE_LIMITS} -gt 16 ]]; then
  MYSQL_RESOURCE_LIMITS_CPU="4000m"
  MYSQL_RESOURCE_LIMITS_MEMORY="${MYSQL_RESOURCE_LIMITS}Gi"
  MYSQL_RESOURCE_REQUESTS_CPU="4000m"
  MYSQL_RESOURCE_REQUESTS_MEMORY="${MYSQL_RESOURCE_LIMITS}Gi"
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

online_install_mysql() {
  # check if mysql already installed
  if helm status ${RELEASE} -n "${MYSQL_KUBE_NAMESPACE}" &>/dev/null; then
    error "${RELEASE} already installed. Use helm remove it first"
  fi

  info "Start add helm bitnami repo"
  helm repo add bitnami https://charts.bitnami.com/bitnami &>/dev/null || error "Helm add bitnami repo error."

  info "Start update helm bitnami repo"
  helm repo update bitnami 2>/dev/null || error "Helm update bitnami repo error."

  if [[ -z ${MYSQL_CONFIG_FILE} ]]; then
    local mysql_conf="/tmp/bitnami-mysql.cnf"
    local download_url="https://raw.githubusercontent.com/upmio/upm-deploy/main/addons/mysql-standalone/config/my.cnf"
    curl -sSL ${download_url} -o "${mysql_conf}" || error "get mysql config failed"
  else
    [[ -f ${MYSQL_CONFIG_FILE} ]] || error "MYSQL_CONFIG_FILE not exist."
    local mysql_conf="${MYSQL_CONFIG_FILE}"
  fi

  info "Install mysql, It might take a long time..."
  helm install ${RELEASE} ${CHART} \
    --debug \
    --version "${CHART_VERSION}" \
    --namespace "${MYSQL_KUBE_NAMESPACE}" \
    --create-namespace \
    --set-string initdbScriptsConfigMap="${MYSQL_INITDB_CONFIGMAP}" \
    --set-string architecture="standalone" \
    --set-string auth.rootPassword="${MYSQL_PWD}" \
    --set auth.createDatabase=false \
    --set-string primary.service.type="${MYSQL_SERVICE_TYPE}" \
    --set primary.service.nodePorts.mysql=${MYSQL_NODEPORT} \
    --set-file primary.configuration="${mysql_conf}" \
    --set-string primary.resources.limits.cpu="${MYSQL_RESOURCE_LIMITS_CPU}" \
    --set-string primary.resources.limits.memory="${MYSQL_RESOURCE_LIMITS_MEMORY}" \
    --set-string primary.resources.requests.cpu="${MYSQL_RESOURCE_REQUESTS_CPU}" \
    --set-string primary.resources.requests.memory="${MYSQL_RESOURCE_REQUESTS_MEMORY}" \
    --set-string primary.persistence.storageClass="${MYSQL_STORAGECLASS_NAME}" \
    --set-string primary.persistence.size="${MYSQL_PVC_SIZE_G}Gi" \
    --set-string primary.nodeAffinityPreset.type="hard" \
    --set-string primary.nodeAffinityPreset.key="mysql\.standalone\.node" \
    --set-string primary.nodeAffinityPreset.values='{enable}' \
    --timeout $TIME_OUT_SECOND \
    --wait 2>&1 | grep "\[debug\]" | awk '{$1="[Helm]"; $2=""; print }' | tee -a "${INSTALL_LOG_PATH}" || {
    error "Fail to install ${RELEASE}."
  }

  #TODO: check more resources after install
}

offline_install_mysql() {
  # check if mysql already installed
  if helm status ${RELEASE} -n "${MYSQL_KUBE_NAMESPACE}" &>/dev/null; then
    error "${RELEASE} already installed. Use helm remove it first"
  fi

  [[ -d "${MYSQL_CHART_DIR}" ]] || error "MYSQL_CHART_DIR not exist."
  [[ -f ${MYSQL_CONFIG_FILE} ]] || error "MYSQL_CONFIG_FILE not exist."
  local mysql_conf="${MYSQL_CONFIG_FILE}"

  info "Install mysql, It might take a long time..."
  helm install "${RELEASE}" "${MYSQL_CHART_DIR}" \
    --namespace "${MYSQL_KUBE_NAMESPACE}" \
    --create-namespace \
    --set-string global.imageRegistry="${MYSQL_IMAGE_REGISTRY}" \
    --set-string initdbScriptsConfigMap="${MYSQL_INITDB_CONFIGMAP}" \
    --set-string architecture="standalone" \
    --set-string auth.rootPassword="${MYSQL_PWD}" \
    --set auth.createDatabase=false \
    --set-string primary.service.type="${MYSQL_SERVICE_TYPE}" \
    --set primary.service.nodePorts.mysql=${MYSQL_NODEPORT} \
    --set-file primary.configuration="${mysql_conf}" \
    --set-string primary.resources.limits.cpu="${MYSQL_RESOURCE_LIMITS_CPU}" \
    --set-string primary.resources.limits.memory="${MYSQL_RESOURCE_LIMITS_MEMORY}" \
    --set-string primary.resources.requests.cpu="${MYSQL_RESOURCE_REQUESTS_CPU}" \
    --set-string primary.resources.requests.memory="${MYSQL_RESOURCE_REQUESTS_MEMORY}" \
    --set-string primary.persistence.storageClass="${MYSQL_STORAGECLASS_NAME}" \
    --set-string primary.persistence.size="${MYSQL_PVC_SIZE_G}Gi" \
    --set-string primary.nodeAffinityPreset.type="hard" \
    --set-string primary.nodeAffinityPreset.key="mysql\.standalone\.node" \
    --set-string primary.nodeAffinityPreset.values='{enable}' \
    --timeout $TIME_OUT_SECOND \
    --wait 2>&1 | tee -a "${INSTALL_LOG_PATH}" || {
    error "Fail to install ${RELEASE}."
  }

  #TODO: check more resources after install
}

verify_supported() {
  installed helm || error "helm is required"
  installed kubectl || error "kubectl is required"

  [[ -n "${MYSQL_PWD}" ]] || error "MYSQL_PWD MUST set in environment variable."
  [[ -n "${MYSQL_PVC_SIZE_G}" ]] || error "MYSQL_PVC_SIZE_G MUST set in environment variable."
  [[ -n "${MYSQL_NODE_NAMES}" ]] || error "MYSQL_NODE_NAMES MUST set in environment variable."

  if [[ -z "${MYSQL_STORAGECLASS_NAME}" ]]; then
    error "MYSQL_STORAGECLASS_NAME MUST set in environment variable."
  else
    kubectl get storageclasses "${MYSQL_STORAGECLASS_NAME}" &>/dev/null || {
      error "storageclass resources not all ready, use kubectl to check reason"
    }
  fi

  local node
  local db_node_array
  IFS="," read -r -a db_node_array <<<"${MYSQL_NODE_NAMES}"
  for node in "${db_node_array[@]}"; do
    kubectl label node "${node}" 'mysql.standalone.node=enable' --overwrite &>/dev/null || {
      error "kubectl label node ${node} 'mysql.standalone.node=enable' failed, use kubectl to check reason"
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
  status=$(helm status "${RELEASE}" -n "${MYSQL_KUBE_NAMESPACE}" -o yaml | yq -r '.info.status')
  [[ "${status}" == "deployed" ]] || {
    error "Helm release ${RELEASE} status is not deployed, use helm to check reason"
  }

  info "${RELEASE} Deployment Completed!"
}

main() {
  init_log
  verify_supported
  if [[ ${OFFLINE_INSTALL} == "false" ]]; then
    online_install_mysql
  elif [[ ${OFFLINE_INSTALL} == "true" ]]; then
    offline_install_mysql
  fi
  verify_installed
}

main
