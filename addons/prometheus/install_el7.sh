#!/usr/bin/env bash 

readonly NAMESPACE="prometheus"
readonly CHART="prometheus-community/kube-prometheus-stack"
readonly RELEASE="prometheus"
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

install_prometheus() {
  # check if prometheus already installed
  if helm status ${RELEASE} -n ${NAMESPACE} &>/dev/null; then
    error "${RELEASE} already installed. Use helm remove it first"
  fi
  info "Install prometheus, It might take a long time..."
  helm upgrade ${RELEASE} ${CHART} \
  --debug \
  --namespace ${NAMESPACE} \
  --create-namespace \
  --install \
  --set prometheusOperator.admissionWebhooks.patch.image.registry=docker.io \
  --set prometheusOperator.admissionWebhooks.patch.image.repository=dyrnq/kube-webhook-certgen \
  --set prometheus.prometheusSpec.podMonitorSelectorNilUsesHelmValues=false \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false \
  --set prometheusOperator.prometheusConfigReloader.admissionWebhooks.patch.affinity.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution.nodeSelectorTerms[0].matchExpressions[0].key=prometheus.node \
  --set prometheusOperator.prometheusConfigReloader.admissionWebhooks.patch.affinity.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution.nodeSelectorTerms[0].matchExpressions[0].operator=Exists \
  --set prometheusOperator.affinity.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution.nodeSelectorTerms[0].matchExpressions[0].key=prometheus.node \
  --set prometheusOperator.affinity.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution.nodeSelectorTerms[0].matchExpressions[0].operator=Exists \
  --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.storageClassName="${PROM_STORAGECLASS_NAME}" \
  --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.accessModes[0]=ReadWriteOnce \
  --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage=${PROM_PVC_SIZE_G}Gi \
  --set prometheus.prometheusSpec.affinity.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution.nodeSelectorTerms[0].matchExpressions[0].key=prometheus.node \
  --set prometheus.prometheusSpec.affinity.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution.nodeSelectorTerms[0].matchExpressions[0].operator=Exists \
  --set alertmanager.alertmanagerSpec.affinity.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution.nodeSelectorTerms[0].matchExpressions[0].key=prometheus.node \
  --set alertmanager.alertmanagerSpec.affinity.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution.nodeSelectorTerms[0].matchExpressions[0].operator=Exists \
  --set grafana.affinity.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution.nodeSelectorTerms[0].matchExpressions[0].key=prometheus.node \
  --set grafana.affinity.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution.nodeSelectorTerms[0].matchExpressions[0].operator=Exists \
  --set kube-state-metrics.affinity.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution.nodeSelectorTerms[0].matchExpressions[0].key=prometheus.node \
  --set kube-state-metrics.affinity.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution.nodeSelectorTerms[0].matchExpressions[0].operator=Exists \
  --set kube-state-metrics.image.registry=docker.io \
  --set kube-state-metrics.image.repository=dbscale/kube-state-metrics \
  --set kube-state-metrics.image.tag="v2.9.2"
    --timeout $TIME_OUT_SECOND \
    --wait 2>&1 | grep "\[debug\]" | awk '{$1="[Helm]"; $2=""; print }' | tee -a "${INSTALL_LOG_PATH}" || {
    error "Fail to install ${RELEASE}."
  }

  #TODO: check more resources after install
}

init_helm_repo() {
  helm repo add prometheus-community https://prometheus-community.github.io/helm-charts &>/dev/null
  info "Start update helm prometheus repo"
  if ! helm repo update prometheus-community 2>/dev/null; then
    error "Helm update prometheus repo error."
  fi
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

  if [[ -z "${PROM_STORAGECLASS_NAME}" ]]; then
    error "PROM_STORAGECLASS_NAME MUST set in environment variable."
  fi

  kubectl get storageclasses "${PROM_STORAGECLASS_NAME}" &>/dev/null || {
    error "storageclass resources not all ready, use kubectl to check reason"
  }

  if [[ -z "${PROM_PVC_SIZE_G}" ]]; then
    error "PROM_PVC_SIZE_G MUST set in environment variable."
  fi

  if [[ -z "${PROM_NODE_NAMES}" ]]; then
    error "PROM_NODE_NAMES MUST set in environment variable."
  fi

  local db_node_array
  IFS="," read -r -a db_node_array <<<"${PROM_NODE_NAMES}"
  for node in "${PROM_node_array[@]}"; do
    kubectl label node "${node}" 'prometheus.node=enable' --overwrite &>/dev/null || {
      error "kubectl label node ${node} 'prometheus.node=enable' failed, use kubectl to check reason"
    }
  done

}

init_log() {
  INSTALL_LOG_PATH=/tmp/prometheus_install-$(date +'%Y-%m-%d_%H-%M-%S').log
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
  install_prometheus
  verify_installed
}

main
