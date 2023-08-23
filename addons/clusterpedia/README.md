# 部署 clusterpedia

本文档目标是指导安装多集群管理程序 [clusterpedia](https://github.com/clusterpedia-io/clusterpedia) 。

## 外置数据库-快速安装 clusterpedia 

### 1. 确定登录kubernetes 

使用 kubectl 确定目前连接的集群是 Parent Cluster。

```console
kubectl cluster-info
```

### 2. 设置必要的环境变量

CLUSTERPEDIA_CONTROLLER_NODE_NAMES：指定安装 clusterpedia-controller pod的节点名称，节点名称可以使用","作为分隔符，表示多个节点名称，安装程序会对节点进行label固定安装节点。

CLUSTERPEDIA_WORKER_NODE_NAMES：指定安装 clusterpedia-worker pod的节点名称，节点名称可以使用","作为分隔符，表示多个节点名称，安装程序会对节点进行label固定安装节点。

CLUSTERPEDIA_MYSQL_HOST：外置数据库登录 MySQL 用户名。

CLUSTERPEDIA_MYSQL_PORT：外置数据库登录 MySQL 端口。

CLUSTERPEDIA_MYSQL_USER：外置数据库登录 MySQL 用户名。

CLUSTERPEDIA_MYSQL_PASSWORD：外置数据库登录 MySQL 密码。

```console
export CLUSTERPEDIA_CONTROLLER_NODE_NAMES="clusterpedia-control-plan01"
export CLUSTERPEDIA_WORKER_NODE_NAMES="clusterpedia-control-plan01"
export CLUSTERPEDIA_MYSQL_HOST="mysql01-mysql"
export CLUSTERPEDIA_MYSQL_PORT="3306"
export CLUSTERPEDIA_MYSQL_USER="admin"
export CLUSTERPEDIA_MYSQL_PASSWORD="password"
```

### 3. 运行安装脚本

**注意⚠️：如果找不到 Helm3，将自动安装。**

**注意⚠️：安装脚本会对指定节点进行添加label的操作。**

运行安装脚本
```console
# BASH
curl -sSL https://raw.githubusercontent.com/upmio/infini-scale-install/main/addons/clusterpedia/install_external_storage_el7.sh | sh -
```

等待几分钟。 如果所有 clusterpedia pod 都在运行，则 clusterpedia 将成功安装。

```console
kubectl get --namespace clusterpedia-system pods -w
```

## 内置数据库-快速安装 clusterpedia

### 1. 确定登录kubernetes

使用 kubectl 确定目前连接的集群是 Child Cluster。

```console
kubectl cluster-info
```

### 2. 设置必要的环境变量

CLUSTERPEDIA_CONTROLLER_NODE_NAMES：指定安装 clusterpedia-controller pod的节点名称，节点名称可以使用","作为分隔符，表示多个节点名称，安装程序会对节点进行label固定安装节点。

CLUSTERPEDIA_WORKER_NODE_NAMES：指定安装 clusterpedia-worker pod的节点名称，节点名称可以使用","作为分隔符，表示多个节点名称，安装程序会对节点进行label固定安装节点。

CLUSTERPEDIA_MYSQL_PASSWORD：内置数据库登录 MySQL 密码。

CLUSTERPEDIA_MYSQL_NODE：内置数据库所在节点名称。

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
curl -sSL https://raw.githubusercontent.com/upmio/infini-scale-install/main/addons/clusterpedia/install_internal_storage_el7.sh | sh -
```

等待几分钟。 如果所有 clusterpedia pod 都在运行，则 clusterpedia 将成功安装。

```console
kubectl get --namespace clusterpedia-system pods -w
```

## 使用 Helm 卸载 clusterpedia

```console
# Helm
helm uninstall clusterpedia --namespace clusterpedia-system
```

这将删除与 Charts 关联的所有 Kubernetes 组件并删除发布。

_请参阅 [helm uninstall](https://helm.sh/docs/helm/helm_uninstall/) 获取命令文档。_

## License

<!-- Keep full URL links to repo files because this README syncs from main to gh-pages.  -->
[Apache 2.0 License](https://raw.githubusercontent.com/upmio/infini-scale-install/main/LICENSE).
