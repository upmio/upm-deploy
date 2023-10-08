#!/usr/bin/env bash

# You must be prepared as follows before run install.sh:
#
# 1. NACOS_CONTROLLER_NODE_NAMES MUST be set as environment variable, for an example:
#
#        export NACOS_CONTROLLER_NODE_NAMES="master01,master02"
#
# 2. NACOS_STORAGECLASS_NAME MUST be set as environment variable, for an example:
#
#        export NACOS_STORAGECLASS_NAME="openebs-lvmsc-hdd"
#
# 3. NACOS_MYSQL_NODE_NAME MUST be set as environment variable, for an example:
#
#        export NACOS_MYSQL_NODE_NAME="node01"
#

readonly CHART="ygqygq2/nacos"
readonly RELEASE="nacos"
readonly TIME_OUT_SECOND="600s"
readonly NACOS_RESOURCE_LIMITS_CPU="1"
readonly NACOS_RESOURCE_LIMITS_MEMORY="2Gi"
readonly NACOS_RESOURCE_REQUESTS_CPU="1"
readonly NACOS_RESOURCE_REQUESTS_MEMORY="2Gi"
readonly NACOS_MYSQL_RESOURCE_LIMITS_CPU="1"
readonly NACOS_MYSQL_RESOURCE_LIMITS_MEMORY="2Gi"
readonly NACOS_MYSQL_RESOURCE_REQUESTS_CPU="1"
readonly NACOS_MYSQL_RESOURCE_REQUESTS_MEMORY="2Gi"
readonly VERSION="2.1.4"

NACOS_PVC_SIZE_G="${NACOS_PVC_SIZE_G:-5}"
NACOS_PORT="${NACOS_PORT:-8848}"
NACOS_CLIENT_PORT="$(("${NACOS_PORT}" + 1000 ))"
NACOS_RAFT_PORT="$(("${NACOS_PORT}" + 1001 ))"
NACOS_MYSQL_PVC_SIZE_G="${NACOS_MYSQL_PVC_SIZE_G:-10}"
NACOS_MYSQL_PWD="${NACOS_MYSQL_PWD:-nacos}"

NAMESPACE="${NACOS_NAMESPACE:-nacos}"
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

install_nacos() {
  # check if nacos already installed
  if helm status ${RELEASE} -n "${NAMESPACE}" &>/dev/null; then
    error "${RELEASE} already installed. Use helm remove it first"
  fi
  info "Install nacos, It might take a long time..."
  helm install ${RELEASE} ${CHART} \
    --debug \
    --version "${VERSION}" \
    --namespace "${NAMESPACE}" \
    --create-namespace \
    --set nodeAffinityPreset.type="hard" \
    --set nodeAffinityPreset.key="nacos\.io/control-plane" \
    --set nodeAffinityPreset.values='{enable}' \
    --set replicaCount=${NACOS_CONTROLLER_NODE_COUNT} \
    --set service.ports.http.port=''"${NACOS_PORT}"'' \
    --set service.ports."client-rpc".port=''"${NACOS_CLIENT_PORT}"'' \
    --set service.ports."raft-rpc".port=''"${NACOS_RAFT_PORT}"'' \
    --set resources.limits.cpu=''${NACOS_RESOURCE_LIMITS_CPU}'' \
    --set resources.limits.memory=''${NACOS_RESOURCE_LIMITS_MEMORY}'' \
    --set resources.requests.cpu=''${NACOS_RESOURCE_REQUESTS_CPU}'' \
    --set resources.requests.memory=''${NACOS_RESOURCE_REQUESTS_MEMORY}'' \
    --set persistence.enabled=false \
    --set persistence.storageClass=''"${NACOS_STORAGECLASS_NAME}"'' \
    --set persistence.size=''"${NACOS_PVC_SIZE_G}Gi"'' \
    --set ingress.enabled=false \
    --set mysql.architecture="standalone" \
    --set mysql.auth.rootPassword=''"${NACOS_MYSQL_PWD}"'' \
    --set mysql.auth.password=''"${NACOS_MYSQL_PWD}"'' \
    --set primary.resources.limits.cpu=''${NACOS_MYSQL_RESOURCE_LIMITS_CPU}'' \
    --set primary.resources.limits.memory=''${NACOS_MYSQL_RESOURCE_LIMITS_MEMORY}'' \
    --set primary.resources.requests.cpu=''${NACOS_MYSQL_RESOURCE_REQUESTS_CPU}'' \
    --set primary.resources.requests.memory=''${NACOS_MYSQL_RESOURCE_REQUESTS_MEMORY}'' \
    --set primary.persistence.enabled=true \
    --set primary.persistence.storageClass=''"${NACOS_STORAGECLASS_NAME}"'' \
    --set primary.persistence.size=''"${NACOS_MYSQL_PVC_SIZE_G}Gi"'' \
    --set primary.nodeAffinityPreset.type="hard" \
    --set primary.nodeAffinityPreset.key="nacos\.io/mysql" \
    --set primary.nodeAffinityPreset.values='{enable}' \
    --timeout $TIME_OUT_SECOND \
    --wait 2>&1 | grep "\[debug\]" | awk '{$1="[Helm]"; $2=""; print }' | tee -a "${INSTALL_LOG_PATH}" || {
    error "Fail to install ${RELEASE}."
  }

  #TODO: check more resources after install
}

init_helm_repo() {
  helm repo add ygqygq2 https://ygqygq2.github.io/charts/ &>/dev/null
  info "Start update helm nacos repo"
  if ! helm repo update ygqygq2 2>/dev/null; then
    error "Helm update nacos repo error."
  fi
}

verify_supported() {
  local HAS_HELM
  HAS_HELM="$(type "helm" &>/dev/null && echo true || echo false)"
  local HAS_KUBECTL
  HAS_KUBECTL="$(type "kubectl" &>/dev/null && echo true || echo false)"
  local HAS_CURL
  HAS_CURL="$(type "curl" &>/dev/null && echo true || echo false)"

  if [[ -z "${NACOS_STORAGECLASS_NAME}" ]]; then
    error "NACOS_STORAGECLASS_NAME MUST set in environment variable."
  fi

  if [[ -z "${NACOS_MYSQL_PVC_SIZE_G}" ]]; then
    error "NACOS_MYSQL_PVC_SIZE_G MUST set in environment variable."
  fi

  if [[ -z "${NACOS_CONTROLLER_NODE_NAMES}" ]]; then
    error "NACOS_CONTROLLER_NODE_NAMES MUST set in environment variable."
  fi

  local node
  local control_node_array
  IFS="," read -r -a control_node_array <<<"${NACOS_CONTROLLER_NODE_NAMES}"
  NACOS_CONTROLLER_NODE_COUNT=0
  for node in "${control_node_array[@]}"; do
    kubectl label node "${node}" 'nacos.io/control-plane=enable' --overwrite &>/dev/null || {
      error "kubectl label node ${node} 'nacos.io/control-plane=enable' failed, use kubectl to check reason"
    }
    ((NACOS_CONTROLLER_NODE_COUNT++))
  done

  if [[ -z "${NACOS_MYSQL_NODE_NAME}" ]]; then
    error "NACOS_MYSQL_NODE_NAME MUST set in environment variable."
  fi

  kubectl label node "${NACOS_MYSQL_NODE_NAME}" 'nacos.io/mysql=enable' --overwrite &>/dev/null || {
    error "kubectl label node ${NACOS_MYSQL_NODE_NAME} 'nacos.io/mysql=enable' failed, use kubectl to check reason"
  }

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
  INSTALL_LOG_PATH=/tmp/nacos_install-$(date +'%Y-%m-%d_%H-%M-%S').log
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

main() {
  init_log
  verify_supported
  init_helm_repo
  install_nacos
  verify_installed
}

main
