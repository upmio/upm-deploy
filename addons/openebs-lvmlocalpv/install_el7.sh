#!/usr/bin/env bash

# You must be prepared as follows before run install.sh:
#
# 1. OPENEBS_CONTROLLER_NODE_NAMES MUST be set as environment variable, for an example:
#
#        export OPENEBS_CONTROLLER_NODE_NAMES="master01,master02"
#
# 2. OPENEBS_DATA_NODE_NAMES MUST be set as environment variable, for an example:
#
#        export OPENEBS_DATA_NODE_NAMES="node01,node02"
#
# 4. OPENEBS_STORAGECLASS_NAME MUST be set as environment variable, for an example:
#
#        export OPENEBS_STORAGECLASS_NAME="openebs-lvmsc-hdd"
#
# 3. OPENEBS_VG_NAME MUST be set as environment variable, for an example:
#
#        export OPENEBS_VG_NAME="local_HDD_VG"
#

readonly NAMESPACE="openebs"
readonly CHART="openebs-lvmlocalpv/lvm-localpv"
readonly RELEASE="openebs-lvmlocalpv"
readonly TIME_OUT_SECOND="600s"

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

install_lvmlocalpv() {
  # check if openebs-lvmlocalpv already installed
  if helm status ${RELEASE} -n ${NAMESPACE} &>/dev/null; then
    error "${RELEASE} already installed. Use helm remove it first"
  fi
  info "Install openebs-lvmlocalpv, It might take a long time..."
  helm install ${RELEASE} ${CHART} \
    --debug \
    --namespace ${NAMESPACE} \
    --create-namespace \
    --set lvmController.nodeSelector."openebs\.io/control-plane"="enable" \
    --set lvmNode.nodeSelector."openebs\.io/node"="enable" \
    --set lvmPlugin.allowedTopologies='kubernetes\.io/hostname\,openebs\.io/node' \
    --set analytics.enabled=false \
    --timeout $TIME_OUT_SECOND \
    --wait 2>&1 | grep "\[debug\]" | awk '{$1="[Helm]"; $2=""; print }' | tee -a "${INSTALL_LOG_PATH}" || {
    error "Fail to install ${RELEASE}."
  }

  #TODO: check more resources after install
}

init_helm_repo() {
  helm repo add openebs-lvmlocalpv https://openebs.github.io/lvm-localpv &>/dev/null
  info "Start update helm openebs-lvmlocalpv repo"
  if ! helm repo update openebs-lvmlocalpv 2>/dev/null; then
    error "Helm update openebs-lvmlocalpv repo error."
  fi
}

verify_supported() {
  local HAS_HELM
  HAS_HELM="$(type "helm" &>/dev/null && echo true || echo false)"
  local HAS_KUBECTL
  HAS_KUBECTL="$(type "kubectl" &>/dev/null && echo true || echo false)"
  local HAS_CURL
  HAS_CURL="$(type "curl" &>/dev/null && echo true || echo false)"

  if [[ -z "${OPENEBS_STORAGECLASS_NAME}" ]]; then
    error "OPENEBS_STORAGECLASS_NAME MUST set in environment variable."
  fi

  if [[ -z "${OPENEBS_VG_NAME}" ]]; then
    error "OPENEBS_VG_NAME MUST set in environment variable."
  fi

  if [[ -z "${OPENEBS_CONTROLLER_NODE_NAMES}" ]]; then
    error "OPENEBS_CONTROLLER_NODE_NAMES MUST set in environment variable."
  fi

  local control_node_array
  IFS="," read -r -a control_node_array <<<"${OPENEBS_CONTROLLER_NODE_NAMES}"
  for node in "${control_node_array[@]}"; do
    kubectl label node "${node}" 'openebs.io/control-plane=enable' --overwrite &>/dev/null || {
      error "kubectl label node ${node} 'openebs.io/control-plane=enable' failed, use kubectl to check reason"
    }
  done

  if [[ -z "${OPENEBS_DATA_NODE_NAMES}" ]]; then
    error "OPENEBS_DATA_NODE_NAMES MUST set in environment variable."
  fi

  local data_node_array
  IFS="," read -r -a data_node_array <<<"${OPENEBS_DATA_NODE_NAMES}"
  for node in "${data_node_array[@]}"; do
    kubectl label node "${node}" 'openebs.io/node=enable' --overwrite &>/dev/null || {
      error "kubectl label node ${node} 'openebs.io/node=enable' failed, use kubectl to check reason"
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
  INSTALL_LOG_PATH=/tmp/openebs-lvmlocalpv_install-$(date +'%Y-%m-%d_%H-%M-%S').log
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

create_storageclass() {
  info "create storageclass..."
  curl -sSL https://raw.githubusercontent.com/upmio/infini-scale-install/main/addons/openebs-lvmlocalpv/yaml/storageclass.yaml | envsubst | kubectl apply -f - || {
    error "kubectl create storageclass fail, check log use kubectl."
  }

  info "create storageclass successful!"
}

main() {
  init_log
  verify_supported
  init_helm_repo
  install_lvmlocalpv
  verify_installed
  create_storageclass
}

main
