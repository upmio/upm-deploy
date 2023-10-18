#!/usr/bin/env bash

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
readonly VERSION="18.1.5"

REDIS_SERVICE_TYPE="${REDIS_SERVICE_TYPE:-ClusterIP}"
REDIS_PORT="${REDIS_PORT:-6379}"
REDIS_KUBE_NAMESPACE="${REDIS_KUBE_NAMESPACE:-default}"
REDIS_RESOURCE_LIMITS_CPU="${REDIS_RESOURCE_LIMITS_CPU:-1000m}"
REDIS_RESOURCE_LIMITS_MEMORY="${REDIS_RESOURCE_LIMITS_MEMORY:-2Gi}"
REDIS_RESOURCE_REQUESTS_CPU="${REDIS_RESOURCE_REQUESTS_CPU:-1000m}"
REDIS_RESOURCE_REQUESTS_MEMORY="${REDIS_RESOURCE_REQUESTS_MEMORY:-2Gi}"
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

install_redis() {
  # check if redis already installed
  if helm status "${RELEASE}" -n "${REDIS_KUBE_NAMESPACE}" &>/dev/null; then
    error "${RELEASE} already installed. Use helm remove it first"
  fi
  info "Install redis, It might take a long time..."
  helm install "${RELEASE}" "${CHART}" \
    --debug \
    --version "${VERSION}" \
    --namespace "${REDIS_KUBE_NAMESPACE}" \
    --create-namespace \
    --set-string global.redis.password="${REDIS_PWD}" \
    --set image.debug=true \
    --set-string architecture="standalone" \
    --set-string master.resources.limits.cpu="${REDIS_RESOURCE_LIMITS_CPU}" \
    --set-string master.resources.limits.memory="${REDIS_RESOURCE_LIMITS_MEMORY}" \
    --set-string master.resources.requests.cpu="${REDIS_RESOURCE_REQUESTS_CPU}" \
    --set-string master.resources.requests.memory="${REDIS_RESOURCE_REQUESTS_MEMORY}" \
    --set master.count=1 \
    --set master.containerPorts.redis="${REDIS_PORT}" \
    --set master.service.type="${REDIS_SERVICE_TYPE}" \
    --set master.service.ports.redis="${REDIS_PORT}" \
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

init_helm_repo() {
  info "Start add helm bitnami repo"
  helm repo add bitnami https://charts.bitnami.com/bitnami &>/dev/null || {
    error "Helm add bitnami repo error."
  }

  info "Start update helm bitnami repo"
  helm repo update bitnami 2>/dev/null || {
    error "Helm update bitnami repo error."
  }
}

verify_supported() {
  local HAS_HELM
  HAS_HELM="$(type "helm" &>/dev/null && echo true || echo false)"
  local HAS_KUBECTL
  HAS_KUBECTL="$(type "kubectl" &>/dev/null && echo true || echo false)"
  local HAS_CURL
  HAS_CURL="$(type "curl" &>/dev/null && echo true || echo false)"

  if [[ -z "${REDIS_PWD}" ]]; then
    error "REDIS_PWD MUST set in environment variable."
  fi

  if [[ -z "${REDIS_NODE_NAMES}" ]]; then
    error "REDIS_NODE_NAMES MUST set in environment variable."
  fi

  local node
  local redis_node_array
  IFS="," read -r -a redis_node_array <<<"${REDIS_NODE_NAMES}"
  for node in "${redis_node_array[@]}"; do
    kubectl label node "${node}" 'redis.standalone.node=enable' --overwrite &>/dev/null || {
      error "kubectl label node ${node} 'redis.standalone.node=enable' failed, use kubectl to check reason"
    }
  done

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
  INSTALL_LOG_PATH=/tmp/redis_install-$(date +'%Y-%m-%d_%H-%M-%S').log
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
  helm status "${RELEASE}" -n "${REDIS_KUBE_NAMESPACE}" | grep deployed &>/dev/null || {
    error "${RELEASE} installed fail, check log use helm and kubectl."
  }

  info "${RELEASE} Deployment Completed!"
}

main() {
  init_log
  verify_supported
  init_helm_repo
  install_redis
  verify_installed
}

main