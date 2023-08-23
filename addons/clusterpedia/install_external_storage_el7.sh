#!/usr/bin/env bash

# You must be prepared as follows before run install.sh:
#
# 1. CLUSTERPEDIA_CONTROLLER_NODE_NAMES MUST be set as environment variable, for an example:
#
#        export CLUSTERPEDIA_CONTROLLER_NODE_NAMES="master01,master02"
#
# 2. CLUSTERPEDIA_WORKER_NODE_NAMES MUST be set as environment variable, for an example:
#
#        export CLUSTERPEDIA_WORKER_NODE_NAMES="worker01,worker02"
#
# 3. CLUSTERPEDIA_MYSQL_HOST MUST be set as environment variable, for an example:
#
#        export CLUSTERPEDIA_MYSQL_HOST="192.168.1.100"
#
# 4. CLUSTERPEDIA_MYSQL_PORT MUST be set as environment variable, for an example:
#
#        export CLUSTERPEDIA_MYSQL_PORT="3306"
#
# 5. CLUSTERPEDIA_MYSQL_USER MUST be set as environment variable, for an example:
#
#        export CLUSTERPEDIA_MYSQL_USER="clusterpedia"
#
# 6. CLUSTERPEDIA_MYSQL_PASSWORD MUST be set as environment variable, for an example:
#
#        export CLUSTERPEDIA_MYSQL_PASSWORD="password"
#

readonly CLUSTERPEDIA_NS="clusterpedia-system"
readonly CLUSTERPEDIA_MYSQL_DATABASE="clusterpedia"
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

install_clusterpedia() {
  info "Install clusterpedia..."
  local release="clusterpedia"
  # check if clusterpedia already installed
  if helm status ${release} -n ${CLUSTERPEDIA_NS} &>/dev/null; then
    error "${release} already installed. Use helm remove it first"
  fi
  info "Install ${release}, It might take a long time..."
  helm install ${release} clusterpedia/clusterpedia \
    --debug \
    --namespace ${CLUSTERPEDIA_NS} \
    --create-namespace \
    --set installCRDs=true \
    --set postgresql.enabled=false \
    --set mysql.enabled=false \
    --set persistenceMatchNode=None \
    --set storageInstallMode="external" \
    --set externalStorage.type="mysql" \
    --set externalStorage.host="${CLUSTERPEDIA_MYSQL_HOST}" \
    --set externalStorage.port="${CLUSTERPEDIA_MYSQL_PORT}" \
    --set externalStorage.user="${CLUSTERPEDIA_MYSQL_USER}" \
    --set externalStorage.password="${CLUSTERPEDIA_MYSQL_PASSWORD}" \
    --set externalStorage.database="${CLUSTERPEDIA_MYSQL_DATABASE}" \
    --set externalStorage.createDatabase=true \
    --set controllerManager.replicaCount="${CLUSTERPEDIA_CONTROLLER_NODE_COUNT}" \
    --set controllerManager.nodeSelector."clusterpedia\.io/control-plane"="enable" \
    --set apiserver.replicaCount="${CLUSTERPEDIA_CONTROLLER_NODE_COUNT}" \
    --set apiserver.nodeSelector."clusterpedia\.io/control-plane"="enable" \
    --set clustersynchroManager.replicaCount="${CLUSTERPEDIA_WORKER_NODE_COUNT}" \
    --set clustersynchroManager.nodeSelector."clusterpedia\.io/worker"="enable" \
    --timeout $TIME_OUT_SECOND \
    --wait 2>&1 | grep "\[debug\]" | awk '{$1="[Helm]"; $2=""; print }' | tee -a "${INSTALL_LOG_PATH}" || {
    error "Fail to install ${release}."
  }

  #TODO: check more resources after install

  helm status "${release}" -n "${CLUSTERPEDIA_NS}" | grep deployed &>/dev/null || {
    error "${release} installed fail, check log use helm and kubectl."
  }

  info "${release} Deployment Completed!"
}

init_helm_repo() {
  info "Start init helm clusterpedia repo"
  helm repo add clusterpedia https://clusterpedia-io.github.io/clusterpedia-helm/ &>/dev/null || {
    error "Helm repo add clusterpedia error."
  }
  info "Start update helm clusterpedia repo"
  if ! helm repo update clusterpedia 2>/dev/null; then
    error "Helm update clusterpedia repo error."
  fi
}

verify_supported() {
  local HAS_HELM
  HAS_HELM="$(type "helm" &>/dev/null && echo true || echo false)"
  local HAS_KUBECTL
  HAS_KUBECTL="$(type "kubectl" &>/dev/null && echo true || echo false)"
  local HAS_CURL
  HAS_CURL="$(type "curl" &>/dev/null && echo true || echo false)"

  if [[ -z "${CLUSTERPEDIA_CONTROLLER_NODE_NAMES}" ]]; then
    error "CLUSTERPEDIA_CONTROLLER_NODE_NAMES MUST set in environment variable."
  fi

  local control_node_array
  IFS="," read -r -a control_node_array <<<"${CLUSTERPEDIA_CONTROLLER_NODE_NAMES}"
  CLUSTERPEDIA_CONTROLLER_NODE_COUNT=0
  for node in "${control_node_array[@]}"; do
    kubectl label node "${node}" 'clusterpedia.io/control-plane=enable' --overwrite &>/dev/null || {
      error "kubectl label node ${node} 'clusterpedia.io/control-plane=enable' failed, use kubectl to check reason"
    }
    ((CLUSTERPEDIA_CONTROLLER_NODE_COUNT++))
  done

  if [[ -z "${CLUSTERPEDIA_WORKER_NODE_NAMES}" ]]; then
    error "CLUSTERPEDIA_WORKER_NODE_NAMES MUST set in environment variable."
  fi

  local worker_node_array
  IFS="," read -r -a worker_node_array <<<"${CLUSTERPEDIA_WORKER_NODE_NAMES}"
  CLUSTERPEDIA_WORKER_NODE_COUNT=0
  for node in "${worker_node_array[@]}"; do
    kubectl label node "${node}" 'clusterpedia.io/worker=enable' --overwrite &>/dev/null || {
      error "kubectl label node ${node} 'clusterpedia.io/worker=enable' failed, use kubectl to check reason"
    }
    ((CLUSTERPEDIA_WORKER_NODE_COUNT++))
  done

  if [[ -z "${CLUSTERPEDIA_MYSQL_HOST}" ]]; then
    error "CLUSTERPEDIA_MYSQL_HOST MUST set in environment variable."
  fi

  if [[ -z "${CLUSTERPEDIA_MYSQL_PORT}" ]]; then
    error "CLUSTERPEDIA_MYSQL_PORT MUST set in environment variable."
  fi

  if [[ -z "${CLUSTERPEDIA_MYSQL_USER}" ]]; then
    error "CLUSTERPEDIA_MYSQL_USER MUST set in environment variable."
  fi

  if [[ -z "${CLUSTERPEDIA_MYSQL_PASSWORD}" ]]; then
    error "CLUSTERPEDIA_MYSQL_PASSWORD MUST set in environment variable."
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
  INSTALL_LOG_PATH=/tmp/clusterpedia_install-$(date +'%Y-%m-%d_%H-%M-%S').log
  if ! touch "${INSTALL_LOG_PATH}"; then
    error "Create log file ${INSTALL_LOG_PATH} error"
  fi
  info "Log file create in path ${INSTALL_LOG_PATH}"
}

main() {
  init_log
  verify_supported
  init_helm_repo
  install_clusterpedia
}

main
