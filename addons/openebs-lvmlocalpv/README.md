# 部署 openebs-lvmlocalpv

本文档目标是指导安装基于LVM本地持久化卷目录动态供应程序 [openebs/openebs-lvmlocalpv](https://github.com/openebs/lvm-localpv/tree/develop/deploy/helm/charts) ，为工作负载节点的有状态服务提供持久化存储。

## 快速安装指南

### 1. 创建VolumeGroup

**注意⚠️：每个数据节点都必须保证VolumeGroup 存在，才能部署 openebs-lvmlocalpv。**

在LVM PV的工作节点，创建对应与VG_NAME同名的VolumeGroup，用于供应Storageclass的本地PV资源。

**dev_name 是磁盘设备名称，例如 /dev/sdb。**

```console
# BASH
vgcreate local_HDD_VG {dev_name}
```

### 2. 设置必要的环境变量

OPENEBS_CONTROLLER_NODE_NAMES：指定安装controller pod的节点名称，节点名称可以使用","作为分隔符，表示多个节点名称，安装程序会对节点进行label固定安装节点。

OPENEBS_DATA_NODE_NAMES：指定LVM PV的工作负载节点名称，节点名称可以使用","作为分隔符，表示多个节点名称，安装程序会对节点进行label固定安装节点。

OPENEBS_STORAGECLASS_NAME：指定Storageclass名称。

OPENEBS_VG_NAME：指定Storageclass对应的VolumeGroup名称。

```console
export OPENEBS_CONTROLLER_NODE_NAMES="openebs-control-plan01"
export OPENEBS_DATA_NODE_NAMES="openebs-control-plan01,kube-node01,kube-node02,kube-node03"
export OPENEBS_STORAGECLASS_NAME="openebs-lvmsc-hdd"
export OPENEBS_VG_NAME="local_HDD_VG"
```

### 3. 运行安装脚本

**注意⚠️：如果找不到 Helm3，将自动安装。**

**注意⚠️：安装脚本会对指定节点进行添加label的操作。**

运行安装脚本
```console
# BASH
curl -sSL https://raw.githubusercontent.com/upmio/infini-scale-install/main/addons/openebs-lvmlocalpv/install_el7.sh | sh -
```

等几分钟。 如果所有 openebs-lvmlocalpv  pod 都在运行，则 openebs-lvmlocalpv 将成功安装。

```console
kubectl get --namespace openebs pods -w
```

## 使用 Helm 卸载 Charts

```console
# Helm
helm uninstall openebs-lvmlocalpv --namespace openebs
```

这将删除与 Charts 关联的所有 Kubernetes 组件并删除发布。

_请参阅 [helm uninstall](https://helm.sh/docs/helm/helm_uninstall/) 获取命令文档。_

## License

<!-- Keep full URL links to repo files because this README syncs from main to gh-pages.  -->
[Apache 2.0 License](https://raw.githubusercontent.com/upmio/infini-scale-install/main/LICENSE).
