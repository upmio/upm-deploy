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

readonly CHART="openebs-lvmlocalpv/lvm-localpv"
readonly RELEASE="openebs-lvmlocalpv"
readonly TIME_OUT_SECOND="600s"
readonly CHART_VERSION="1.4.0"

OFFLINE_INSTALL="${OFFLINE_INSTALL:-false}"
OPENEBS_KUBE_NAMESPACE="${OPENEBS_KUBE_NAMESPACE:-openebs}"
OPENEBS_CREATE_STORAGECLASS="${OPENEBS_CREATE_STORAGECLASS:-false}"
OPENEBS_STORAGECLASS_YAML="${OPENEBS_STORAGECLASS_YAML:-/tmp/storageclass.yaml}"
INSTALL_LOG_PATH=/tmp/openebs-lvmlocalpv_install-$(date +'%Y-%m-%d_%H-%M-%S').log

OPENEBS_CONTROLLER_RESOURCE_LIMITS_CPU="${OPENEBS_CONTROLLER_RESOURCE_LIMITS_CPU:-500m}"
OPENEBS_CONTROLLER_RESOURCE_LIMITS_MEMORY="${OPENEBS_CONTROLLER_RESOURCE_LIMITS_MEMORY:-512Mi}"
OPENEBS_CONTROLLER_RESOURCE_REQUESTS_CPU="${OPENEBS_CONTROLLER_RESOURCE_REQUESTS_CPU:-500m}"
OPENEBS_CONTROLLER_RESOURCE_REQUESTS_MEMORY="${OPENEBS_CONTROLLER_RESOURCE_REQUESTS_MEMORY:-512Mi}"
OPENEBS_NODE_RESOURCE_LIMITS_CPU="${OPENEBS_NODE_RESOURCE_LIMITS_CPU:-500m}"
OPENEBS_NODE_RESOURCE_LIMITS_MEMORY="${OPENEBS_NODE_RESOURCE_LIMITS_MEMORY:-512Mi}"
OPENEBS_NODE_RESOURCE_REQUESTS_CPU="${OPENEBS_NODE_RESOURCE_REQUESTS_CPU:-500m}"
OPENEBS_NODE_RESOURCE_REQUESTS_MEMORY="${OPENEBS_NODE_RESOURCE_REQUESTS_MEMORY:-512Mi}"

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

online_install_lvmlocalpv() {
  # check if openebs-lvmlocalpv already installed
  if helm status ${RELEASE} -n "${OPENEBS_KUBE_NAMESPACE}" &>/dev/null; then
    error "${RELEASE} already installed. Use helm remove it first"
  fi

  info "Start add helm openebs-lvmlocalpv repo"
  helm repo add openebs-lvmlocalpv https://openebs.github.io/lvm-localpv &>/dev/null || error "Helm add openebs-lvmlocalpv repo error."
  info "Start update helm openebs-lvmlocalpv repo"
  helm repo update openebs-lvmlocalpv 2>/dev/null || error "Helm update openebs-lvmlocalpv repo error."

  info "Install openebs-lvmlocalpv, It might take a long time..."
  helm install ${RELEASE} ${CHART} \
    --version "${CHART_VERSION}" \
    --namespace "${OPENEBS_KUBE_NAMESPACE}" \
    --create-namespace \
    --set lvmController.nodeSelector."openebs\.io/control-plane"="enable" \
    --set-string lvmController.resources.limits.cpu="${OPENEBS_CONTROLLER_RESOURCE_LIMITS_CPU}" \
    --set-string lvmController.resources.limits.memory="${OPENEBS_CONTROLLER_RESOURCE_LIMITS_MEMORY}" \
    --set-string lvmController.resources.requests.cpu="${OPENEBS_CONTROLLER_RESOURCE_REQUESTS_CPU}" \
    --set-string lvmController.resources.requests.memory="${OPENEBS_CONTROLLER_RESOURCE_REQUESTS_MEMORY}" \
    --set lvmNode.nodeSelector."openebs\.io/node"="enable" \
    --set-string lvmNode.resources.limits.cpu="${OPENEBS_NODE_RESOURCE_LIMITS_CPU}" \
    --set-string lvmNode.resources.limits.memory="${OPENEBS_NODE_RESOURCE_LIMITS_MEMORY}" \
    --set-string lvmNode.resources.requests.cpu="${OPENEBS_NODE_RESOURCE_REQUESTS_CPU}" \
    --set-string lvmNode.resources.requests.memory="${OPENEBS_NODE_RESOURCE_REQUESTS_MEMORY}" \
    --set lvmPlugin.allowedTopologies='kubernetes\.io/hostname\,openebs\.io/node' \
    --set analytics.enabled=false \
    --timeout $TIME_OUT_SECOND \
    --wait 2>&1 | tee -a "${INSTALL_LOG_PATH}" || {
    error "Fail to install ${RELEASE}."
  }

  #TODO: check more resources after install
}

offline_install_lvmlocalpv() {
  # check if openebs-lvmlocalpv already installed
  if helm status ${RELEASE} -n "${OPENEBS_KUBE_NAMESPACE}" &>/dev/null; then
    error "${RELEASE} already installed. Use helm remove it first"
  fi

  [[ -d "${OPENEBS_CHART_DIR}" ]] || error "OPENEBS_CHART_DIR not exist."

  local image_registry plugin_image_registry
  if [[ -z "${OPENEBS_IMAGE_REGISTRY}" ]]; then
    image_registry='registry.k8s.io/'
    plugin_image_registry=''
  else
    image_registry="${OPENEBS_IMAGE_REGISTRY}/"
    plugin_image_registry="${OPENEBS_IMAGE_REGISTRY}/"
  fi

  info "Install openebs-lvmlocalpv, It might take a long time..."
  helm install ${RELEASE} "${OPENEBS_CHART_DIR}" \
    --namespace "${OPENEBS_KUBE_NAMESPACE}" \
    --create-namespace \
    --set-string lvmController.resizer.image.registry="${image_registry}" \
    --set-string lvmController.snapshotter.image.registry="${image_registry}" \
    --set-string lvmController.snapshotController.image.registry="${image_registry}" \
    --set-string lvmController.provisioner.image.registry="${image_registry}" \
    --set lvmController.nodeSelector."openebs\.io/control-plane"="enable" \
    --set-string lvmController.resources.limits.cpu="${OPENEBS_CONTROLLER_RESOURCE_LIMITS_CPU}" \
    --set-string lvmController.resources.limits.memory="${OPENEBS_CONTROLLER_RESOURCE_LIMITS_MEMORY}" \
    --set-string lvmController.resources.requests.cpu="${OPENEBS_CONTROLLER_RESOURCE_REQUESTS_CPU}" \
    --set-string lvmController.resources.requests.memory="${OPENEBS_CONTROLLER_RESOURCE_REQUESTS_MEMORY}" \
    --set-string lvmNode.driverRegistrar.image.registry="${image_registry}" \
    --set lvmNode.nodeSelector."openebs\.io/node"="enable" \
    --set-string lvmNode.resources.limits.cpu="${OPENEBS_NODE_RESOURCE_LIMITS_CPU}" \
    --set-string lvmNode.resources.limits.memory="${OPENEBS_NODE_RESOURCE_LIMITS_MEMORY}" \
    --set-string lvmNode.resources.requests.cpu="${OPENEBS_NODE_RESOURCE_REQUESTS_CPU}" \
    --set-string lvmNode.resources.requests.memory="${OPENEBS_NODE_RESOURCE_REQUESTS_MEMORY}" \
    --set-string lvmPlugin.image.registry="${plugin_image_registry}" \
    --set lvmPlugin.allowedTopologies='kubernetes\.io/hostname\,openebs\.io/node' \
    --set analytics.enabled=false \
    --timeout $TIME_OUT_SECOND \
    --wait 2>&1 | tee -a "${INSTALL_LOG_PATH}" || {
    error "Fail to install ${RELEASE}."
  }

  #TODO: check more resources after install
}

verify_supported() {

  local HAS_HELM
  HAS_HELM="$(type "helm" &>/dev/null && echo true || echo false)"
  local HAS_KUBECTL
  HAS_KUBECTL="$(type "kubectl" &>/dev/null && echo true || echo false)"
  local HAS_CURL
  HAS_CURL="$(type "curl" &>/dev/null && echo true || echo false)"

  if [[ "${HAS_CURL}" != "true" ]]; then
    error "curl is required"
  fi

  if [[ "${HAS_HELM}" != "true" ]]; then
    install_helm
  fi

  if [[ "${HAS_KUBECTL}" != "true" ]]; then
    install_kubectl
  fi

  installed helm || error "helm is required"
  installed kubectl || error "kubectl is required"
  installed curl || error "curl is required"
  installed envsubst || error "envsubst is required"

  [[ -n "${OPENEBS_STORAGECLASS_NAME}" ]] || error "OPENEBS_STORAGECLASS_NAME MUST set in environment variable."
  [[ -n "${OPENEBS_VG_NAME}" ]] || error "OPENEBS_VG_NAME MUST set in environment variable."

  [[ -n "${OPENEBS_CONTROLLER_NODE_NAMES}" ]] || error "OPENEBS_CONTROLLER_NODE_NAMES MUST set in environment variable."
  local node
  local control_node_array
  IFS="," read -r -a control_node_array <<<"${OPENEBS_CONTROLLER_NODE_NAMES}"
  for node in "${control_node_array[@]}"; do
    kubectl label node "${node}" 'openebs.io/control-plane=enable' --overwrite &>/dev/null || {
      error "kubectl label node ${node} 'openebs.io/control-plane=enable' failed, use kubectl to check reason"
    }
  done
  [[ -n "${OPENEBS_DATA_NODE_NAMES}" ]] || error "OPENEBS_DATA_NODE_NAMES MUST set in environment variable."
  local data_node_array
  IFS="," read -r -a data_node_array <<<"${OPENEBS_DATA_NODE_NAMES}"
  for node in "${data_node_array[@]}"; do
    kubectl label node "${node}" 'openebs.io/node=enable' --overwrite &>/dev/null || {
      error "kubectl label node ${node} 'openebs.io/node=enable' failed, use kubectl to check reason"
    }
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
  status=$(helm status "${RELEASE}" -n "${OPENEBS_KUBE_NAMESPACE}" | grep ^STATUS: | awk '{print $2}')
  [[ "${status}" == "deployed" ]] || {
    error "Helm release ${RELEASE} status is not deployed, use helm to check reason"
  }

  info "${RELEASE} Deployment Completed!"
}

create_storageclass() {
  [[ -f ${OPENEBS_STORAGECLASS_YAML} ]] || {
    local download_url="https://raw.githubusercontent.com/upmio/upm-deploy/main/addons/openebs-lvmlocalpv/yaml/storageclass.yaml"
    curl -sSL "${download_url}" -o "${OPENEBS_STORAGECLASS_YAML}" || {
      error "curl get storageclass.yaml failed"
    }
  }

  OPENEBS_STORAGECLASS_NAME="${OPENEBS_STORAGECLASS_NAME}" \
    OPENEBS_VG_NAME="${OPENEBS_VG_NAME}" \
    envsubst <"${OPENEBS_STORAGECLASS_YAML}" | kubectl apply -f - || {
    error "kubectl create storageclass failed, check log use kubectl."
  }

  info "create storageclass successful!"
}

main() {
  init_log
  verify_supported
  if [[ ${OFFLINE_INSTALL} == "false" ]]; then
    online_install_lvmlocalpv
  elif [[ ${OFFLINE_INSTALL} == "true" ]]; then
    offline_install_lvmlocalpv
  fi
  verify_installed
  if [[ ${OPENEBS_CREATE_STORAGECLASS} == "true" ]]; then
    create_storageclass
  else
    info "OPENEBS_CREATE_STORAGECLASS disable, skip create storageclass."
  fi
}

main
