#!/usr/bin/env bash

# You must be prepared as follows before run install.sh:
#
# 1. CROSSPLANE_NODE_NAMES MUST be set as environment variable, for an example:
#
#        export CROSSPLANE_NODE_NAMES="master01,master02"
#

readonly CHART="crossplane-stable/crossplane"
readonly RELEASE="crossplane"
readonly TIME_OUT_SECOND="600s"
readonly CHART_VERSION="1.14.0"

OFFLINE_INSTALL="${OFFLINE_INSTALL:-false}"
CROSSPLANE_PROVIDER_SQL_CREATE="${CROSSPLANE_PROVIDER_SQL_CREATE:-false}"
CROSSPLANE_KUBE_NAMESPACE="${CROSSPLANE_KUBE_NAMESPACE:-crossplane-system}"
CROSSPLANE_RESOURCE_LIMITS="${CROSSPLANE_RESOURCE_LIMITS:-1}"
INSTALL_LOG_PATH=/tmp/crossplane_install-$(date +'%Y-%m-%d_%H-%M-%S').log

if [[ ${CROSSPLANE_RESOURCE_LIMITS} -eq 0 ]]; then
  CROSSPLANE_RESOURCE_LIMITS_CPU="0"
  CROSSPLANE_RESOURCE_LIMITS_MEMORY="0"
  CROSSPLANE_RESOURCE_REQUESTS_CPU="0"
  CROSSPLANE_RESOURCE_REQUESTS_MEMORY="0"
elif [[ ${CROSSPLANE_RESOURCE_LIMITS} -gt 0 && ${CROSSPLANE_RESOURCE_LIMITS} -le 4 ]]; then
  CROSSPLANE_RESOURCE_LIMITS_CPU="1000m"
  CROSSPLANE_RESOURCE_LIMITS_MEMORY="${CROSSPLANE_RESOURCE_LIMITS}Gi"
  CROSSPLANE_RESOURCE_REQUESTS_CPU="1000m"
  CROSSPLANE_RESOURCE_REQUESTS_MEMORY="${CROSSPLANE_RESOURCE_LIMITS}Gi"
elif [[ ${CROSSPLANE_RESOURCE_LIMITS} -gt 4 ]]; then
  CROSSPLANE_RESOURCE_LIMITS_CPU="2000m"
  CROSSPLANE_RESOURCE_LIMITS_MEMORY="${CROSSPLANE_RESOURCE_LIMITS}Gi"
  CROSSPLANE_RESOURCE_REQUESTS_CPU="2000m"
  CROSSPLANE_RESOURCE_REQUESTS_MEMORY="${CROSSPLANE_RESOURCE_LIMITS}Gi"
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

online_install_crossplane() {
  info "Install crossplane..."
  # check if crossplane already installed
  if helm status "${RELEASE}" -n "${CROSSPLANE_KUBE_NAMESPACE}" &>/dev/null; then
    error "${RELEASE} already installed. Use helm remove it first"
  fi

  info "Start init helm crossplane repo"
  helm repo add crossplane-stable https://charts.crossplane.io/stable &>/dev/null || {
    error "Helm repo add crossplane error."
  }
  info "Start update helm crossplane repo"
  if ! helm repo update crossplane-stable 2>/dev/null; then
    error "Helm update crossplane repo error."
  fi

  info "Install ${RELEASE}, It might take a long time..."
  helm install "${RELEASE}" "${CHART}" \
    --version "${CHART_VERSION}" \
    --namespace "${CROSSPLANE_KUBE_NAMESPACE}" \
    --create-namespace \
    --set image.repository="crossplane/crossplane" \
    --set replicas="${CROSSPLANE_NODE_COUNT}" \
    --set nodeSelector."crossplane\.io/control-plane"="enable" \
    --set rbacManager.replicas="${CROSSPLANE_NODE_COUNT}" \
    --set rbacManager.nodeSelector."crossplane\.io/control-plane"="enable" \
    --set resourcesCrossplane.limits.cpu="${CROSSPLANE_RESOURCE_LIMITS_CPU}" \
    --set resourcesCrossplane.limits.memory="${CROSSPLANE_RESOURCE_LIMITS_MEMORY}" \
    --set resourcesCrossplane.requests.cpu="${CROSSPLANE_RESOURCE_REQUESTS_CPU}" \
    --set resourcesCrossplane.requests.memory="${CROSSPLANE_RESOURCE_REQUESTS_MEMORY}" \
    --set resourcesRBACManager.limits.cpu="${CROSSPLANE_RESOURCE_LIMITS_CPU}" \
    --set resourcesRBACManager.limits.memory="${CROSSPLANE_RESOURCE_LIMITS_MEMORY}" \
    --set resourcesRBACManager.requests.cpu="${CROSSPLANE_RESOURCE_REQUESTS_CPU}" \
    --set resourcesRBACManager.requests.memory="${CROSSPLANE_RESOURCE_REQUESTS_MEMORY}" \
    --timeout $TIME_OUT_SECOND \
    --wait 2>&1 | tee -a "${INSTALL_LOG_PATH}" || {
    error "Fail to install ${RELEASE}."
  }

  #TODO: check more resources after install
}

offline_install_crossplane() {
  info "Install crossplane..."
  # check if crossplane already installed
  if helm status "${RELEASE}" -n "${CROSSPLANE_KUBE_NAMESPACE}" &>/dev/null; then
    error "${RELEASE} already installed. Use helm remove it first"
  fi

  [[ -d "${CROSSPLANE_CHART_DIR}" ]] || error "CROSSPLANE_CHART_DIR not exist."

  info "Install ${RELEASE}, It might take a long time..."
  helm install "${RELEASE}" "${CROSSPLANE_CHART_DIR}" \
    --namespace "${CROSSPLANE_KUBE_NAMESPACE}" \
    --create-namespace \
    --set image.repository="${MYSQL_IMAGE_REGISTRY}/crossplane/crossplane" \
    --set replicas="${CROSSPLANE_NODE_COUNT}" \
    --set nodeSelector."crossplane\.io/control-plane"="enable" \
    --set rbacManager.replicas="${CROSSPLANE_NODE_COUNT}" \
    --set rbacManager.nodeSelector."crossplane\.io/control-plane"="enable" \
    --set resourcesCrossplane.limits.cpu="${CROSSPLANE_RESOURCE_LIMITS_CPU}" \
    --set resourcesCrossplane.limits.memory="${CROSSPLANE_RESOURCE_LIMITS_MEMORY}" \
    --set resourcesCrossplane.requests.cpu="${CROSSPLANE_RESOURCE_REQUESTS_CPU}" \
    --set resourcesCrossplane.requests.memory="${CROSSPLANE_RESOURCE_REQUESTS_MEMORY}" \
    --set resourcesRBACManager.limits.cpu="${CROSSPLANE_RESOURCE_LIMITS_CPU}" \
    --set resourcesRBACManager.limits.memory="${CROSSPLANE_RESOURCE_LIMITS_MEMORY}" \
    --set resourcesRBACManager.requests.cpu="${CROSSPLANE_RESOURCE_REQUESTS_CPU}" \
    --set resourcesRBACManager.requests.memory="${CROSSPLANE_RESOURCE_REQUESTS_MEMORY}" \
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

  [[ -n "${CROSSPLANE_NODE_NAMES}" ]] || error "CROSSPLANE_NODE_NAMES MUST set in environment variable."
  local node
  local node_array
  IFS="," read -r -a node_array <<<"${CROSSPLANE_NODE_NAMES}"
  CROSSPLANE_NODE_COUNT=0
  for node in "${node_array[@]}"; do
    kubectl label node "${node}" 'crossplane.io/control-plane=enable' --overwrite &>/dev/null || {
      error "kubectl label node ${node} 'crossplane.io/control-plane=enable' failed, use kubectl to check reason"
    }
    ((CROSSPLANE_NODE_COUNT++))
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
  status=$(helm status "${RELEASE}" -n "${CROSSPLANE_KUBE_NAMESPACE}" -o yaml | yq -r '.info.status')
  [[ "${status}" == "deployed" ]] || error "Helm release ${RELEASE} status is not deployed, use helm to check reason"

  info "${RELEASE} Deployment Completed!"
}

create_provider_sql() {
  if [[ ${CROSSPLANE_PROVIDER_SQL_CREATE} == "false" ]]; then
    info "CROSSPLANE_PROVIDER_SQL_CREATE is false, skip create provider sql."
    return
  fi

  [[ -n ${CROSSPLANE_PROVIDER_SQL_VERSION} ]] || error "CROSSPLANE_PROVIDER_SQL_VERSION MUST set in environment variable."

  [[ -f ${CROSSPLANE_PROVIDER_SQL_YAML} ]] || {
    local download_url="https://raw.githubusercontent.com/upmio/upm-deploy/main/addons/crossplane/yaml/crossplane-provider-sql.yaml"
    curl -sSL "${download_url}" -o "${CROSSPLANE_PROVIDER_SQL_YAML}" || {
      error "curl get crossplane-provider-sql.yaml failed"
    }
  }

  CROSSPLANE_PROVIDER_SQL_VERSION="${CROSSPLANE_PROVIDER_SQL_VERSION}" \
    envsubst <"${CROSSPLANE_PROVIDER_SQL_YAML}" | kubectl apply -f - || {
    error "kubectl create provider-sql failed, check log use kubectl."
  }
  info "create provider-sql successful!"
}

main() {
  init_log
  verify_supported
  if [[ ${OFFLINE_INSTALL} == "false" ]]; then
    online_install_crossplane
  elif [[ ${OFFLINE_INSTALL} == "true" ]]; then
    offline_install_crossplane
  fi
  verify_installed
}

main
