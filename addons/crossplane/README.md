# 部署 crossplane

本文档目标是指导安装crossplane, 一个构建云原生控制平面的框架。 [crossplane](https://github.com/crossplane/crossplane) 。

## 外置数据库-快速安装 crossplane 

### 1. 确定登录kubernetes 

使用 kubectl 确定目前连接的集群信息。

```console
kubectl cluster-info
```

### 2. 设置必要的环境变量

CROSSPLANE_NODE_NAMES：指定安装 crossplane-controller pod的节点名称，节点名称可以使用","作为分隔符，表示多个节点名称，安装程序会对节点进行label固定安装节点。

CROSSPLANE_KUBE_NAMESPACE：指定安装命名空间，非必填项，默认值为`crossplane-system`。
```console
export CROSSPLANE_NODE_NAMES="crossplane-control-plan01"
```

### 3. 运行安装脚本

**注意⚠️：如果找不到 Helm3，将自动安装。**

**注意⚠️：安装脚本会对指定节点进行添加label的操作。**

运行安装脚本
```console
# BASH
curl -sSL https://raw.githubusercontent.com/upmio/upm-deploy/main/addons/crossplane/install_el7.sh | sh -
```

等待几分钟。 如果所有 crossplane pod 都在运行，则 crossplane 将成功安装。

```console
kubectl get pods -n crossplane-system  -w
```

## 使用 Helm 卸载 crossplane

```console
# Helm
helm uninstall crossplane -n crossplane-system
```

这将删除与 Charts 关联的所有 Kubernetes 组件并删除发布。

_请参阅 [helm uninstall](https://helm.sh/docs/helm/helm_uninstall/) 获取命令文档。_
