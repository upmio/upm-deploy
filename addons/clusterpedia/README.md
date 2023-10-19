# 部署 clusterpedia

本文档目标是指导安装多集群管理程序 [clusterpedia](https://github.com/clusterpedia-io/clusterpedia) 。

## 外置数据库-快速安装 clusterpedia 

### 1. 确定登录kubernetes 

使用 kubectl 确定目前连接的集群信息。

```console
kubectl cluster-info
```

### 2. 设置必要的环境变量

CLUSTERPEDIA_CONTROLLER_NODE_NAMES：指定安装 clusterpedia-controller pod的节点名称，节点名称可以使用","作为分隔符，表示多个节点名称，安装程序会对节点进行label固定安装节点。

CLUSTERPEDIA_WORKER_NODE_NAMES：指定安装 clusterpedia-worker pod的节点名称，节点名称可以使用","作为分隔符，表示多个节点名称，安装程序会对节点进行label固定安装节点。

CLUSTERPEDIA_MYSQL_HOST：外置MySQL数据库主机地址。

CLUSTERPEDIA_MYSQL_PORT：外置MySQL数据库端口。

CLUSTERPEDIA_MYSQL_USER：外置MySQL数据库登录用户名。

CLUSTERPEDIA_MYSQL_PASSWORD：外置MySQL数据库登录密码。

CLUSTERPEDIA_KUBE_NAMESPACE：指定安装命名空间，非必填项，默认值为`clusterpedia`。

```console
export CLUSTERPEDIA_CONTROLLER_NODE_NAMES="clusterpedia-control-plan01"
export CLUSTERPEDIA_WORKER_NODE_NAMES="clusterpedia-control-plan01"
export CLUSTERPEDIA_MYSQL_HOST="mysql"
export CLUSTERPEDIA_MYSQL_PORT="3306"
export CLUSTERPEDIA_MYSQL_USER="clusterpedia"
export CLUSTERPEDIA_MYSQL_PASSWORD="password"
```

### 3. 运行安装脚本

**注意⚠️：如果找不到 Helm3，将自动安装。**

**注意⚠️：安装脚本会对指定节点进行添加label的操作。**

运行安装脚本
```console
# BASH
curl -sSL https://raw.githubusercontent.com/upmio/upm-deploy/main/addons/clusterpedia/install_external_storage_el7.sh | sh -
```

等待几分钟。 如果所有 clusterpedia pod 都在运行，则 clusterpedia 将成功安装。

```console
kubectl get pods -n clusterpedia  -w
```

## 内置数据库-快速安装 clusterpedia

### 1. 确定登录kubernetes

使用 kubectl 确定目前连接的集群信息。

```console
kubectl cluster-info
```

### 2. 设置必要的环境变量

CLUSTERPEDIA_CONTROLLER_NODE_NAMES：指定安装 clusterpedia-controller pod的节点名称，节点名称可以使用","作为分隔符，表示多个节点名称，安装程序会对节点进行label固定安装节点。

CLUSTERPEDIA_WORKER_NODE_NAMES：指定安装 clusterpedia-worker pod的节点名称，节点名称可以使用","作为分隔符，表示多个节点名称，安装程序会对节点进行label固定安装节点。

CLUSTERPEDIA_MYSQL_PASSWORD：内置MySQL数据库登录密码。

CLUSTERPEDIA_MYSQL_NODE：内置MySQL数据库部署节点名称。

CLUSTERPEDIA_KUBE_NAMESPACE：指定安装命名空间，非必填项，默认值为`clusterpedia`。

```console
export CLUSTERPEDIA_CONTROLLER_NODE_NAMES="clusterpedia-control-plan01"
export CLUSTERPEDIA_WORKER_NODE_NAMES="clusterpedia-control-plan01"
export CLUSTERPEDIA_MYSQL_PASSWORD="password"
export CLUSTERPEDIA_MYSQL_NODE="mysql01"
```

### 3. 运行安装脚本

**注意⚠️：如果找不到 Helm3，将自动安装。**

**注意⚠️：安装脚本会对指定节点进行添加label的操作。**

运行安装脚本
```console
# BASH
curl -sSL https://raw.githubusercontent.com/upmio/upm-deploy/main/addons/clusterpedia/install_internal_storage_el7.sh | sh -
```

等待几分钟。 如果所有 clusterpedia pod 都在运行，则 clusterpedia 将成功安装。

```console
kubectl get -n clusterpedia pods -w
```

## 使用 Helm 卸载 clusterpedia

```console
# Helm
helm uninstall clusterpedia -n clusterpedia
# clean pvc
kubectl delete pvc -n clusterpedia data-clusterpedia-mysql-0
```

这将删除与 Charts 关联的所有 Kubernetes 组件并删除发布。

_请参阅 [helm uninstall](https://helm.sh/docs/helm/helm_uninstall/) 获取命令文档。_

## 导入集群

Clusterpedia 使用自定义资源 PediaCluster 资源来代表接入的集群

用户使用 kubeconfig 方式来配置接入的集群。 通过直接配置 base64 编码的 kubeconfig 到 `kubeconfig` 字段用于集群连接和验证

首先需要将接入集群的 kubeconfig base64 编码。
```bash
# mac
base64 ~/.kube/config

# linux
base64 -w 0 ~/.kube/config
```

将 base64 后的内容设置到 PediaCluster 的 spec.kubeconfig 中即可，并且手动额外配置 spec.apiserver 字段，其他验证字段都不需要填写。

[管理集群 spec 样例文件](https://raw.githubusercontent.com/upmio/upm-deploy/main/addons/clusterpedia/yaml/example/manager-cluster.yaml)
[工作负载集群 spec 样例文件](https://raw.githubusercontent.com/upmio/upm-deploy/main/addons/clusterpedia/yaml/example/workload-cluster.yaml)
