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
readonly CHART_VERSION="1.1.2"
readonly TESSERACT_CUBE_VERSION="v1.1.0"
readonly KAUNTLET_VERSION="v1.1.0"
readonly TEMPLATE_VERSION="v1.1.0"

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

install_upm_engine_on_openshift() {
  # install tesseract-cube-operator
  kubectl apply -f - <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: tesseract-cube-catalog
  namespace: openshift-marketplace
spec:
  sourceType: grpc
  image: quay.io/upmio/tesseract-cube-catalog:${TESSERACT_CUBE_VERSION}
  displayName: tesseract-cube
  publisher: BSG
EOF

  kubectl apply -f - <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  labels: 
    operators.coreos.com/tesseract-cube.openshift-operators: ""
  name: tesseract-cube-operator
  namespace: openshift-operators
spec:
  channel: alpha
  installPlanApproval: Automatic
  name: tesseract-cube
  source: tesseract-cube-catalog
  sourceNamespace: openshift-marketplace
  startingCSV: tesseract-cube.${TESSERACT_CUBE_VERSION}
EOF

  # install kauntlet-operator
  kubectl apply -f - <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: kauntlet-catalog
  namespace: openshift-marketplace
spec:
  sourceType: grpc
  image: quay.io/upmio/kauntlet-catalog:${KAUNTLET_VERSION}
  displayName: kauntlet
  publisher: BSG
EOF

  kubectl apply -f - <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  labels:
    operators.coreos.com/kauntlet.openshift-operators: ""
  name: kauntlet-operator
  namespace: openshift-operators
spec:
  channel: alpha
  installPlanApproval: Automatic
  name: kauntlet
  source: kauntlet-catalog
  sourceNamespace: openshift-marketplace
  startingCSV: kauntlet.${KAUNTLET_VERSION}
EOF

  # create import-configmap-job rbac
  kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: ${RELEASE}-import-configmaps-role
  namespace: openshift-operators
rules:
- apiGroups:
  - ""
  resources:
  - configmaps
  verbs:
  - create
  - get
  - list
  - watch
  - patch
  - update
EOF

  kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: ${RELEASE}-import-configmaps-rolebinding
  namespace: openshift-operators
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: ${RELEASE}-import-configmaps-role
subjects:
- kind: ServiceAccount
  name: ${RELEASE}-import-configmaps-sa
  namespace: openshift-operators
EOF

  kubectl apply -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: ${RELEASE}-import-configmaps-sa
  namespace: openshift-operators
EOF

  # create import-configmap-job
  kubectl apply -f - <<EOF
apiVersion: batch/v1
kind: Job
metadata:
  labels:
    app.kubernetes.io/instance: ${RELEASE}
  name: "${RELEASE}-import-configmaps"
  namespace: openshift-operators
spec:
  template:
    metadata:
      name: ${RELEASE}
      labels:
        app.kubernetes.io/instance: ${RELEASE}
    spec:
      serviceAccountName: ${RELEASE}-import-configmaps-sa
      restartPolicy: Never
      containers:
      - name: import-configmaps
        image: quay.io/upmio/upm-template:${TEMPLATE_VERSION}
        imagePullPolicy: IfNotPresent
        command:
          - /bin/bash
          - -ec
          - |
            kubectl apply --server-side -f /configmaps/ -n openshift-operators --force-conflicts
       
EOF
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
    --set tesseract-cube.crds.enabled=true \
    --set-string configmaps.image.tag="${TEMPLATE_VERSION}" \
    --set-string tesseract-cube.image.tag="${TESSERACT_CUBE_VERSION}" \
    --set-string tesseract-cube.agent.image.tag="${TESSERACT_CUBE_VERSION}" \
    --set tesseract-cube.replicaCount="${ENGINE_NODE_COUNT}" \
    --set-string tesseract-cube.nodeAffinityPreset.type="hard" \
    --set-string tesseract-cube.nodeAffinityPreset.key="upm\.engine\.node" \
    --set-string tesseract-cube.nodeAffinityPreset.values='{enable}' \
    --set-string tesseract-cube.resources.limits.cpu="${ENGINE_RESOURCE_LIMITS_CPU}" \
    --set-string tesseract-cube.resources.limits.memory="${ENGINE_RESOURCE_LIMITS_MEMORY}" \
    --set-string tesseract-cube.resources.requests.cpu="${ENGINE_RESOURCE_REQUESTS_CPU}" \
    --set-string tesseract-cube.resources.requests.memory="${ENGINE_RESOURCE_REQUESTS_MEMORY}" \
    --set kauntlet.crds.enabled=true \
    --set-string kauntlet.image.tag="${KAUNTLET_VERSION}" \
    --set kauntlet.replicaCount="${ENGINE_NODE_COUNT}" \
    --set-string kauntlet.nodeAffinityPreset.type="hard" \
    --set-string kauntlet.nodeAffinityPreset.key="upm\.engine\.node" \
    --set-string kauntlet.nodeAffinityPreset.values='{enable}' \
    --set-string kauntlet.resources.limits.cpu="${ENGINE_RESOURCE_LIMITS_CPU}" \
    --set-string kauntlet.resources.limits.memory="${ENGINE_RESOURCE_LIMITS_MEMORY}" \
    --set-string kauntlet.resources.requests.cpu="${ENGINE_RESOURCE_REQUESTS_CPU}" \
    --set-string kauntlet.resources.requests.memory="${ENGINE_RESOURCE_REQUESTS_MEMORY}" \
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

  [[ -d "${ENGINE_CHART_DIR}" ]] || error "ENGINE_CHART_DIR not exist."

  info "Install upm-engine, It might take a long time..."
  helm install ${RELEASE} "${ENGINE_CHART_DIR}" \
    --namespace "${ENGINE_KUBE_NAMESPACE}" \
    --create-namespace \
    --set-string global.imageRegistry="${ENGINE_IMAGE_REGISTRY}" \
    --set tesseract-cube.crds.enabled=true \
    --set-string configmaps.image.tag="${TEMPLATE_VERSION}" \
    --set-string tesseract-cube.image.tag="${TESSERACT_CUBE_VERSION}" \
    --set-string tesseract-cube.agent.image.tag="${TESSERACT_CUBE_VERSION}" \
    --set tesseract-cube.replicaCount="${ENGINE_NODE_COUNT}" \
    --set-string tesseract-cube.nodeAffinityPreset.type="hard" \
    --set-string tesseract-cube.nodeAffinityPreset.key="upm\.engine\.node" \
    --set-string tesseract-cube.nodeAffinityPreset.values='{enable}' \
    --set-string tesseract-cube.resources.limits.cpu="${ENGINE_RESOURCE_LIMITS_CPU}" \
    --set-string tesseract-cube.resources.limits.memory="${ENGINE_RESOURCE_LIMITS_MEMORY}" \
    --set-string tesseract-cube.resources.requests.cpu="${ENGINE_RESOURCE_REQUESTS_CPU}" \
    --set-string tesseract-cube.resources.requests.memory="${ENGINE_RESOURCE_REQUESTS_MEMORY}" \
    --set kauntlet.crds.enabled=true \
    --set-string kauntlet.image.tag="${KAUNTLET_VERSION}" \
    --set kauntlet.replicaCount="${ENGINE_NODE_COUNT}" \
    --set-string kauntlet.nodeAffinityPreset.type="hard" \
    --set-string kauntlet.nodeAffinityPreset.key="upm\.engine\.node" \
    --set-string kauntlet.nodeAffinityPreset.values='{enable}' \
    --set-string kauntlet.resources.limits.cpu="${ENGINE_RESOURCE_LIMITS_CPU}" \
    --set-string kauntlet.resources.limits.memory="${ENGINE_RESOURCE_LIMITS_MEMORY}" \
    --set-string kauntlet.resources.requests.cpu="${ENGINE_RESOURCE_REQUESTS_CPU}" \
    --set-string kauntlet.resources.requests.memory="${ENGINE_RESOURCE_REQUESTS_MEMORY}" \
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
}

label_resource() {
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

  # detect if the cluster is OpenShift
  if kubectl api-resources | grep security.openshift.io/v1 &>/dev/null; then
    install_upm_engine_on_openshift
    check_resource_on_openshift
  # detect if the cluster is Kubernetes
  else
    label_resource
    if [[ ${OFFLINE_INSTALL} == "false" ]]; then
      online_install_upm_engine
    elif [[ ${OFFLINE_INSTALL} == "true" ]]; then
      offline_install_upm_engine
    fi
    verify_installed
  fi
}

check_resource_on_openshift() {
  if [[ "$(kubectl get csv -n openshift-operators kauntlet."${TEMPLATE_VERSION}" -o jsonpath='{.status.phase}')" == 'Succeeded' ]]; then
    echo "csv kauntlet.${TEMPLATE_VERSION} create Succeeded"
  else
    echo "csv kauntlet.${TEMPLATE_VERSION} create failed"
  fi

  if [[ "$(kubectl get csv -n openshift-operators tesseract-cube."${TESSERACT_CUBE_VERSION}" -o jsonpath='{.status.phase}')" == 'Succeeded' ]]; then
    echo "csv tesseract-cube.${TESSERACT_CUBE_VERSION} create Succeeded"
  else
    echo "csv tesseract-cube.${TESSERACT_CUBE_VERSION} create failed"
  fi

  if [[ "$(kubectl get catalogsources -n openshift-operators kauntlet-catalog -o jsonpath='{.status.lastObservedState}')" == 'READY' ]]; then
    echo "catalogsources kauntlet-catalog create Succeeded"
  else
    echo "catalogsources kauntlet-catalog create failed"
  fi

  if [[ "$(kubectl get catalogsources -n openshift-marketplace tesseract-cube-catalog -o jsonpath='{.status.lastObservedState}')" == 'READY' ]]; then
    echo "catalogsources tesseract-cube-catalog create Succeeded"
  else
    echo "catalogsources tesseract-cube-catalog create failed"
  fi
}

main
