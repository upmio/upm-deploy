#!/usr/bin/env bash

# You must be prepared as follows before run install.sh:
#
# 1. ENGINE_NODE_NAMES MUST be set as environment variable, for an example:
#
#        export ENGINE_NODE_NAMES="master01,master02"
#

readonly CHART="upm-charts/upm-engine"
readonly RELEASE="upm-engine"
readonly TIME_OUT_SECOND="600s"
readonly CHART_VERSION="1.1.0"
readonly TESSERACT_VERSION="dev-ce4f7db5"
readonly TESSERACT_AGENT_VERSION="dev-93796329"
readonly SCEPTER_VERSION="dev-8e75ea5a"
readonly GAUNTLET_VERSION="dev-25c22709"
readonly TEMPLATE_VERSION="dev-d97237bb"

ENGINE_KUBE_NAMESPACE="${ENGINE_KUBE_NAMESPACE:-upm-system}"
INSTALL_LOG_PATH=/tmp/upm_engine_install-$(date +'%Y-%m-%d_%H-%M-%S').log

if [[ ${ENGINE_RESOURCE_LIMITS} -eq 0 ]]; then
  ENGINE_RESOURCE_LIMITS_CPU="0"
  ENGINE_RESOURCE_LIMITS_MEMORY="0"
  ENGINE_RESOURCE_REQUESTS_CPU="0"
  ENGINE_RESOURCE_REQUESTS_MEMORY="0"
elif [[ ${ENGINE_RESOURCE_LIMITS} -gt 0 && ${ENGINE_RESOURCE_LIMITS} -le 4 ]]; then
  ENGINE_RESOURCE_LIMITS_CPU="1000m"
  ENGINE_RESOURCE_LIMITS_MEMORY="${ENGINE_RESOURCE_LIMITS}Gi"
  ENGINE_RESOURCE_REQUESTS_CPU="1000m"
  ENGINE_RESOURCE_REQUESTS_MEMORY="${ENGINE_RESOURCE_LIMITS}Gi"
elif [[ ${ENGINE_RESOURCE_LIMITS} -gt 4 ]]; then
  ENGINE_RESOURCE_LIMITS_CPU="2000m"
  ENGINE_RESOURCE_LIMITS_MEMORY="${ENGINE_RESOURCE_LIMITS}Gi"
  ENGINE_RESOURCE_REQUESTS_CPU="2000m"
  ENGINE_RESOURCE_REQUESTS_MEMORY="${ENGINE_RESOURCE_LIMITS}Gi"
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

online_install_upm_engine() {
  # check if upm-engine already installed
  if helm status ${RELEASE} -n "${ENGINE_KUBE_NAMESPACE}" &>/dev/null; then
    error "${RELEASE} already installed. Use helm remove it first"
  fi

  info "Start add helm upm-charts repo"
  helm repo add upm-charts https://upmio.github.io/helm-charts &>/dev/null || error "Helm add upm-charts repo error."
  info "Start update helm upm-charts repo"
  helm repo update upm-charts 2>/dev/null || error "Helm update upm-charts repo error."

  info "Install upm-engine, It might take a long time..."
  helm install ${RELEASE} ${CHART} \
    --version "${CHART_VERSION}" \
    --namespace "${ENGINE_KUBE_NAMESPACE}" \
    --create-namespace \
    --set tesseract.crds.enabled=true \
    --set-string configmaps.image.tag="${TEMPLATE_VERSION}" \
    --set-string tesseract.image.tag="${TESSERACT_VERSION}" \
    --set-string tesseract.agent.image.tag="${TESSERACT_AGENT_VERSION}" \
    --set tesseract.replicaCount="${ENGINE_NODE_COUNT}" \
    --set-string tesseract.nodeAffinityPreset.type="hard" \
    --set-string tesseract.nodeAffinityPreset.key="upm\.engine\.node" \
    --set-string tesseract.nodeAffinityPreset.values='{enable}' \
    --set-string tesseract.resources.limits.cpu="${ENGINE_RESOURCE_LIMITS_CPU}" \
    --set-string tesseract.resources.limits.memory="${ENGINE_RESOURCE_LIMITS_MEMORY}" \
    --set-string tesseract.resources.requests.cpu="${ENGINE_RESOURCE_REQUESTS_CPU}" \
    --set-string tesseract.resources.requests.memory="${ENGINE_RESOURCE_REQUESTS_MEMORY}" \
    --set scepter.crds.enabled=true \
    --set-string scepter.image.tag="${SCEPTER_VERSION}" \
    --set scepter.replicaCount="${ENGINE_NODE_COUNT}" \
    --set-string scepter.nodeAffinityPreset.type="hard" \
    --set-string scepter.nodeAffinityPreset.key="upm\.engine\.node" \
    --set-string scepter.nodeAffinityPreset.values='{enable}' \
    --set-string scepter.resources.limits.cpu="${ENGINE_RESOURCE_LIMITS_CPU}" \
    --set-string scepter.resources.limits.memory="${ENGINE_RESOURCE_LIMITS_MEMORY}" \
    --set-string scepter.resources.requests.cpu="${ENGINE_RESOURCE_REQUESTS_CPU}" \
    --set-string scepter.resources.requests.memory="${ENGINE_RESOURCE_REQUESTS_MEMORY}" \
    --set gauntlet.crds.enabled=true \
    --set-string gauntlet.image.tag="${GAUNTLET_VERSION}" \
    --set gauntlet.replicaCount="${ENGINE_NODE_COUNT}" \
    --set-string gauntlet.nodeAffinityPreset.type="hard" \
    --set-string gauntlet.nodeAffinityPreset.key="upm\.engine\.node" \
    --set-string gauntlet.nodeAffinityPreset.values='{enable}' \
    --set-string gauntlet.resources.limits.cpu="${ENGINE_RESOURCE_LIMITS_CPU}" \
    --set-string gauntlet.resources.limits.memory="${ENGINE_RESOURCE_LIMITS_MEMORY}" \
    --set-string gauntlet.resources.requests.cpu="${ENGINE_RESOURCE_REQUESTS_CPU}" \
    --set-string gauntlet.resources.requests.memory="${ENGINE_RESOURCE_REQUESTS_MEMORY}" \
    --timeout $TIME_OUT_SECOND \
    --wait 2>&1 | tee -a "${INSTALL_LOG_PATH}" || {
    error "Fail to install ${RELEASE}."
  }

  #TODO: check more resources after install
}

offline_install_upm_engine() {
  # check if upm-engine already installed
  if helm status ${RELEASE} -n "${ENGINE_KUBE_NAMESPACE}" &>/dev/null; then
    error "${RELEASE} already installed. Use helm remove it first"
  fi

  local image_registry="${IMAGE_REGISTRY:-}"
  [[ -d "${ENGINE_CHART_DIR}" ]] || error "ENGINE_CHART_DIR not exist."

  info "Install upm-engine, It might take a long time..."
  helm install ${RELEASE} "${ENGINE_CHART_DIR}" \
    --namespace "${ENGINE_KUBE_NAMESPACE}" \
    --create-namespace \
    --set-string global.imageRegistry="${image_registry}" \
    --set tesseract.crds.enabled=true \
    --set-string configmaps.image.tag="${TEMPLATE_VERSION}" \
    --set-string tesseract.image.tag="${TESSERACT_VERSION}" \
    --set-string tesseract.agent.image.tag="${TESSERACT_AGENT_VERSION}" \
    --set tesseract.replicaCount="${ENGINE_NODE_COUNT}" \
    --set-string tesseract.nodeAffinityPreset.type="hard" \
    --set-string tesseract.nodeAffinityPreset.key="upm\.engine\.node" \
    --set-string tesseract.nodeAffinityPreset.values='{enable}' \
    --set-string tesseract.resources.limits.cpu="${ENGINE_RESOURCE_LIMITS_CPU}" \
    --set-string tesseract.resources.limits.memory="${ENGINE_RESOURCE_LIMITS_MEMORY}" \
    --set-string tesseract.resources.requests.cpu="${ENGINE_RESOURCE_REQUESTS_CPU}" \
    --set-string tesseract.resources.requests.memory="${ENGINE_RESOURCE_REQUESTS_MEMORY}" \
    --set scepter.crds.enabled=true \
    --set-string scepter.image.tag="${SCEPTER_VERSION}" \
    --set scepter.replicaCount="${ENGINE_NODE_COUNT}" \
    --set-string scepter.nodeAffinityPreset.type="hard" \
    --set-string scepter.nodeAffinityPreset.key="upm\.engine\.node" \
    --set-string scepter.nodeAffinityPreset.values='{enable}' \
    --set-string scepter.resources.limits.cpu="${ENGINE_RESOURCE_LIMITS_CPU}" \
    --set-string scepter.resources.limits.memory="${ENGINE_RESOURCE_LIMITS_MEMORY}" \
    --set-string scepter.resources.requests.cpu="${ENGINE_RESOURCE_REQUESTS_CPU}" \
    --set-string scepter.resources.requests.memory="${ENGINE_RESOURCE_REQUESTS_MEMORY}" \
    --set gauntlet.crds.enabled=true \
    --set-string gauntlet.image.tag="${GAUNTLET_VERSION}" \
    --set gauntlet.replicaCount="${ENGINE_NODE_COUNT}" \
    --set-string gauntlet.nodeAffinityPreset.type="hard" \
    --set-string gauntlet.nodeAffinityPreset.key="upm\.engine\.node" \
    --set-string gauntlet.nodeAffinityPreset.values='{enable}' \
    --set-string gauntlet.resources.limits.cpu="${ENGINE_RESOURCE_LIMITS_CPU}" \
    --set-string gauntlet.resources.limits.memory="${ENGINE_RESOURCE_LIMITS_MEMORY}" \
    --set-string gauntlet.resources.requests.cpu="${ENGINE_RESOURCE_REQUESTS_CPU}" \
    --set-string gauntlet.resources.requests.memory="${ENGINE_RESOURCE_REQUESTS_MEMORY}" \
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

  [[ -n "${ENGINE_NODE_NAMES}" ]] || error "ENGINE_NODE_NAMES MUST set in environment variable."

  local node
  local node_array
  IFS="," read -r -a node_array <<<"${ENGINE_NODE_NAMES}"
  ENGINE_NODE_COUNT=0
  for node in "${node_array[@]}"; do
    kubectl label node "${node}" 'upm.engine.node=enable' --overwrite &>/dev/null || {
      error "kubectl label node ${node} 'upm.engine.node=enable' failed, use kubectl to check reason"
    }
    ((ENGINE_NODE_COUNT++))
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
  status=$(helm status "${RELEASE}" -n "${ENGINE_KUBE_NAMESPACE}" -o yaml | yq -r '.info.status')
  [[ "${status}" == "deployed" ]] || {
    error "Helm release ${RELEASE} status is not deployed, use helm to check reason"
  }

  info "${RELEASE} Deployment Completed!"
}

main() {
  init_log
  verify_supported
  if [[ ${OFFLINE_INSTALL} == "false" ]]; then
    online_install_upm_engine
  elif [[ ${OFFLINE_INSTALL} == "true" ]]; then
    offline_install_upm_engine
  fi
  verify_installed
}

main
