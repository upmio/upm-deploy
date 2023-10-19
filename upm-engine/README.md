# 部署 upm-engine

本文档目标是指导upm平台的执行端程序。

## 快速安装指南

### 1. 设置必要的环境变量

ENGINE_NODE_NAMES：指定安装upm engine pod的节点名称，节点名称可以使用","作为分隔符，表示多个节点名称，安装程序会对节点进行label固定安装节点。

ENGINE_KUBE_NAMESPACE：指定安装命名空间，非必填项，默认值为`upm-system`。

```console
export ENGINE_NODE_NAMES="master01,master02"
```

### 2. 运行安装脚本

**注意⚠️：如果找不到 Helm3，将自动安装。**

运行安装脚本
```console
# BASH
curl -sSL https://raw.githubusercontent.com/upmio/upm-deploy/main/upm-engine/install_el7.sh | sh -
```

等几分钟。 如果所有 upm-engine  pod 都在运行，则 upm-engine 将成功安装。

```console
kubectl get -n upm-system pods -w
```

## 使用 Helm 卸载 Charts

```console
# Helm
helm uninstall -n upm-system upm-engine 
```

这将删除与 Charts 关联的所有 Kubernetes 组件并删除发布。

_请参阅 [helm uninstall](https://helm.sh/docs/helm/helm_uninstall/) 获取命令文档。_

## License

<!-- Keep full URL links to repo files because this README syncs from main to gh-pages.  -->
[Apache 2.0 License](https://raw.githubusercontent.com/upmio/upm-deploy/main/LICENSE).
