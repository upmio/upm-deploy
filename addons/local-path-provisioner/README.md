# 部署 local-path-provisioner

本文档目标是指导安装基于目录的本地持久化卷目录动态供应程序 [local-path-provisioner](https://github.com/rancher/local-path-provisioner) ，为工作负载节点的有状态服务提供持久化存储。

## 快速安装指南

local-path-provisioner helm chart版本为`0.0.30`


### 2. 设置必要的环境变量

LOCAL_PATH_CONTROLLER_NODE_NAMES：指定安装controller pod的节点名称，节点名称可以使用","作为分隔符，表示多个节点名称，安装程序会对节点进行label固定安装节点，必填项。

LOCAL_PATH_STORAGECLASS_NAME：指定Storageclass名称，必填项。

LOCAL_PATH_NODE_PATH：指定节点路径，必填项。

LOCAL_PATH_KUBE_NAMESPACE：指定安装命名空间，非必填项，默认值为`local-path-storage`。

```console
export LOCAL_PATH_CONTROLLER_NODE_NAMES="node1"
export LOCAL_PATH_STORAGECLASS_NAME="local-path"
export LOCAL_PATH_NODE_PATH="/data/local-path"
export LOCAL_PATH_KUBE_NAMESPACE="local-path-storage"
```

### 3. 运行安装脚本

**注意⚠️：如果找不到 Helm3，将自动安装。**

**注意⚠️：安装脚本会对指定节点进行添加label的操作。**

运行安装脚本
```console
# BASH
curl -sSL https://raw.githubusercontent.com/upmio/upm-deploy/v1.2/addons/local-path-provisioner/install_el7.sh | sh -
```

等几分钟。 如果所有 local-path-provisioner pod 都在运行，则 local-path-provisioner 将成功安装。

```console
kubectl get pods -n local-path-storage -w
```

## 使用 Helm 卸载 Charts

```console
# Helm
helm uninstall local-path-provisioner -n local-path-storage
```

这将删除与 Charts 关联的所有 Kubernetes 组件并删除发布。

_请参阅 [helm uninstall](https://helm.sh/docs/helm/helm_uninstall/) 获取命令文档。_

## License

<!-- Keep full URL links to repo files because this README syncs from main to gh-pages.  -->
[Apache 2.0 License](https://raw.githubusercontent.com/upmio/upm-deploy/main/LICENSE).
