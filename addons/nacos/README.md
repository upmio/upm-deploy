# 部署 nacos

本文档目标是指导安装微服务管理平台 [nacos](https://github.com/alibaba/nacos) ，Nacos 提供了一组简单易用的特性集，帮助您快速实现动态服务发现、服务配置、服务元数据及流量管理。

## 快速安装指南

nacos helm chart 版本为`2.1.7`

## 外置数据库-快速安装 nacos

### 1. 设置必要的环境变量

NACOS_NODE_NAMES：指定安装controller pod的节点名称，节点名称可以使用","作为分隔符，表示多个节点名称，安装程序会对节点进行label固定安装节点。

NACOS_STORAGECLASS_NAME：指定Storageclass名称。

NACOS_MYSQL_HOST：外置MySQL数据库主机地址。

NACOS_MYSQL_PORT：外置MySQL数据库端口。

NACOS_MYSQL_USER：外置MySQL数据库登录用户名。

NACOS_MYSQL_PWD：外置MySQL数据库登录密码。

NACOS_KUBE_NAMESPACE：指定安装kubernetes的命名空间，非必填项，默认值为`nacos`。

NACOS_NAMESPACE: 指定nacos的命名空间，当值为非空时，将在nacos中创建命名空间，非必填项，默认值为空。

```console
export NACOS_NODE_NAMES="nacos-control-plan01"
export NACOS_STORAGECLASS_NAME="openebs-lvmsc-hdd"
export NACOS_MYSQL_HOST="mysql"
export NACOS_MYSQL_PORT="3306"
export NACOS_MYSQL_USER="nacos"
export NACOS_MYSQL_PWD="password"
export NACOS_NAMESPACE="upm-system"
```

### 2. 运行安装脚本

**注意⚠️：如果找不到 Helm3，将自动安装。**

**注意⚠️：安装脚本会对指定节点进行添加label的操作。**

运行安装脚本
```console
# BASH
curl -sSL https://raw.githubusercontent.com/upmio/upm-deploy/main/addons/nacos/install_el7.sh | sh -
```

等几分钟。 如果所有 nacos pod 都在运行，则 nacos 将成功安装。

```console
kubectl get -n nacos pods -w
```

**注意⚠️：安装完成后nacos页面登陆用户名为 `nacos` 登陆密码为 `nacos`。**

## 使用 Helm 卸载 Charts

```console
# Helm
helm uninstall nacos -n nacos

# clean pvc
kubectl delete pvc -n nacos data-storage-nacos-0
```

这将删除与 Charts 关联的所有 Kubernetes 组件并删除发布。

_请参阅 [helm uninstall](https://helm.sh/docs/helm/helm_uninstall/) 获取命令文档。_
