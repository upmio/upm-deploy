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
readonly VERSION="1.1.0"
readonly TESSERACT_VERSION="dev-ce4f7db5"
readonly SCEPTER_VERSION="dev-8e75ea5a"
readonly GAUNTLET_VERSION="dev-25c22709"
readonly TEMPLATE_VERSION="dev-d97237bb"

ENGINE_KUBE_NAMESPACE="${ENGINE_KUBE_NAMESPACE:-upm-system}"
ENGINE_RESOURCE_LIMITS_CPU="${REDIS_RESOURCE_LIMITS_CPU:-500m}"
ENGINE_RESOURCE_LIMITS_MEMORY="${REDIS_RESOURCE_LIMITS_MEMORY:-2Gi}"
ENGINE_RESOURCE_REQUESTS_CPU="${REDIS_RESOURCE_REQUESTS_CPU:-500m}"
ENGINE_RESOURCE_REQUESTS_MEMORY="${REDIS_RESOURCE_REQUESTS_MEMORY:-2Gi}"
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

install_upm_engine() {
  # check if upm-engine already installed
  if helm status ${RELEASE} -n "${ENGINE_KUBE_NAMESPACE}" &>/dev/null; then
    error "${RELEASE} already installed. Use helm remove it first"
  fi
  info "Install upm-engine, It might take a long time..."
  helm install ${RELEASE} ${CHART} \
    --debug \
    --version "${VERSION}" \
    --namespace "${ENGINE_KUBE_NAMESPACE}" \
    --create-namespace \
    --set-string configmaps.image.tag="${TEMPLATE_VERSION}" \
    --set-string tesseract.image.tag="${TESSERACT_VERSION}" \
    --set tesseract.replicaCount="${ENGINE_NODE_COUNT}" \
    --set-string tesseract.nodeAffinityPreset.type="hard" \
    --set-string tesseract.nodeAffinityPreset.key="upm\.engine\.node" \
    --set-string tesseract.nodeAffinityPreset.values='{enable}' \
    --set-string tesseract.resources.limits.cpu="${ENGINE_RESOURCE_LIMITS_CPU}" \
    --set-string tesseract.resources.limits.memory="${ENGINE_RESOURCE_LIMITS_MEMORY}" \
    --set-string tesseract.resources.requests.cpu="${ENGINE_RESOURCE_REQUESTS_CPU}" \
    --set-string tesseract.resources.requests.memory="${ENGINE_RESOURCE_REQUESTS_MEMORY}" \
    --set-string scepter.image.tag="${SCEPTER_VERSION}" \
    --set scepter.replicaCount="${ENGINE_NODE_COUNT}" \
    --set-string scepter.nodeAffinityPreset.type="hard" \
    --set-string scepter.nodeAffinityPreset.key="upm\.engine\.node" \
    --set-string scepter.nodeAffinityPreset.values='{enable}' \
    --set-string scepter.resources.limits.cpu="${ENGINE_RESOURCE_LIMITS_CPU}" \
    --set-string scepter.resources.limits.memory="${ENGINE_RESOURCE_LIMITS_MEMORY}" \
    --set-string scepter.resources.requests.cpu="${ENGINE_RESOURCE_REQUESTS_CPU}" \
    --set-string scepter.resources.requests.memory="${ENGINE_RESOURCE_REQUESTS_MEMORY}" \
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

  if [[ -z "${ENGINE_NODE_NAMES}" ]]; then
    error "ENGINE_NODE_NAMES MUST set in environment variable."
  fi

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
  INSTALL_LOG_PATH=/tmp/upm_engine_install-$(date +'%Y-%m-%d_%H-%M-%S').log
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
  helm status "${RELEASE}" -n "${ENGINE_KUBE_NAMESPACE}" | grep deployed &>/dev/null || {
    error "${RELEASE} installed fail, check log use helm and kubectl."
  }

  info "${RELEASE} Deployment Completed!"
}

main() {
  init_log
  verify_supported
  init_helm_repo
  install_upm_engine
  verify_installed
}

main
