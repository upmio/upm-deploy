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
# 3. REDIS_STORAGECLASS_NAME MUST be set as environment variable, for an example:
#
#        export REDIS_STORAGECLASS_NAME="openebs-lvmsc-hdd"
#
# 4. REDIS_PVC_SIZE_G MUST be set as environment variable, for an example:
#
#        export REDIS_PVC_SIZE_G="50"
#

readonly CHART="bitnami/redis"
readonly RELEASE="redis"
readonly TIME_OUT_SECOND="600s"
readonly REDIS_VERSION="6.2.13"

REDIS_PORT="${REDIS_PORT:-6379}"
NAMESPACE="${REDIS_NAMESPACE:-default}"
RESOURCE_LIMITS_CPU="${REDIS_RESOURCE_LIMITS_CPU:-1}"
RESOURCE_LIMITS_MEMORY="${REDIS_RESOURCE_LIMITS_MEMORY:-2Gi}"
RESOURCE_REQUESTS_CPU="${REDIS_RESOURCE_REQUESTS_CPU:-1}"
RESOURCE_REQUESTS_MEMORY="${REDIS_RESOURCE_REQUESTS_MEMORY:-2Gi}"
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
  if helm status "${RELEASE}" -n "${NAMESPACE}" &>/dev/null; then
    error "${RELEASE} already installed. Use helm remove it first"
  fi
  info "Install redis, It might take a long time..."
  helm install "${RELEASE}" "${CHART}" \
    --debug \
    --namespace "${NAMESPACE}" \
    --create-namespace \
    --set image.debug=true \
    --set image.tag=''${REDIS_VERSION}'' \
    --set architecture='standalone' \
    --set master.resources.limits.cpu=''${RESOURCE_LIMITS_CPU}'' \
    --set master.resources.limits.memory=''${RESOURCE_LIMITS_MEMORY}'' \
    --set master.resources.requests.cpu=''${RESOURCE_REQUESTS_CPU}'' \
    --set master.resources.requests.memory=''${RESOURCE_REQUESTS_MEMORY}'' \
    --set global.redis.password=''"${REDIS_PWD}"'' \
    --set master.count=1 \
    --set master.containerPorts.redis="${REDIS_PORT}" \
    --set master.service.ports.redis="${REDIS_PORT}" \
    --set master.persistence.storageClass="${REDIS_STORAGECLASS_NAME}" \
    --set master.persistence.size="${REDIS_PVC_SIZE_G}"Gi \
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

  if [[ -z "${REDIS_STORAGECLASS_NAME}" ]]; then
    error "REDIS_STORAGECLASS_NAME MUST set in environment variable."
  fi

  kubectl get storageclasses "${REDIS_STORAGECLASS_NAME}" &>/dev/null || {
    error "storageclass resources not all ready, use kubectl to check reason"
  }

  if [[ -z "${REDIS_PVC_SIZE_G}" ]]; then
    error "REDIS_PVC_SIZE_G MUST set in environment variable."
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
  helm status "${RELEASE}" -n "${NAMESPACE}" | grep deployed &>/dev/null || {
    error "${RELEASE} installed fail, check log use helm and kubectl."
  }

  info "${RELEASE} Deployment Completed!"
}

create_nodeport_service() {
  info "create nodeport service..."
  kubectl delete svc -n "${NAMESPACE}" redis
  export NAMESPACE REDIS_PORT REDIS_VERSION VERSION
  curl -sSL https://raw.githubusercontent.com/upmio/upm-deploy/main/addons/redis-standalone/yaml/master-nodeport-service.yaml | envsubst | kubectl apply -f - || {
    error "kubectl create nodeport service fail, check log use kubectl."
  }

  info "create nodeport service successful!"
}

main() {
  init_log
  verify_supported
  init_helm_repo
  install_redis
  verify_installed
  create_nodeport_service
}

main