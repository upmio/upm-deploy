#!/usr/bin/env bash

# You must be prepared as follows before run install.sh:
#
# 1. DB_USER MUST be set as environment variable, for an example:
#
#        export DB_USER="admin"
#
# 2. DB_PWD MUST be set as environment variable, for an example:
#
#        export DB_PWD="passwords"
#
# 3. DB_STORAGECLASS_NAME MUST be set as environment variable, for an example:
#
#        export DB_STORAGECLASS_NAME=""
#
# 4. DB_PVC_SIZE_G MUST be set as environment variable, for an example:
#
#        export DB_PVC_SIZE_G="50"
#
# 5. DB_NODE_NAMES MUST be set as environment variable, for an example:
#
#        export DB_NODE_NAMES="kube-node01"

readonly NAMESPACE="mysql"
readonly CHART="mysqlrepo/mysql"
readonly RELEASE="mysql"
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

install_mysql() {
  # check if mysql already installed
  if helm status ${RELEASE} -n ${NAMESPACE} &>/dev/null; then
    error "${RELEASE} already installed. Use helm remove it first"
  fi
  info "Install mysql, It might take a long time..."
  helm install ${RELEASE} ${CHART} \
    --debug \
    --namespace ${NAMESPACE} \
    --create-namespace \
    --set auth.username=''${DB_USER}'' \
    --set auth.password=''${DB_PWD}'' \
    --set architecture='standalone' \
    --set persistence.storageClassName="${DB_STORAGECLASS_NAME}" \
    --set persistence.size=${DB_PVC_SIZE_G}Gi \
    --set nodeAffinityPreset.type="hard" \
    --set nodeAffinityPreset.key="mysql\.node" \
    --set nodeAffinityPreset.values='{enable}' \
    --timeout $TIME_OUT_SECOND \
    --wait 2>&1 | grep "\[debug\]" | awk '{$1="[Helm]"; $2=""; print }' | tee -a "${INSTALL_LOG_PATH}" || {
    error "Fail to install ${RELEASE}."
  }

  #TODO: check more resources after install
}

init_helm_repo() {
  helm repo add mysqlrepo https://haolowkey.github.io/helm-mysql &>/dev/null
  info "Start update helm mysql repo"
  if ! helm repo update mysqlrepo 2>/dev/null; then
    error "Helm update mysql repo error."
  fi
}

verify_supported() {
  local HAS_HELM
  HAS_HELM="$(type "helm" &>/dev/null && echo true || echo false)"
  local HAS_KUBECTL
  HAS_KUBECTL="$(type "kubectl" &>/dev/null && echo true || echo false)"
  local HAS_CURL
  HAS_CURL="$(type "curl" &>/dev/null && echo true || echo false)"

  if [[ -z "${DB_USER}" ]]; then
    error "DB_USER MUST set in environment variable."
  fi

  if [[ -z "${DB_PWD}" ]]; then
    error "DB_PWD MUST set in environment variable."
  fi

  if [[ -z "${DB_STORAGECLASS_NAME}" ]]; then
    error "DB_STORAGECLASS_NAME MUST set in environment variable."
  fi

  kubectl get storageclasses "${DB_STORAGECLASS_NAME}" &>/dev/null || {
    error "storageclass resources not all ready, use kubectl to check reason"
  }

  if [[ -z "${DB_PVC_SIZE_G}" ]]; then
    error "DB_PVC_SIZE_G MUST set in environment variable."
  fi

  if [[ -z "${DB_NODE_NAMES}" ]]; then
    error "DB_NODE_NAMES MUST set in environment variable."
  fi

  local db_node_array
  IFS="," read -r -a db_node_array <<<"${DB_NODE_NAMES}"
  for node in "${db_node_array[@]}"; do
    kubectl label node "${node}" 'mysql.node=enable' --overwrite &>/dev/null || {
      error "kubectl label node ${node} 'mysql.node=enable' failed, use kubectl to check reason"
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
  INSTALL_LOG_PATH=/tmp/mysql_install-$(date +'%Y-%m-%d_%H-%M-%S').log
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
  install_mysql
  verify_installed
}

main
