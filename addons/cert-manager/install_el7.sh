#!/usr/bin/env bash

# You must be prepared as follows before run install.sh:
#
# 1. CERT_MANAGER_NODE_NAMES MUST be set as environment variable, for an example:
#
#        export CERT_MANAGER_NODE_NAMES="master01,master02"
#

readonly CHART="jetstack/cert-manager"
readonly RELEASE="cert-manager"
readonly TIME_OUT_SECOND="600s"
readonly VERSION="v1.13.1"

NAMESPACE="${CERT_MANAGER_NAMESPACE:-cert-manager}"
CERT_MANAGER_RESOURCE_LIMITS_CPU="${CERT_MANAGER_RESOURCE_LIMITS_CPU:-500m}"
CERT_MANAGER_RESOURCE_LIMITS_MEMORY="${CERT_MANAGER_RESOURCE_LIMITS_MEMORY:-512Mi}"
CERT_MANAGER_RESOURCE_REQUESTS_CPU="${CERT_MANAGER_RESOURCE_REQUESTS_CPU:-500m}"
CERT_MANAGER_RESOURCE_REQUESTS_MEMORY="${CERT_MANAGER_RESOURCE_REQUESTS_MEMORY:-512Mi}"

CERT_MANAGER_WEBHOOK_RESOURCE_LIMITS_CPU="${CERT_MANAGER_WEBHOOK_RESOURCE_LIMITS_CPU:-100m}"
CERT_MANAGER_WEBHOOK_RESOURCE_LIMITS_MEMORY="${CERT_MANAGER_WEBHOOK_RESOURCE_LIMITS_MEMORY:-128Mi}"
CERT_MANAGER_WEBHOOK_RESOURCE_REQUESTS_CPU="${CERT_MANAGER_WEBHOOK_RESOURCE_REQUESTS_CPU:-100m}"
CERT_MANAGER_WEBHOOK_RESOURCE_REQUESTS_MEMORY="${CERT_MANAGER_WEBHOOK_RESOURCE_REQUESTS_MEMORY:-128Mi}"

CERT_MANAGER_CAINJECTOR_RESOURCE_LIMITS_CPU="${CERT_MANAGER_CAINJECTOR_RESOURCE_LIMITS_CPU:-100m}"
CERT_MANAGER_CAINJECTOR_RESOURCE_LIMITS_MEMORY="${CERT_MANAGER_CAINJECTOR_RESOURCE_LIMITS_MEMORY:-128Mi}"
CERT_MANAGER_CAINJECTOR_RESOURCE_REQUESTS_CPU="${CERT_MANAGER_CAINJECTOR_RESOURCE_REQUESTS_CPU:-100m}"
CERT_MANAGER_CAINJECTOR_RESOURCE_REQUESTS_MEMORY="${CERT_MANAGER_CAINJECTOR_RESOURCE_REQUESTS_MEMORY:-128Mi}"
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
  if helm status ${RELEASE} -n "${NAMESPACE}" &>/dev/null; then
    error "${RELEASE} already installed. Use helm remove it first"
  fi
  info "Install cert-manager, It might take a long time..."
  helm install ${RELEASE} ${CHART} \
    --debug \
    --version "${VERSION}" \
    --namespace "${NAMESPACE}" \
    --create-namespace \
    --set installCRDs='true' \
    --set nodeSelector."cert-manager/node"="enable" \
    --set-string resources.limits.cpu="${CERT_MANAGER_RESOURCE_LIMITS_CPU}" \
    --set-string resources.limits.memory="${CERT_MANAGER_RESOURCE_LIMITS_MEMORY}" \
    --set-string resources.requests.cpu="${CERT_MANAGER_RESOURCE_REQUESTS_CPU}" \
    --set-string resources.requests.memory="${CERT_MANAGER_RESOURCE_REQUESTS_MEMORY}" \
    --set webhook.nodeSelector."cert-manager/node"="enable" \
    --set-string webhook.resources.limits.cpu="${CERT_MANAGER_WEBHOOK_RESOURCE_LIMITS_CPU}" \
    --set-string webhook.resources.limits.memory="${CERT_MANAGER_WEBHOOK_RESOURCE_LIMITS_MEMORY}" \
    --set-string webhook.resources.requests.cpu="${CERT_MANAGER_WEBHOOK_RESOURCE_REQUESTS_CPU}" \
    --set-string webhook.resources.requests.memory="${CERT_MANAGER_WEBHOOK_RESOURCE_REQUESTS_MEMORY}" \
    --set cainjector.nodeSelector."cert-manager/node"="enable" \
    --set-string cainjector.resources.limits.cpu="${CERT_MANAGER_CAINJECTOR_RESOURCE_LIMITS_CPU}" \
    --set-string cainjector.resources.limits.memory="${CERT_MANAGER_CAINJECTOR_RESOURCE_LIMITS_MEMORY}" \
    --set-string cainjector.resources.requests.cpu="${CERT_MANAGER_CAINJECTOR_RESOURCE_REQUESTS_CPU}" \
    --set-string cainjector.resources.requests.memory="${CERT_MANAGER_CAINJECTOR_RESOURCE_REQUESTS_MEMORY}" \
    --set startupapicheck.enabled=false \
    --set 'extraArgs={--enable-certificate-owner-ref=true}' \
    --timeout $TIME_OUT_SECOND \
    --wait 2>&1 | grep "\[debug\]" | awk '{$1="[Helm]"; $2=""; print }' | tee -a "${INSTALL_LOG_PATH}" || {
    error "Fail to install ${RELEASE}."
  }

  #TODO: check more resources after install
}

init_helm_repo() {
  helm repo add jetstack https://charts.jetstack.io &>/dev/null
  info "Start update helm cert-manager repo"
  if ! helm repo update jetstack 2>/dev/null; then
    error "Helm update cert-manager repo error."
  fi
}

verify_supported() {
  local HAS_HELM
  HAS_HELM="$(type "helm" &>/dev/null && echo true || echo false)"
  local HAS_KUBECTL
  HAS_KUBECTL="$(type "kubectl" &>/dev/null && echo true || echo false)"
  local HAS_CURL
  HAS_CURL="$(type "curl" &>/dev/null && echo true || echo false)"

  if [[ -z "${CERT_MANAGER_NODE_NAMES}" ]]; then
    error "CERT_MANAGER_NODE_NAMES MUST set in environment variable."
  fi

  local node
  local node_array
  IFS="," read -r -a node_array <<<"${CERT_MANAGER_NODE_NAMES}"
  for node in "${node_array[@]}"; do
    kubectl label node "${node}" 'cert-manager/node=enable' --overwrite &>/dev/null || {
      error "kubectl label node ${node} 'cert-manager/node=enable' failed, use kubectl to check reason"
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
  INSTALL_LOG_PATH=/tmp/cert-manager_install-$(date +'%Y-%m-%d_%H-%M-%S').log
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
  install_cert_managers
  verify_installed
}

main
