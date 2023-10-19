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
# 9. PLATFORM_REDIS_HOST MUST be set as environment variable, for an example:
#
#        export PLATFORM_REDIS_HOST="redis-master"
#
# 9. PLATFORM_REDIS_PORT MUST be set as environment variable, for an example:
#
#        export PLATFORM_REDIS_PORT="6379"
#
# 9. PLATFORM_REDIS_PWD MUST be set as environment variable, for an example:
#
#        export PLATFORM_REDIS_PWD="password"
#

readonly CHART="upm-charts/upm-platform"
readonly RELEASE="upm-platform"
readonly TIME_OUT_SECOND="600s"
readonly VERSION="1.1.0"
readonly UI_VERSION="dev-d11e94e3"
readonly API_VERSION="dev-c62a23df"

PLATFORM_KUBE_NAMESPACE="${PLATFORM_KUBE_NAMESPACE:-upm-manager}"
PLATFORM_SERVICE_TYPE="${PLATFORM_SERVICE_TYPE:-ClusterIP}"
PLATFORM_RESOURCE_LIMITS_CPU="${REDIS_RESOURCE_LIMITS_CPU:-1000m}"
PLATFORM_RESOURCE_LIMITS_MEMORY="${REDIS_RESOURCE_LIMITS_MEMORY:-2Gi}"
PLATFORM_RESOURCE_REQUESTS_CPU="${REDIS_RESOURCE_REQUESTS_CPU:-1000m}"
PLATFORM_RESOURCE_REQUESTS_MEMORY="${REDIS_RESOURCE_REQUESTS_MEMORY:-2Gi}"
INSTALL_LOG_PATH=""

info() {
  echo "[Info][$(date +'%Y-%m-%dT%H:%M:%S%z')]: $*" | tee -a "${INSTALL_LOG_PATH}"
}

error() {
  echo "[Error][$(date +'%Y-%m-%dT%H:%M:%S%z')]: $*" | tee -a "${INSTALL_LOG_PATH}"
  exit 1
}

install_kubectl() {
  info "Install kubectl..."
  if ! curl -LOs "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"; then
    error "Fail to get kubectl, please confirm whether the connection to dl.k8s.io is ok?"
  fi
  if ! sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl; then
    error "Install kubectl fail"
  fi
  info "Kubectl install completed"
}

install_helm() {
  info "Install helm..."
  if ! curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3; then
    error "Fail to get helm installed script, please confirm whether the connection to raw.githubusercontent.com is ok?"
  fi
  chmod 700 get_helm.sh
  if ! ./get_helm.sh; then
    error "Fail to get helm when running get_helm.sh"
  fi
  info "Helm install completed"
}

install_cert_managers() {
  # check if cert-manager already installed
  if helm status ${RELEASE} -n "${PLATFORM_KUBE_NAMESPACE}" &>/dev/null; then
    error "${RELEASE} already installed. Use helm remove it first"
  fi
  info "Install cert-manager, It might take a long time..."
  helm install ${RELEASE} ${CHART} \
    --debug \
    --version "${VERSION}" \
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
    --set-string service.type="${PLATFORM_SERVICE_TYPE}" \
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
    --set-string operatelog.nodeAffinityPreset.type="hard" \
    --set-string operatelog.nodeAffinityPreset.key="upm\.platform\.node" \
    --set-string operatelog.nodeAffinityPreset.values='{enable}' \
    --set-string operatelog.resources.limits.cpu="${PLATFORM_RESOURCE_LIMITS_CPU}" \
    --set-string operatelog.resources.limits.memory="${PLATFORM_RESOURCE_LIMITS_MEMORY}" \
    --set-string operatelog.resources.requests.cpu="${PLATFORM_RESOURCE_REQUESTS_CPU}" \
    --set-string operatelog.resources.requests.memory="${PLATFORM_RESOURCE_REQUESTS_MEMORY}" \
    --set-string resource.image.tag="${API_VERSION}" \
    --set resource.replicaCount="${PLATFORM_NODE_COUNT}" \
    --set-string resource.nodeAffinityPreset.type="hard" \
    --set-string resource.nodeAffinityPreset.key="upm\.platform\.node" \
    --set-string resource.nodeAffinityPreset.values='{enable}' \
    --set-string resource.resources.limits.cpu="${PLATFORM_RESOURCE_LIMITS_CPU}" \
    --set-string resource.resources.limits.memory="${PLATFORM_RESOURCE_LIMITS_MEMORY}" \
    --set-string resource.resources.requests.cpu="${PLATFORM_RESOURCE_REQUESTS_CPU}" \
    --set-string resource.resources.requests.memory="${PLATFORM_RESOURCE_REQUESTS_MEMORY}" \
    --set-string service-easysearch.image.tag="${API_VERSION}" \
    --set service-easysearch.replicaCount="${PLATFORM_NODE_COUNT}" \
    --set-string service-easysearch.nodeAffinityPreset.type="hard" \
    --set-string service-easysearch.nodeAffinityPreset.key="upm\.platform\.node" \
    --set-string service-easysearch.nodeAffinityPreset.values='{enable}' \
    --set-string service-easysearch.resources.limits.cpu="${PLATFORM_RESOURCE_LIMITS_CPU}" \
    --set-string service-easysearch.resources.limits.memory="${PLATFORM_RESOURCE_LIMITS_MEMORY}" \
    --set-string service-easysearch.resources.requests.cpu="${PLATFORM_RESOURCE_REQUESTS_CPU}" \
    --set-string service-easysearch.resources.requests.memory="${PLATFORM_RESOURCE_REQUESTS_MEMORY}" \
    --set-string service-kafka.image.tag="${API_VERSION}" \
    --set service-kafka.replicaCount="${PLATFORM_NODE_COUNT}" \
    --set-string service-kafka.nodeAffinityPreset.type="hard" \
    --set-string service-kafka.nodeAffinityPreset.key="upm\.platform\.node" \
    --set-string service-kafka.nodeAffinityPreset.values='{enable}' \
    --set-string service-kafka.resources.limits.cpu="${PLATFORM_RESOURCE_LIMITS_CPU}" \
    --set-string service-kafka.resources.limits.memory="${PLATFORM_RESOURCE_LIMITS_MEMORY}" \
    --set-string service-kafka.resources.requests.cpu="${PLATFORM_RESOURCE_REQUESTS_CPU}" \
    --set-string service-kafka.resources.requests.memory="${PLATFORM_RESOURCE_REQUESTS_MEMORY}" \
    --set-string service-mysql.image.tag="${API_VERSION}" \
    --set service-mysql.replicaCount="${PLATFORM_NODE_COUNT}" \
    --set-string service-mysql.nodeAffinityPreset.type="hard" \
    --set-string service-mysql.nodeAffinityPreset.key="upm\.platform\.node" \
    --set-string service-mysql.nodeAffinityPreset.values='{enable}' \
    --set-string service-mysql.resources.limits.cpu="${PLATFORM_RESOURCE_LIMITS_CPU}" \
    --set-string service-mysql.resources.limits.memory="${PLATFORM_RESOURCE_LIMITS_MEMORY}" \
    --set-string service-mysql.resources.requests.cpu="${PLATFORM_RESOURCE_REQUESTS_CPU}" \
    --set-string service-mysql.resources.requests.memory="${PLATFORM_RESOURCE_REQUESTS_MEMORY}" \
    --set-string user.image.tag="${API_VERSION}" \
    --set user.replicaCount="${PLATFORM_NODE_COUNT}" \
    --set-string user.nodeAffinityPreset.type="hard" \
    --set-string user.nodeAffinityPreset.key="upm\.platform\.node" \
    --set-string user.nodeAffinityPreset.values='{enable}' \
    --set-string user.resources.limits.cpu="${PLATFORM_RESOURCE_LIMITS_CPU}" \
    --set-string user.resources.limits.memory="${PLATFORM_RESOURCE_LIMITS_MEMORY}" \
    --set-string user.resources.requests.cpu="${PLATFORM_RESOURCE_REQUESTS_CPU}" \
    --set-string user.resources.requests.memory="${PLATFORM_RESOURCE_REQUESTS_MEMORY}" \
    --timeout $TIME_OUT_SECOND \
    --wait 2>&1 | grep "\[debug\]" | awk '{$1="[Helm]"; $2=""; print }' | tee -a "${INSTALL_LOG_PATH}" || {
    error "Fail to install ${RELEASE}."
  }

  #TODO: check more resources after install
}

init_helm_repo() {
  info "Start add helm bitnami repo"
  helm repo add upm-charts https://upmio.github.io/helm-charts &>/dev/null || {
    error "Helm add upm-charts repo error."
  }

  info "Start update helm upm-charts repo"
  helm repo update upm-charts 2>/dev/null || {
    error "Helm update upm-charts repo error."
  }
}

verify_supported() {
  local HAS_HELM
  HAS_HELM="$(type "helm" &>/dev/null && echo true || echo false)"
  local HAS_KUBECTL
  HAS_KUBECTL="$(type "kubectl" &>/dev/null && echo true || echo false)"
  local HAS_CURL
  HAS_CURL="$(type "curl" &>/dev/null && echo true || echo false)"

  if [[ -z "${PLATFORM_NODE_NAMES}" ]]; then
    error "PLATFORM_NODE_NAMES MUST set in environment variable."
  fi

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

  if [[ -z "${PLATFORM_MYSQL_HOST}" ]]; then
    error "PLATFORM_MYSQL_HOST MUST set in environment variable."
  fi

  if [[ -z "${PLATFORM_MYSQL_PORT}" ]]; then
    error "PLATFORM_MYSQL_PORT MUST set in environment variable."
  fi

  if [[ -z "${PLATFORM_MYSQL_USER}" ]]; then
    error "PLATFORM_MYSQL_USER MUST set in environment variable."
  fi

  if [[ -z "${PLATFORM_MYSQL_PWD}" ]]; then
    error "PLATFORM_MYSQL_USER MUST set in environment variable."
  fi

  if [[ -z "${PLATFORM_REDIS_HOST}" ]]; then
    error "PLATFORM_REDIS_HOST MUST set in environment variable."
  fi

  if [[ -z "${PLATFORM_REDIS_PORT}" ]]; then
    error "PLATFORM_REDIS_PORT MUST set in environment variable."
  fi

  if [[ -z "${PLATFORM_REDIS_PWD}" ]]; then
    error "PLATFORM_REDIS_USER MUST set in environment variable."
  fi

  if [[ -z "${PLATFORM_NACOS_HOST}" ]]; then
    error "PLATFORM_NACOS_HOST MUST set in environment variable."
  fi

  if [[ -z "${PLATFORM_NACOS_PORT}" ]]; then
    error "PLATFORM_NACOS_PORT MUST set in environment variable."
  fi

  if [[ -z "${PLATFORM_NACOS_USER}" ]]; then
    error "PLATFORM_NACOS_USER MUST set in environment variable."
  fi

  if [[ -z "${PLATFORM_NACOS_PWD}" ]]; then
    error "PLATFORM_NACOS_USER MUST set in environment variable."
  fi

  if [[ "${HAS_CURL}" != "true" ]]; then
    error "curl is required"
  fi

  if [[ "${HAS_HELM}" != "true" ]]; then
    install_helm
  fi

  if [[ "${HAS_KUBECTL}" != "true" ]]; then
    install_kubectl
  fi
}

init_log() {
  INSTALL_LOG_PATH=/tmp/upm_platform_install-$(date +'%Y-%m-%d_%H-%M-%S').log
  if ! touch "${INSTALL_LOG_PATH}"; then
    error "Create log file ${INSTALL_LOG_PATH} error"
  fi
  info "Log file create in path ${INSTALL_LOG_PATH}"
}

############################################
# Check if helm release deployment correctly
# Arguments:
#   release
#   namespace
############################################
verify_installed() {
  helm status "${RELEASE}" -n "${PLATFORM_KUBE_NAMESPACE}" | grep deployed &>/dev/null || {
    error "${RELEASE} installed fail, check log use helm and kubectl."
  }

  info "${RELEASE} Deployment Completed!"
}

main() {
  init_log
  verify_supported
  init_helm_repo
  install_upm_platform
  verify_installed
}

main
