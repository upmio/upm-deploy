# 部署 cert-manager

本文档目标是指导安装证书管理工具 [cert-manager](https://github.com/cert-manager/cert-manager) 。

## 快速安装指南

### 1. 设置必要的环境变量

CERT_MANAGER_NODE_NAMES：指定安装cert-manager pod的节点名称，节点名称可以使用","作为分隔符，表示多个节点名称，安装程序会对节点进行label固定安装节点。

CERT_MANAGER_NAMESPACE：指定安装命名空间，非必填项，默认值为cert-manager。

```console
export CERT_MANAGER_NODE_NAMES="master01,master02"
```

### 2. 运行安装脚本

**注意⚠️：如果找不到 Helm3，将自动安装。**

运行安装脚本
```console
# BASH
curl -sSL https://raw.githubusercontent.com/upmio/upm-deploy/main/addons/cert-manager/install_el7.sh | sh -
```

等几分钟。 如果所有 cert-manager  pod 都在运行，则 cert-manager 将成功安装。

```console
kubectl get --namespace cert-manager pods -w
```

## 使用 Helm 卸载 Charts

```console
# Helm
helm uninstall --namespace cert-manager cert-manager 
```

这将删除与 Charts 关联的所有 Kubernetes 组件并删除发布。

_请参阅 [helm uninstall](https://helm.sh/docs/helm/helm_uninstall/) 获取命令文档。_

## License

<!-- Keep full URL links to repo files because this README syncs from main to gh-pages.  -->
[Apache 2.0 License](https://raw.githubusercontent.com/upmio/upm-deploy/main/LICENSE).
