#!/usr/bin/env bash

# You must be prepared as follows before run install.sh:
#
# 1. NACOS_NODE_NAMES MUST be set as environment variable, for an example:
#
#        export NACOS_NODE_NAMES="master01,master02"
#
# 2. NACOS_STORAGECLASS_NAME MUST be set as environment variable, for an example:
#
#        export NACOS_STORAGECLASS_NAME="openebs-lvmsc-hdd"
#
# 3. NACOS_MYSQL_HOST MUST be set as environment variable, for an example:
#
#        export NACOS_MYSQL_HOST="mysql"
#
# 4. NACOS_MYSQL_PORT MUST be set as environment variable, for an example:
#
#        export NACOS_MYSQL_PORT="3306"
#
# 5. NACOS_MYSQL_USER MUST be set as environment variable, for an example:
#
#        export NACOS_MYSQL_USER="nacos"
#
# 6. NACOS_MYSQL_PWD MUST be set as environment variable, for an example:
#
#        export NACOS_MYSQL_PWD="password"
#

readonly CHART="ygqygq2/nacos"
readonly RELEASE="nacos"
readonly TIME_OUT_SECOND="600s"
readonly NACOS_VERSION="v2.2.3"
readonly CHART_VERSION="2.1.4"

OFFLINE_INSTALL="${OFFLINE_INSTALL:-false}"
NACOS_PVC_SIZE_G="${NACOS_PVC_SIZE_G:-5}"
NACOS_PORT="${NACOS_PORT:-8848}"
NACOS_NODEPORT="${NACOS_NODEPORT:-32008}"
NACOS_CLIENT_PORT="$((NACOS_PORT + 1000))"
NACOS_RAFT_PORT="$((NACOS_PORT + 1001))"
NACOS_KUBE_NAMESPACE="${NACOS_KUBE_NAMESPACE:-nacos}"
NACOS_NAMESPACE="${NACOS_NAMESPACE:-}"
NACOS_SERVICE_TYPE="${NACOS_SERVICE_TYPE:-ClusterIP}"

if [[ ${NACOS_SERVICE_TYPE} == "NodePort" ]]; then
  NACOS_NODEPORT="${NACOS_NODEPORT:-32008}"
elif [[ ${NACOS_SERVICE_TYPE} == "ClusterIP" ]] || [[ ${NACOS_SERVICE_TYPE} == "LoadBalancer" ]]; then
  NACOS_NODEPORT=null
else
  error "NACOS_SERVICE_TYPE must be NodePort or ClusterIP or LoadBalancer"
fi

INSTALL_LOG_PATH=/tmp/nacos_install-$(date +'%Y-%m-%d_%H-%M-%S').log

if [[ ${NACOS_RESOURCE_LIMITS} -eq 0 ]]; then
  NACOS_RESOURCE_LIMITS_CPU="0"
  NACOS_RESOURCE_LIMITS_MEMORY="0"
  NACOS_RESOURCE_REQUESTS_CPU="0"
  NACOS_RESOURCE_REQUESTS_MEMORY="0"
elif [[ ${NACOS_RESOURCE_LIMITS} -gt 0 && ${NACOS_RESOURCE_LIMITS} -le 8 ]]; then
  NACOS_RESOURCE_LIMITS_CPU="1000m"
  NACOS_RESOURCE_LIMITS_MEMORY="${NACOS_RESOURCE_LIMITS}Gi"
  NACOS_RESOURCE_REQUESTS_CPU="1000m"
  NACOS_RESOURCE_REQUESTS_MEMORY="${NACOS_RESOURCE_LIMITS}Gi"
elif [[ ${NACOS_RESOURCE_LIMITS} -gt 8 ]]; then
  NACOS_RESOURCE_LIMITS_CPU="2000m"
  NACOS_RESOURCE_LIMITS_MEMORY="${NACOS_RESOURCE_LIMITS}Gi"
  NACOS_RESOURCE_REQUESTS_CPU="2000m"
  NACOS_RESOURCE_REQUESTS_MEMORY="${NACOS_RESOURCE_LIMITS}Gi"
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

online_install_nacos() {
  # check if nacos already installed
  if helm status ${RELEASE} -n "${NACOS_KUBE_NAMESPACE}" &>/dev/null; then
    error "${RELEASE} already installed. Use helm remove it first"
  fi

  info "Start add helm ygqygq2 repo"
  helm repo add ygqygq2 https://ygqygq2.github.io/charts/ &>/dev/null || error "Helm add nacos repo error."

  info "Start update helm nacos repo"
  helm repo update ygqygq2 2>/dev/null || error "Helm update nacos repo error."

  info "Install nacos, It might take a long time..."
  helm install ${RELEASE} ${CHART} \
    --debug \
    --version "${CHART_VERSION}" \
    --namespace "${NACOS_KUBE_NAMESPACE}" \
    --create-namespace \
    --set-string image.tag="${NACOS_VERSION}" \
    --set nodeAffinityPreset.type="hard" \
    --set nodeAffinityPreset.key="nacos\.io/control-plane" \
    --set nodeAffinityPreset.values='{enable}' \
    --set replicaCount=${NACOS_NODE_COUNT} \
    --set service.ports.http.port="${NACOS_PORT}" \
    --set service.ports.client-rpc.port="${NACOS_CLIENT_PORT}" \
    --set service.ports.raft-rpc.port="${NACOS_RAFT_PORT}" \
    --set-string resources.limits.cpu="${NACOS_RESOURCE_LIMITS_CPU}" \
    --set-string resources.limits.memory="${NACOS_RESOURCE_LIMITS_MEMORY}" \
    --set-string resources.requests.cpu="${NACOS_RESOURCE_REQUESTS_CPU}" \
    --set-string resources.requests.memory="${NACOS_RESOURCE_REQUESTS_MEMORY}" \
    --set persistence.enabled=true \
    --set-string persistence.storageClass="${NACOS_STORAGECLASS_NAME}" \
    --set-string persistence.size="${NACOS_PVC_SIZE_G}Gi" \
    --set ingress.enabled=false \
    --set-string extraEnvVars[0].name="PREFER_HOST_MODE" \
    --set-string extraEnvVars[0].value="hostname" \
    --set-string extraEnvVars[1].name="TZ" \
    --set-string extraEnvVars[1].value="Asia/Shanghai" \
    --set-string extraEnvVars[2].name="SPRING_DATASOURCE_PLATFORM" \
    --set-string extraEnvVars[2].value="mysql" \
    --set-string extraEnvVars[3].name="NACOS_AUTH_ENABLE" \
    --set-string extraEnvVars[3].value="true" \
    --set-string extraEnvVars[4].name="NACOS_AUTH_TOKEN" \
    --set-string extraEnvVars[4].value="SecretKey012345678901234567890123456789012345678901234567890123456789" \
    --set-string extraEnvVars[5].name="JAVA_OPT" \
    --set-string extraEnvVars[5].value="-Dnacos.core.auth.server.identity.key=nacos -Dnacos.core.auth.server.identity.value=nacos -Dnacos.core.auth.plugin.nacos.token.secret.key=SecretKey012345678901234567890123456789012345678901234567890123456789" \
    --set mysql.enabled=false \
    --set-string mysql.external.mysqlMasterHost="${NACOS_MYSQL_HOST}" \
    --set-string mysql.external.mysqlMasterPort="${NACOS_MYSQL_PORT}" \
    --set-string mysql.external.mysqlMasterUser="${NACOS_MYSQL_USER}" \
    --set-string mysql.external.mysqlMasterPassword="${NACOS_MYSQL_PWD}" \
    --set-string mysql.external.mysqlDatabase="nacos" \
    --set-string initDB.image.repository="dbscale/nacos-server-initdb" \
    --set-string initDB.image.tag="${NACOS_VERSION}" \
    --timeout $TIME_OUT_SECOND \
    --wait 2>&1 | grep "\[debug\]" | awk '{$1="[Helm]"; $2=""; print }' | tee -a "${INSTALL_LOG_PATH}" || {
    error "Fail to install ${RELEASE}."
  }

  #TODO: check more resources after install
}

offline_install_nacos() {
  # check if nacos already installed
  if helm status ${RELEASE} -n "${NACOS_KUBE_NAMESPACE}" &>/dev/null; then
    error "${RELEASE} already installed. Use helm remove it first"
  fi

  [[ -d "${NACOS_CHART_DIR}" ]] || error "NACOS_CHART_DIR not exist."

  info "Install nacos, It might take a long time..."
  helm install ${RELEASE} "${NACOS_CHART_DIR}" \
    --namespace "${NACOS_KUBE_NAMESPACE}" \
    --create-namespace \
    --set-string global.imageRegistry="${NACOS_IMAGE_REGISTRY}" \
    --set-string image.tag="${NACOS_VERSION}" \
    --set nodeAffinityPreset.type="hard" \
    --set nodeAffinityPreset.key="nacos\.io/control-plane" \
    --set nodeAffinityPreset.values='{enable}' \
    --set replicaCount=${NACOS_NODE_COUNT} \
    --set service.ports.http.port="${NACOS_PORT}" \
    --set service.ports.client-rpc.port="${NACOS_CLIENT_PORT}" \
    --set service.ports.raft-rpc.port="${NACOS_RAFT_PORT}" \
    --set-string resources.limits.cpu="${NACOS_RESOURCE_LIMITS_CPU}" \
    --set-string resources.limits.memory="${NACOS_RESOURCE_LIMITS_MEMORY}" \
    --set-string resources.requests.cpu="${NACOS_RESOURCE_REQUESTS_CPU}" \
    --set-string resources.requests.memory="${NACOS_RESOURCE_REQUESTS_MEMORY}" \
    --set persistence.enabled=true \
    --set-string persistence.storageClass="${NACOS_STORAGECLASS_NAME}" \
    --set-string persistence.size="${NACOS_PVC_SIZE_G}Gi" \
    --set ingress.enabled=false \
    --set-string extraEnvVars[0].name="PREFER_HOST_MODE" \
    --set-string extraEnvVars[0].value="hostname" \
    --set-string extraEnvVars[1].name="TZ" \
    --set-string extraEnvVars[1].value="Asia/Shanghai" \
    --set-string extraEnvVars[2].name="SPRING_DATASOURCE_PLATFORM" \
    --set-string extraEnvVars[2].value="mysql" \
    --set-string extraEnvVars[3].name="NACOS_AUTH_ENABLE" \
    --set-string extraEnvVars[3].value="true" \
    --set-string extraEnvVars[4].name="NACOS_AUTH_TOKEN" \
    --set-string extraEnvVars[4].value="SecretKey012345678901234567890123456789012345678901234567890123456789" \
    --set-string extraEnvVars[5].name="JAVA_OPT" \
    --set-string extraEnvVars[5].value="-Dnacos.core.auth.server.identity.key=nacos -Dnacos.core.auth.server.identity.value=nacos -Dnacos.core.auth.plugin.nacos.token.secret.key=SecretKey012345678901234567890123456789012345678901234567890123456789" \
    --set mysql.enabled=false \
    --set-string mysql.external.mysqlMasterHost="${NACOS_MYSQL_HOST}" \
    --set-string mysql.external.mysqlMasterPort="${NACOS_MYSQL_PORT}" \
    --set-string mysql.external.mysqlMasterUser="${NACOS_MYSQL_USER}" \
    --set-string mysql.external.mysqlMasterPassword="${NACOS_MYSQL_PWD}" \
    --set-string mysql.external.mysqlDatabase="nacos" \
    --set-string initDB.image.repository="dbscale/nacos-server-initdb" \
    --set-string initDB.image.tag="${NACOS_VERSION}" \
    --timeout $TIME_OUT_SECOND \
    --wait 2>&1 | tee -a "${INSTALL_LOG_PATH}" || {
    error "Fail to install ${RELEASE}."
  }

  #TODO: check more resources after install
}

verify_supported() {
  installed helm || error "helm is required"
  installed kubectl || error "kubectl is required"
  installed curl || error "curl is required"
  installed yq || error "yq is required"
  installed jq || error "jq is required"

  [[ -n "${NACOS_MYSQL_HOST}" ]] || error "NACOS_MYSQL_HOST MUST set in environment variable."
  [[ -n "${NACOS_MYSQL_PORT}" ]] || error "NACOS_MYSQL_PORT MUST set in environment variable."
  [[ -n "${NACOS_MYSQL_USER}" ]] || error "NACOS_MYSQL_USER MUST set in environment variable."
  [[ -n "${NACOS_MYSQL_PWD}" ]] || error "NACOS_MYSQL_PWD MUST set in environment variable."

  [[ -n "${NACOS_NODE_NAMES}" ]] || error "NACOS_NODE_NAMES MUST set in environment variable."

  if [[ -z "${NACOS_STORAGECLASS_NAME}" ]]; then
    error "NACOS_STORAGECLASS_NAME MUST set in environment variable."
  else
    kubectl get storageclasses "${NACOS_STORAGECLASS_NAME}" &>/dev/null || {
      error "storageclass resources not all ready, use kubectl to check reason"
    }
  fi

  local node
  local control_node_array
  IFS="," read -r -a control_node_array <<<"${NACOS_NODE_NAMES}"
  NACOS_NODE_COUNT=0
  for node in "${control_node_array[@]}"; do
    kubectl label node "${node}" 'nacos.io/control-plane=enable' --overwrite &>/dev/null || {
      error "kubectl label node ${node} 'nacos.io/control-plane=enable' failed, use kubectl to check reason"
    }
    ((NACOS_NODE_COUNT++))
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
  status=$(helm status "${RELEASE}" -n "${NACOS_KUBE_NAMESPACE}" -o yaml | yq -r '.info.status')
  [[ "${status}" == "deployed" ]] || {
    error "Helm release ${RELEASE} status is not deployed, use helm to check reason"
  }

  info "${RELEASE} Deployment Completed!"
}

create_nacos_namespace() {
  if [[ ${NACOS_SERVICE_TYPE} == "NodePort" ]]; then
    info "patch service type to NodePort..."
    kubectl patch service -n "${NACOS_KUBE_NAMESPACE}" "nacos" --type='json' -p '[{"op":"replace","path":"/spec/type","value":"NodePort"},{"op":"replace","path":"/spec/ports/1/nodePort","value":'"${NACOS_NODEPORT}"'}]' || {
      error "kubectl patch service failed !"
    }
    sleep 6
    local svc_addr
    svc_addr=$(kubectl get node -l 'node-role.kubernetes.io/control-plane=' --no-headers -o jsonpath='{.items[0].status.addresses[0].address}')
    local svc_port="${NACOS_NODEPORT}"
    # waiting for service started
  elif [[ ${NACOS_SERVICE_TYPE} == "LoadBalancer" ]]; then
    info "patch service type to LoadBalancer..."
    kubectl patch service -n "${NACOS_KUBE_NAMESPACE}" "nacos" --type='json' -p '[{"op":"replace","path":"/spec/type","value":"LoadBalancer"}]' || {
      error "kubectl patch service failed !"
    }
    # waiting for service started
    sleep 20
    local svc_addr
    svc_addr=$(kubectl get svc -n "${NACOS_KUBE_NAMESPACE}" "nacos" -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
    local svc_port="${NACOS_PORT}"
  fi

  info "create nacos namespace..."
  local nacos_username="nacos"
  local nacos_password="nacos"
  # get token
  local token
  token="$(curl --noproxy '*' -s -X POST -d 'username='"${nacos_username}"'&password='"${nacos_password}"'' --url "http://${svc_addr}:${svc_port}/nacos/v1/auth/login" | jq -r .accessToken)"
  [[ -n $token ]] || error "get env token failed !"

  curl --noproxy '*' -X POST -d 'accessToken='"${token}"'' 'http://'"${svc_addr}":"${svc_port}"'/nacos/v1/console/namespaces?customNamespaceId='"${NACOS_NAMESPACE}"'&namespaceName='"${NACOS_NAMESPACE}"'&namespaceDesc='"${NACOS_NAMESPACE}"'' || {
    error "create nacos namespace failed !"
  }

  info "create nacos namespace successful!"
}

main() {
  init_log
  verify_supported
  if [[ ${OFFLINE_INSTALL} == "false" ]]; then
    online_install_nacos
  elif [[ ${OFFLINE_INSTALL} == "true" ]]; then
    offline_install_nacos
  fi
  verify_installed
  if [[ -n ${NACOS_NAMESPACE} ]]; then
    create_nacos_namespace
  fi
}

main
