# 部署 nacos

本文档目标是指导安装微服务管理平台 [nacos](https://github.com/alibaba/nacos) ，Nacos 提供了一组简单易用的特性集，帮助您快速实现动态服务发现、服务配置、服务元数据及流量管理。

## 快速安装指南

nacos helm chart 版本为2.1.4

## 内置数据库-快速安装 nacos

### 1. 设置必要的环境变量

NACOS_CONTROLLER_NODE_NAMES：指定安装controller pod的节点名称，节点名称可以使用","作为分隔符，表示多个节点名称，安装程序会对节点进行label固定安装节点。

NACOS_STORAGECLASS_NAME：指定Storageclass名称。

NACOS_MYSQL_NODE_NAME：指定MySQL节点名称，节点名称可以使用","作为分隔符，表示多个节点名称，安装程序会对节点进行label固定安装节点。

NACOS_NAMESPACE：指定安装命名空间，非必填项，默认值为nacos。

```console
export NACOS_CONTROLLER_NODE_NAMES="nacos-control-plan01"
export NACOS_STORAGECLASS_NAME="openebs-lvmsc-hdd"
export NACOS_MYSQL_NODE_NAME="nacos-control-plan01"
```

### 2. 运行安装脚本

**注意⚠️：如果找不到 Helm3，将自动安装。**

**注意⚠️：安装脚本会对指定节点进行添加label的操作。**

运行安装脚本
```console
# BASH
curl -sSL https://raw.githubusercontent.com/upmio/upm-deploy/main/addons/nacos/install_internal_storage_el7.sh | sh -
```

等几分钟。 如果所有 nacos pod 都在运行，则 nacos 将成功安装。

```console
kubectl get --namespace nacos pods -w
```

## 使用 Helm 卸载 Charts

```console
# Helm
helm uninstall nacos -n nacos

# clean pvc
kubectl delete pvc -n nacos data-nacos-mysql-0
kubectl delete pvc -n nacos data-storage-nacos-0
```

这将删除与 Charts 关联的所有 Kubernetes 组件并删除发布。

## 外置数据库-快速安装 nacos

### 1. 设置必要的环境变量

NACOS_CONTROLLER_NODE_NAMES：指定安装controller pod的节点名称，节点名称可以使用","作为分隔符，表示多个节点名称，安装程序会对节点进行label固定安装节点。

NACOS_STORAGECLASS_NAME：指定Storageclass名称。

NACOS_MYSQL_HOST：指定MySQL服务链接地址。

NACOS_MYSQL_PORT：指定MySQL服务端口。

NACOS_MYSQL_USER：指定MySQL服务用户。

NACOS_MYSQL_PWD：指定MySQL服务用户密码。

NACOS_NAMESPACE：指定安装命名空间，非必填项，默认值为nacos。

```console
export NACOS_CONTROLLER_NODE_NAMES="nacos-control-plan01"
export NACOS_STORAGECLASS_NAME="openebs-lvmsc-hdd"
export NACOS_MYSQL_HOST="mysql"
export NACOS_MYSQL_PORT="3306"
export NACOS_MYSQL_USER="nacos"
export NACOS_MYSQL_PWD="password"
```

### 2. 运行安装脚本

**注意⚠️：如果找不到 Helm3，将自动安装。**

**注意⚠️：安装脚本会对指定节点进行添加label的操作。**

运行安装脚本
```console
# BASH
curl -sSL https://raw.githubusercontent.com/upmio/upm-deploy/main/addons/nacos/install_external_storage_el7.sh | sh -
```

等几分钟。 如果所有 nacos pod 都在运行，则 nacos 将成功安装。

```console
kubectl get --namespace nacos pods -w
```

## 使用 Helm 卸载 Charts

```console
# Helm
helm uninstall nacos -n nacos

# clean pvc
kubectl delete pvc -n nacos data-storage-nacos-0
```

这将删除与 Charts 关联的所有 Kubernetes 组件并删除发布。

_请参阅 [helm uninstall](https://helm.sh/docs/helm/helm_uninstall/) 获取命令文档。_

## License

<!-- Keep full URL links to repo files because this README syncs from main to gh-pages.  -->
[Apache 2.0 License](https://raw.githubusercontent.com/upmio/upm-deploy/main/LICENSE).
