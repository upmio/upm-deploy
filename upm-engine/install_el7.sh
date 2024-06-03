#!/usr/bin/env bash

# You must be prepared as follows before run install.sh:
#
# 1. ENGINE_NODE_NAMES MUST be set as environment variable, for an example:
#
#        export ENGINE_NODE_NAMES="master01,master02"
#

readonly CHART="upm-charts/upm-engine"
readonly RELEASE="upm-engine"
readonly TIME_OUT_SECOND="600"
readonly CHART_VERSION="1.1.2"
readonly TESSERACT_CUBE_VERSION="v1.1.1"
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

add_operator_on_openshift() {
  local operator_name=$1
  local operator_version=$2
  local catalog_namespace="openshift-marketplace"
  local operators_namespace="openshift-operators"
  local publisher="BSG"

  kubectl apply -f - <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: ${operator_name}-catalog
  namespace: ${catalog_namespace}
spec:
  sourceType: grpc
  image: quay.io/upmio/${operator_name}-catalog:${operator_version}
  displayName: ${operator_name}
  publisher: ${publisher}
EOF

  kubectl apply -f - <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  labels:
    operators.coreos.com/${operator_name}.openshift-operators: ""
  name: ${operator_name}-operator
  namespace: ${operators_namespace}
spec:
  channel: alpha
  installPlanApproval: Automatic
  name: ${operator_name}
  source: ${operator_name}-catalog
  sourceNamespace: ${catalog_namespace}
  startingCSV: ${operator_name}.${operator_version}
EOF

  # while csv status is not Succeeded, keep checking
  count=0
  while true; do
    # get ClusterServiceVersion name from Subscription
    local csv_name
    csv_name=$(kubectl get subscription -n "${operators_namespace}" "${operator_name}-operator" -ojsonpath='{.status.installedCSV}')
    local csv_phase
    csv_phase=$(kubectl get csv -n ${operators_namespace} "${csv_name}" -ojsonpath='{.status.phase}')
    if [ "$csv_phase" == "Succeeded" ]; then
      echo "${operator_name} csv created successfully"
      break
    fi

    ((count++))
    if [[ $count -gt $TIME_OUT_SECOND ]]; then
      echo "${operator_name} csv not created successfully"
      exit 1
    fi

    sleep 2
  done
}

import_configmaps_on_openshift() {
  local operators_namespace="openshift-operators"

  # create service account
  kubectl apply -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: ${RELEASE}-import-configmaps-sa
  namespace: ${operators_namespace}
EOF

  # create role
  kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: ${RELEASE}-import-configmaps-role
  namespace: ${operators_namespace}
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

  # create rolebinding
  kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: ${RELEASE}-import-configmaps-rolebinding
  namespace: ${operators_namespace}
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: ${RELEASE}-import-configmaps-role
subjects:
- kind: ServiceAccount
  name: ${RELEASE}-import-configmaps-sa
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

  # while job status is not Completed, keep checking
  count=0
  while true; do
    job_phase=$(kubectl get job -n ${operators_namespace} ${RELEASE}-import-configmaps -ojsonpath='{.status.succeeded}')
    if [ "$job_phase" == "1" ]; then
      echo "import-configmaps job created successfully"
      break
    fi

    ((count++))
    if [[ $count -gt $TIME_OUT_SECOND ]]; then
      echo "import-configmaps job not created successfully"
      exit 1
    fi

    sleep 2
  done
}

install_upm_engine_on_openshift() {
  # install tesseract-cube-operator
  add_operator_on_openshift tesseract-cube ${TESSERACT_CUBE_VERSION}

  # install kauntlet-operator
  add_operator_on_openshift kauntlet ${KAUNTLET_VERSION}

  # import configmaps
  import_configmaps_on_openshift
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
    --timeout "${TIME_OUT_SECOND}s" \
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
    --timeout "${TIME_OUT_SECOND}s" \
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

main
