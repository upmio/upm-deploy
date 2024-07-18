#!/usr/bin/env bash

# You must be prepared as follows before run install.sh:
#
# 1. PLATFORM_NODE_NAMES MUST be set as environment variable, for an example:
#
#        export PLATFORM_NODE_NAMES="master01,master02"
#
# 2. PLATFORM_MYSQL_HOST MUST be set as environment variable, for an example:
#
#        export PLATFORM_MYSQL_HOST="mysql"
#
# 3. PLATFORM_MYSQL_PORT MUST be set as environment variable, for an example:
#
#        export PLATFORM_MYSQL_PORT="3306"
#
# 4. PLATFORM_MYSQL_USER MUST be set as environment variable, for an example:
#
#        export PLATFORM_MYSQL_USER="upm"
#
# 5. PLATFORM_MYSQL_PWD MUST be set as environment variable, for an example:
#
#        export PLATFORM_MYSQL_PWD="password"
#
# 6. PLATFORM_NACOS_HOST MUST be set as environment variable, for an example:
#
#        export PLATFORM_NACOS_HOST="nacos.nacos"
#
# 7. PLATFORM_NACOS_PORT MUST be set as environment variable, for an example:
#
#        export PLATFORM_NACOS_PORT="8848"
#
# 8. PLATFORM_NACOS_USER MUST be set as environment variable, for an example:
#
#        export PLATFORM_NACOS_USER="nacos"
#
# 9. PLATFORM_NACOS_PWD MUST be set as environment variable, for an example:
#
#        export PLATFORM_NACOS_PWD="nacos"
#
# 10. PLATFORM_REDIS_HOST MUST be set as environment variable, for an example:
#
#        export PLATFORM_REDIS_HOST="redis-master"
#
# 11. PLATFORM_REDIS_PORT MUST be set as environment variable, for an example:
#
#        export PLATFORM_REDIS_PORT="6379"
#
# 12. PLATFORM_REDIS_PWD MUST be set as environment variable, for an example:
#
#        export PLATFORM_REDIS_PWD="password"
#

readonly CHART="upm-charts/upm-platform"
readonly RELEASE="upm-platform"
readonly TIME_OUT_SECOND="600s"
readonly CHART_VERSION="1.1.1"
readonly UI_CN_VERSION="v1.1.2-CN"
readonly UI_EN_VERSION="v1.1.2-EN"
readonly API_VERSION="v1.1.2"
readonly HELIX_VERSION="v1.1.1"

OFFLINE_INSTALL="${OFFLINE_INSTALL:-false}"
PLATFORM_INIT_DB="${PLATFORM_INIT_DB:-false}"
PLATFORM_KUBE_NAMESPACE="${PLATFORM_KUBE_NAMESPACE:-upm-system}"
PLATFORM_SERVICE_TYPE="${PLATFORM_SERVICE_TYPE:-ClusterIP}"
INSTALL_LOG_PATH=/tmp/upm-platform_install-$(date +'%Y-%m-%d_%H-%M-%S').log
PLATFORM_RESOURCE_LIMITS="${PLATFORM_RESOURCE_LIMITS:-1}"
PLATFORM_EASYSEARCH_ENABLED="${PLATFORM_EASYSEARCH_ENABLED:-false}"
PLATFORM_UI_LANG="${PLATFORM_UI_LANG:-CN}"

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

if [[ ${PLATFORM_SERVICE_TYPE} == "NodePort" ]]; then
  PLATFORM_NODEPORT="${PLATFORM_NODEPORT:-32010}"
elif [[ ${PLATFORM_SERVICE_TYPE} == "ClusterIP" ]] || [[ ${PLATFORM_SERVICE_TYPE} == "LoadBalancer" ]]; then
  PLATFORM_NODEPORT=null
else
  error "PLATFORM_SERVICE_TYPE must be NodePort or ClusterIP or LoadBalancer"
fi

PLATFORM_NGINX_RESOURCE_LIMITS_CPU="${PLATFORM_NGINX_RESOURCE_LIMITS_CPU:-1000m}"
PLATFORM_NGINX_RESOURCE_LIMITS_MEMORY="${PLATFORM_NGINX_RESOURCE_LIMITS_MEMORY:-2Gi}"
PLATFORM_NGINX_RESOURCE_REQUESTS_CPU="${PLATFORM_NGINX_RESOURCE_REQUESTS_CPU:-1000m}"
PLATFORM_NGINX_RESOURCE_REQUESTS_MEMORY="${PLATFORM_NGINX_RESOURCE_REQUESTS_MEMORY:-2Gi}"
if [[ ${PLATFORM_RESOURCE_LIMITS} -eq 0 ]]; then
  PLATFORM_RESOURCE_LIMITS_CPU="0"
  PLATFORM_RESOURCE_LIMITS_MEMORY="0"
  PLATFORM_RESOURCE_REQUESTS_CPU="0"
  PLATFORM_RESOURCE_REQUESTS_MEMORY="0"
elif [[ ${PLATFORM_RESOURCE_LIMITS} -gt 0 && ${PLATFORM_RESOURCE_LIMITS} -le 4 ]]; then
  PLATFORM_RESOURCE_LIMITS_CPU="1000m"
  PLATFORM_RESOURCE_LIMITS_MEMORY="${PLATFORM_RESOURCE_LIMITS}Gi"
  PLATFORM_RESOURCE_REQUESTS_CPU="1000m"
  PLATFORM_RESOURCE_REQUESTS_MEMORY="${PLATFORM_RESOURCE_LIMITS}Gi"
elif [[ ${PLATFORM_RESOURCE_LIMITS} -gt 4 ]]; then
  PLATFORM_RESOURCE_LIMITS_CPU="2000m"
  PLATFORM_RESOURCE_LIMITS_MEMORY="${PLATFORM_RESOURCE_LIMITS}Gi"
  PLATFORM_RESOURCE_REQUESTS_CPU="2000m"
  PLATFORM_RESOURCE_REQUESTS_MEMORY="${PLATFORM_RESOURCE_LIMITS}Gi"
fi

if [[ ${PLATFORM_UI_LANG} == "CN" ]]; then
  UI_VERSION=${UI_CN_VERSION}
elif [[ ${PLATFORM_UI_LANG} == "EN" ]]; then
  UI_VERSION=${UI_EN_VERSION}
else
  error "PLATFORM_UI_LANG must be CN or EN"
fi

online_install_upm_platform() {
  # check if upm-platform already installed
  if helm status ${RELEASE} -n "${PLATFORM_KUBE_NAMESPACE}" &>/dev/null; then
    error "${RELEASE} already installed. Use helm remove it first"
  fi

  info "Start add helm upm-charts repo"
  helm repo add upm-charts https://upmio.github.io/helm-charts &>/dev/null || error "Helm add upm-charts repo error."
  info "Start update helm upm-charts repo"
  helm repo update upm-charts 2>/dev/null || error "Helm update upm-charts repo error."

  info "Install upm-platform, It might take a long time..."
  helm install ${RELEASE} ${CHART} \
    --version "${CHART_VERSION}" \
    --namespace "${PLATFORM_KUBE_NAMESPACE}" \
    --create-namespace \
    --set-string mysql.host="${PLATFORM_MYSQL_HOST}" \
    --set mysql.port="${PLATFORM_MYSQL_PORT}" \
    --set-string mysql.username="${PLATFORM_MYSQL_USER}" \
    --set-string mysql.password="${PLATFORM_MYSQL_PWD}" \
    --set-string redis.host="${PLATFORM_REDIS_HOST}" \
    --set redis.port="${PLATFORM_REDIS_PORT}" \
    --set-string redis.password="${PLATFORM_REDIS_PWD}" \
    --set-string nacos.host="${PLATFORM_NACOS_HOST}" \
    --set nacos.port="${PLATFORM_NACOS_PORT}" \
    --set-string nacos.username="${PLATFORM_NACOS_USER}" \
    --set-string nacos.password="${PLATFORM_NACOS_PWD}" \
    --set-string nginx.service.type="${PLATFORM_SERVICE_TYPE}" \
    --set nginx.service.nodePorts.http="${PLATFORM_NODEPORT}" \
    --set nginx.replicaCount="${PLATFORM_NODE_COUNT}" \
    --set-string nginx.nodeAffinityPreset.type="hard" \
    --set-string nginx.nodeAffinityPreset.key="upm\.platform\.node" \
    --set-string nginx.nodeAffinityPreset.values='{enable}' \
    --set-string nginx.resources.limits.cpu="${PLATFORM_NGINX_RESOURCE_LIMITS_CPU}" \
    --set-string nginx.resources.limits.memory="${PLATFORM_NGINX_RESOURCE_LIMITS_MEMORY}" \
    --set-string nginx.resources.requests.cpu="${PLATFORM_NGINX_RESOURCE_REQUESTS_CPU}" \
    --set-string nginx.resources.requests.memory="${PLATFORM_NGINX_RESOURCE_REQUESTS_MEMORY}" \
    --set-string ui.image.tag="${UI_VERSION}" \
    --set ui.replicaCount="${PLATFORM_NODE_COUNT}" \
    --set-string ui.nodeAffinityPreset.type="hard" \
    --set-string ui.nodeAffinityPreset.key="upm\.platform\.node" \
    --set-string ui.nodeAffinityPreset.values='{enable}' \
    --set-string ui.resources.limits.cpu="${PLATFORM_RESOURCE_LIMITS_CPU}" \
    --set-string ui.resources.limits.memory="${PLATFORM_RESOURCE_LIMITS_MEMORY}" \
    --set-string ui.resources.requests.cpu="${PLATFORM_RESOURCE_REQUESTS_CPU}" \
    --set-string ui.resources.requests.memory="${PLATFORM_RESOURCE_REQUESTS_MEMORY}" \
    --set-string auth.image.tag="${API_VERSION}" \
    --set auth.replicaCount="${PLATFORM_NODE_COUNT}" \
    --set-string auth.nodeAffinityPreset.type="hard" \
    --set-string auth.nodeAffinityPreset.key="upm\.platform\.node" \
    --set-string auth.nodeAffinityPreset.values='{enable}' \
    --set-string auth.resources.limits.cpu="${PLATFORM_RESOURCE_LIMITS_CPU}" \
    --set-string auth.resources.limits.memory="${PLATFORM_RESOURCE_LIMITS_MEMORY}" \
    --set-string auth.resources.requests.cpu="${PLATFORM_RESOURCE_REQUESTS_CPU}" \
    --set-string auth.resources.requests.memory="${PLATFORM_RESOURCE_REQUESTS_MEMORY}" \
    --set-string gateway.image.tag="${API_VERSION}" \
    --set gateway.replicaCount="${PLATFORM_NODE_COUNT}" \
    --set-string gateway.nodeAffinityPreset.type="hard" \
    --set-string gateway.nodeAffinityPreset.key="upm\.platform\.node" \
    --set-string gateway.nodeAffinityPreset.values='{enable}' \
    --set-string gateway.resources.limits.cpu="${PLATFORM_RESOURCE_LIMITS_CPU}" \
    --set-string gateway.resources.limits.memory="${PLATFORM_RESOURCE_LIMITS_MEMORY}" \
    --set-string gateway.resources.requests.cpu="${PLATFORM_RESOURCE_REQUESTS_CPU}" \
    --set-string gateway.resources.requests.memory="${PLATFORM_RESOURCE_REQUESTS_MEMORY}" \
    --set-string operatelog.image.tag="${API_VERSION}" \
    --set operatelog.replicaCount="${PLATFORM_NODE_COUNT}" \
    --set operatelog.initDB.enabled=${PLATFORM_INIT_DB} \
    --set-string operatelog.nodeAffinityPreset.type="hard" \
    --set-string operatelog.nodeAffinityPreset.key="upm\.platform\.node" \
    --set-string operatelog.nodeAffinityPreset.values='{enable}' \
    --set-string operatelog.resources.limits.cpu="${PLATFORM_RESOURCE_LIMITS_CPU}" \
    --set-string operatelog.resources.limits.memory="${PLATFORM_RESOURCE_LIMITS_MEMORY}" \
    --set-string operatelog.resources.requests.cpu="${PLATFORM_RESOURCE_REQUESTS_CPU}" \
    --set-string operatelog.resources.requests.memory="${PLATFORM_RESOURCE_REQUESTS_MEMORY}" \
    --set-string resource.image.tag="${API_VERSION}" \
    --set resource.replicaCount="${PLATFORM_NODE_COUNT}" \
    --set resource.initDB.enabled=${PLATFORM_INIT_DB} \
    --set-string resource.nodeAffinityPreset.type="hard" \
    --set-string resource.nodeAffinityPreset.key="upm\.platform\.node" \
    --set-string resource.nodeAffinityPreset.values='{enable}' \
    --set-string resource.resources.limits.cpu="${PLATFORM_RESOURCE_LIMITS_CPU}" \
    --set-string resource.resources.limits.memory="${PLATFORM_RESOURCE_LIMITS_MEMORY}" \
    --set-string resource.resources.requests.cpu="${PLATFORM_RESOURCE_REQUESTS_CPU}" \
    --set-string resource.resources.requests.memory="${PLATFORM_RESOURCE_REQUESTS_MEMORY}" \
    --set upm.easysearch.enabled=${PLATFORM_EASYSEARCH_ENABLED} \
    --set-string service-easysearch.image.tag="${API_VERSION}" \
    --set service-easysearch.replicaCount="${PLATFORM_NODE_COUNT}" \
    --set service-easysearch.initDB.enabled=${PLATFORM_INIT_DB} \
    --set-string service-easysearch.nodeAffinityPreset.type="hard" \
    --set-string service-easysearch.nodeAffinityPreset.key="upm\.platform\.node" \
    --set-string service-easysearch.nodeAffinityPreset.values='{enable}' \
    --set-string service-easysearch.resources.limits.cpu="${PLATFORM_RESOURCE_LIMITS_CPU}" \
    --set-string service-easysearch.resources.limits.memory="${PLATFORM_RESOURCE_LIMITS_MEMORY}" \
    --set-string service-easysearch.resources.requests.cpu="${PLATFORM_RESOURCE_REQUESTS_CPU}" \
    --set-string service-easysearch.resources.requests.memory="${PLATFORM_RESOURCE_REQUESTS_MEMORY}" \
    --set-string user.image.tag="${API_VERSION}" \
    --set user.replicaCount="${PLATFORM_NODE_COUNT}" \
    --set user.initDB.enabled=${PLATFORM_INIT_DB} \
    --set-string user.nodeAffinityPreset.type="hard" \
    --set-string user.nodeAffinityPreset.key="upm\.platform\.node" \
    --set-string user.nodeAffinityPreset.values='{enable}' \
    --set-string user.resources.limits.cpu="${PLATFORM_RESOURCE_LIMITS_CPU}" \
    --set-string user.resources.limits.memory="${PLATFORM_RESOURCE_LIMITS_MEMORY}" \
    --set-string user.resources.requests.cpu="${PLATFORM_RESOURCE_REQUESTS_CPU}" \
    --set-string user.resources.requests.memory="${PLATFORM_RESOURCE_REQUESTS_MEMORY}" \
    --set-string helix.image.tag="${HELIX_VERSION}" \
    --set helix.replicaCount="${PLATFORM_NODE_COUNT}" \
    --set-string helix.nodeAffinityPreset.type="hard" \
    --set-string helix.nodeAffinityPreset.key="upm\.platform\.node" \
    --set-string helix.nodeAffinityPreset.values='{enable}' \
    --set-string helix.resources.limits.cpu="${PLATFORM_RESOURCE_LIMITS_CPU}" \
    --set-string helix.resources.limits.memory="${PLATFORM_RESOURCE_LIMITS_MEMORY}" \
    --set-string helix.resources.requests.cpu="${PLATFORM_RESOURCE_REQUESTS_CPU}" \
    --set-string helix.resources.requests.memory="${PLATFORM_RESOURCE_REQUESTS_MEMORY}" \
    --timeout $TIME_OUT_SECOND \
    --wait 2>&1 | tee -a "${INSTALL_LOG_PATH}" || {
    error "Fail to install ${RELEASE}."
  }

  #TODO: check more resources after install
}

offline_install_upm_platform() {
  # check if upm-platform already installed
  if helm status ${RELEASE} -n "${PLATFORM_KUBE_NAMESPACE}" &>/dev/null; then
    error "${RELEASE} already installed. Use helm remove it first"
  fi

  local image_registry="${PLATFORM_IMAGE_REGISTRY:-}"
  [[ -d "${PLATFORM_CHART_DIR}" ]] || error "PLATFORM_CHART_DIR not exist."

  info "Install upm-platform, It might take a long time..."
  helm install ${RELEASE} "${PLATFORM_CHART_DIR}" \
    --namespace "${PLATFORM_KUBE_NAMESPACE}" \
    --create-namespace \
    --set-string global.imageRegistry="${image_registry}" \
    --set-string mysql.host="${PLATFORM_MYSQL_HOST}" \
    --set mysql.port="${PLATFORM_MYSQL_PORT}" \
    --set-string mysql.username="${PLATFORM_MYSQL_USER}" \
    --set-string mysql.password="${PLATFORM_MYSQL_PWD}" \
    --set-string redis.host="${PLATFORM_REDIS_HOST}" \
    --set redis.port="${PLATFORM_REDIS_PORT}" \
    --set-string redis.password="${PLATFORM_REDIS_PWD}" \
    --set-string nacos.host="${PLATFORM_NACOS_HOST}" \
    --set nacos.port="${PLATFORM_NACOS_PORT}" \
    --set-string nacos.username="${PLATFORM_NACOS_USER}" \
    --set-string nacos.password="${PLATFORM_NACOS_PWD}" \
    --set-string nginx.service.type="${PLATFORM_SERVICE_TYPE}" \
    --set nginx.service.nodePorts.http="${PLATFORM_NODEPORT}" \
    --set nginx.replicaCount="${PLATFORM_NODE_COUNT}" \
    --set-string nginx.nodeAffinityPreset.type="hard" \
    --set-string nginx.nodeAffinityPreset.key="upm\.platform\.node" \
    --set-string nginx.nodeAffinityPreset.values='{enable}' \
    --set-string nginx.resources.limits.cpu="${PLATFORM_NGINX_RESOURCE_LIMITS_CPU}" \
    --set-string nginx.resources.limits.memory="${PLATFORM_NGINX_RESOURCE_LIMITS_MEMORY}" \
    --set-string nginx.resources.requests.cpu="${PLATFORM_NGINX_RESOURCE_REQUESTS_CPU}" \
    --set-string nginx.resources.requests.memory="${PLATFORM_NGINX_RESOURCE_REQUESTS_MEMORY}" \
    --set-string ui.image.tag="${UI_VERSION}" \
    --set ui.replicaCount="${PLATFORM_NODE_COUNT}" \
    --set-string ui.nodeAffinityPreset.type="hard" \
    --set-string ui.nodeAffinityPreset.key="upm\.platform\.node" \
    --set-string ui.nodeAffinityPreset.values='{enable}' \
    --set-string ui.resources.limits.cpu="${PLATFORM_RESOURCE_LIMITS_CPU}" \
    --set-string ui.resources.limits.memory="${PLATFORM_RESOURCE_LIMITS_MEMORY}" \
    --set-string ui.resources.requests.cpu="${PLATFORM_RESOURCE_REQUESTS_CPU}" \
    --set-string ui.resources.requests.memory="${PLATFORM_RESOURCE_REQUESTS_MEMORY}" \
    --set-string auth.image.tag="${API_VERSION}" \
    --set auth.replicaCount="${PLATFORM_NODE_COUNT}" \
    --set-string auth.nodeAffinityPreset.type="hard" \
    --set-string auth.nodeAffinityPreset.key="upm\.platform\.node" \
    --set-string auth.nodeAffinityPreset.values='{enable}' \
    --set-string auth.resources.limits.cpu="${PLATFORM_RESOURCE_LIMITS_CPU}" \
    --set-string auth.resources.limits.memory="${PLATFORM_RESOURCE_LIMITS_MEMORY}" \
    --set-string auth.resources.requests.cpu="${PLATFORM_RESOURCE_REQUESTS_CPU}" \
    --set-string auth.resources.requests.memory="${PLATFORM_RESOURCE_REQUESTS_MEMORY}" \
    --set-string gateway.image.tag="${API_VERSION}" \
    --set gateway.replicaCount="${PLATFORM_NODE_COUNT}" \
    --set-string gateway.nodeAffinityPreset.type="hard" \
    --set-string gateway.nodeAffinityPreset.key="upm\.platform\.node" \
    --set-string gateway.nodeAffinityPreset.values='{enable}' \
    --set-string gateway.resources.limits.cpu="${PLATFORM_RESOURCE_LIMITS_CPU}" \
    --set-string gateway.resources.limits.memory="${PLATFORM_RESOURCE_LIMITS_MEMORY}" \
    --set-string gateway.resources.requests.cpu="${PLATFORM_RESOURCE_REQUESTS_CPU}" \
    --set-string gateway.resources.requests.memory="${PLATFORM_RESOURCE_REQUESTS_MEMORY}" \
    --set-string operatelog.image.tag="${API_VERSION}" \
    --set operatelog.replicaCount="${PLATFORM_NODE_COUNT}" \
    --set operatelog.initDB.enabled=${PLATFORM_INIT_DB} \
    --set-string operatelog.nodeAffinityPreset.type="hard" \
    --set-string operatelog.nodeAffinityPreset.key="upm\.platform\.node" \
    --set-string operatelog.nodeAffinityPreset.values='{enable}' \
    --set-string operatelog.resources.limits.cpu="${PLATFORM_RESOURCE_LIMITS_CPU}" \
    --set-string operatelog.resources.limits.memory="${PLATFORM_RESOURCE_LIMITS_MEMORY}" \
    --set-string operatelog.resources.requests.cpu="${PLATFORM_RESOURCE_REQUESTS_CPU}" \
    --set-string operatelog.resources.requests.memory="${PLATFORM_RESOURCE_REQUESTS_MEMORY}" \
    --set-string resource.image.tag="${API_VERSION}" \
    --set resource.replicaCount="${PLATFORM_NODE_COUNT}" \
    --set resource.initDB.enabled=${PLATFORM_INIT_DB} \
    --set-string resource.nodeAffinityPreset.type="hard" \
    --set-string resource.nodeAffinityPreset.key="upm\.platform\.node" \
    --set-string resource.nodeAffinityPreset.values='{enable}' \
    --set-string resource.resources.limits.cpu="${PLATFORM_RESOURCE_LIMITS_CPU}" \
    --set-string resource.resources.limits.memory="${PLATFORM_RESOURCE_LIMITS_MEMORY}" \
    --set-string resource.resources.requests.cpu="${PLATFORM_RESOURCE_REQUESTS_CPU}" \
    --set-string resource.resources.requests.memory="${PLATFORM_RESOURCE_REQUESTS_MEMORY}" \
    --set upm.easysearch.enabled=${PLATFORM_EASYSEARCH_ENABLED} \
    --set-string service-easysearch.image.tag="${API_VERSION}" \
    --set service-easysearch.replicaCount="${PLATFORM_NODE_COUNT}" \
    --set service-easysearch.initDB.enabled=${PLATFORM_INIT_DB} \
    --set-string service-easysearch.nodeAffinityPreset.type="hard" \
    --set-string service-easysearch.nodeAffinityPreset.key="upm\.platform\.node" \
    --set-string service-easysearch.nodeAffinityPreset.values='{enable}' \
    --set-string service-easysearch.resources.limits.cpu="${PLATFORM_RESOURCE_LIMITS_CPU}" \
    --set-string service-easysearch.resources.limits.memory="${PLATFORM_RESOURCE_LIMITS_MEMORY}" \
    --set-string service-easysearch.resources.requests.cpu="${PLATFORM_RESOURCE_REQUESTS_CPU}" \
    --set-string service-easysearch.resources.requests.memory="${PLATFORM_RESOURCE_REQUESTS_MEMORY}" \
    --set-string user.image.tag="${API_VERSION}" \
    --set user.replicaCount="${PLATFORM_NODE_COUNT}" \
    --set user.initDB.enabled=${PLATFORM_INIT_DB} \
    --set-string user.nodeAffinityPreset.type="hard" \
    --set-string user.nodeAffinityPreset.key="upm\.platform\.node" \
    --set-string user.nodeAffinityPreset.values='{enable}' \
    --set-string user.resources.limits.cpu="${PLATFORM_RESOURCE_LIMITS_CPU}" \
    --set-string user.resources.limits.memory="${PLATFORM_RESOURCE_LIMITS_MEMORY}" \
    --set-string user.resources.requests.cpu="${PLATFORM_RESOURCE_REQUESTS_CPU}" \
    --set-string user.resources.requests.memory="${PLATFORM_RESOURCE_REQUESTS_MEMORY}" \
    --set-string helix.image.tag="${HELIX_VERSION}" \
    --set helix.replicaCount="${PLATFORM_NODE_COUNT}" \
    --set-string helix.nodeAffinityPreset.type="hard" \
    --set-string helix.nodeAffinityPreset.key="upm\.platform\.node" \
    --set-string helix.nodeAffinityPreset.values='{enable}' \
    --set-string helix.resources.limits.cpu="${PLATFORM_RESOURCE_LIMITS_CPU}" \
    --set-string helix.resources.limits.memory="${PLATFORM_RESOURCE_LIMITS_MEMORY}" \
    --set-string helix.resources.requests.cpu="${PLATFORM_RESOURCE_REQUESTS_CPU}" \
    --set-string helix.resources.requests.memory="${PLATFORM_RESOURCE_REQUESTS_MEMORY}" \
    --timeout $TIME_OUT_SECOND \
    --wait 2>&1 | tee -a "${INSTALL_LOG_PATH}" || {
    error "Fail to install ${RELEASE}."
  }

  #TODO: check more resources after install
}

verify_supported() {
  installed helm || error "helm is required"
  installed kubectl || error "kubectl is required"
  installed yq || error "yq is required"

  [[ -n "${PLATFORM_NODE_NAMES}" ]] || error "PLATFORM_NODE_NAMES MUST set in environment variable."
  local node
  local node_array
  IFS="," read -r -a node_array <<<"${PLATFORM_NODE_NAMES}"
  PLATFORM_NODE_COUNT=0
  for node in "${node_array[@]}"; do
    kubectl label node "${node}" 'upm.platform.node=enable' --overwrite &>/dev/null || {
      error "kubectl label node ${node} 'upm.platform.node=enable' failed, use kubectl to check reason"
    }
    ((PLATFORM_NODE_COUNT++))
  done

  [[ -n "${PLATFORM_MYSQL_HOST}" ]] || error "PLATFORM_MYSQL_HOST MUST set in environment variable."
  [[ -n "${PLATFORM_MYSQL_PORT}" ]] || error "PLATFORM_MYSQL_PORT MUST set in environment variable."
  [[ -n "${PLATFORM_MYSQL_USER}" ]] || error "PLATFORM_MYSQL_USER MUST set in environment variable."
  [[ -n "${PLATFORM_MYSQL_PWD}" ]] || error "PLATFORM_MYSQL_PWD MUST set in environment variable."
  [[ -n "${PLATFORM_NACOS_HOST}" ]] || error "PLATFORM_NACOS_HOST MUST set in environment variable."
  [[ -n "${PLATFORM_NACOS_PORT}" ]] || error "PLATFORM_NACOS_PORT MUST set in environment variable."
  [[ -n "${PLATFORM_NACOS_USER}" ]] || error "PLATFORM_NACOS_USER MUST set in environment variable."
  [[ -n "${PLATFORM_NACOS_PWD}" ]] || error "PLATFORM_NACOS_PWD MUST set in environment variable."
  [[ -n "${PLATFORM_REDIS_HOST}" ]] || error "PLATFORM_REDIS_HOST MUST set in environment variable."
  [[ -n "${PLATFORM_REDIS_PORT}" ]] || error "PLATFORM_REDIS_PORT MUST set in environment variable."
  [[ -n "${PLATFORM_REDIS_PWD}" ]] || error "PLATFORM_REDIS_PWD MUST set in environment variable."
}

init_log() {
  touch "${INSTALL_LOG_PATH}" || error "Create log file ${INSTALL_LOG_PATH} error"
  info "Log file create in path ${INSTALL_LOG_PATH}"
}

verify_installed() {
  local status
  status=$(helm status "${RELEASE}" -n "${PLATFORM_KUBE_NAMESPACE}" -o yaml | yq -r '.info.status')
  [[ "${status}" == "deployed" ]] || {
    error "Helm release ${RELEASE} status is not deployed, use helm to check reason"
  }

  info "${RELEASE} Deployment Completed!"
}

main() {
  init_log
  verify_supported
  if [[ ${OFFLINE_INSTALL} == "false" ]]; then
    online_install_upm_platform
  elif [[ ${OFFLINE_INSTALL} == "true" ]]; then
    offline_install_upm_platform
  fi
  verify_installed
}

main
