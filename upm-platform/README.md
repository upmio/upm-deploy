# 部署 upm-platform

本文档目标是指导upm平台的管理端程序。

## 快速安装指南

### 1. 设置必要的环境变量

PLATFORM_NODE_NAMES：指定安装upm平台组件 pod的节点名称，节点名称可以使用","作为分隔符，表示多个节点名称，安装程序会对节点进行label固定安装节点。

PLATFORM_MYSQL_HOST：外置MySQL数据库主机地址。

PLATFORM_MYSQL_PORT：外置MySQL数据库端口。

PLATFORM_MYSQL_USER：外置MySQL数据库登录用户名。

PLATFORM_MYSQL_PWD：外置MySQL数据库登录密码。

PLATFORM_NACOS_HOST：外置nacos平台主机地址。

PLATFORM_NACOS_PORT：外置nacos平台端口。

PLATFORM_NACOS_USER：外置nacos平台登陆用户名。

PLATFORM_NACOS_PWD：外置nacos平台登陆密码。

PLATFORM_REDIS_HOST：外置Redis主机地址。

PLATFORM_REDIS_PORT：外置Redis端口。

PLATFORM_REDIS_PWD：外置Redis登录密码。

PLATFORM_CLUSTERPEDIA_KUBECONF_YAML：链接clusterpedia kubeconfig yaml 文件路径。

PLATFORM_SERVICE_TYPE：指定服务入口类型，支持 `ClusterIP` 、`NodePort` ，非必填项，默认值为`ClusterIP`。

PLATFORM_KUBE_NAMESPACE：指定安装命名空间，非必填项，默认值为`upm-system`。

```console
export PLATFORM_NODE_NAMES="master01,master02"
export PLATFORM_MYSQL_HOST="mysql"
export PLATFORM_MYSQL_PORT=3306
export PLATFORM_MYSQL_USER="upm"
export PLATFORM_MYSQL_PWD="password"
export PLATFORM_NACOS_HOST="nacos.nacos"
export PLATFORM_NACOS_PORT=8848
export PLATFORM_NACOS_USER="nacos"
export PLATFORM_NACOS_PWD="nacos"
export PLATFORM_REDIS_HOST="redis-master"
export PLATFORM_REDIS_PORT=6379
export PLATFORM_REDIS_PWD="password"
export PLATFORM_CLUSTERPEDIA_KUBECONF_YAML="/tmp/kubeconfig"
```

### 2. 运行安装脚本

**注意⚠️：如果找不到 Helm3，将自动安装。**

运行安装脚本
```console
# BASH
curl -sSL https://raw.githubusercontent.com/upmio/upm-deploy/main/upm-platform/install_el7.sh | sh -
```

等几分钟。 如果所有 upm-platform  pod 都在运行，则 upm-platform 将成功安装。

```console
kubectl get -n upm-system pods -w
```

## 使用 Helm 卸载 Charts

```console
# Helm
helm uninstall -n upm-system upm-platform 
```

这将删除与 Charts 关联的所有 Kubernetes 组件并删除发布。

_请参阅 [helm uninstall](https://helm.sh/docs/helm/helm_uninstall/) 获取命令文档。_

## License

<!-- Keep full URL links to repo files because this README syncs from main to gh-pages.  -->
[Apache 2.0 License](https://raw.githubusercontent.com/upmio/upm-deploy/main/LICENSE).
