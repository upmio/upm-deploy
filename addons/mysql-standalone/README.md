# 部署 MySQL 单机版

本文档目标是指导安装 MySQL 单机版, MySQL版本为8.0.34。

## 快速安装指南

### 1. 设置必要的环境变量

MYSQL_PWD：指定 MySQL 管理员用户密码。

MYSQL_USER_NAME：登录 MySQL 用户名。

MYSQL_USER_PWD：登录 MySQL 用户密码。

MYSQL_STORAGECLASS_NAME：指定Storageclass名称, 使用 ```kubectl get storageclasses ```获取可用的 Storageclass 名称。

MYSQL_PVC_SIZE_G：指定持久化卷的大小，单位为Gi。

MYSQL_NODE_NAMES：指定安装 MySQL pod 的节点名称，节点名称可以使用","作为分隔符，表示多个节点名称，安装程序会对节点进行label固定安装节点。

MYSQL_PORT：指定安装 MySQL 端口，非必填项，默认值为3306。

MYSQL_NAMESPACE：指定安装命名空间，非必填项，默认值为default。

```console
export MYSQL_PWD='password'
export MYSQL_USER_NAME="admin"
export MYSQL_USER_PWD='password'
export MYSQL_STORAGECLASS_NAME="openebs-lvmsc-hdd"
export MYSQL_PVC_SIZE_G="50"
export MYSQL_NODE_NAMES="db-node01"
```

### 3. 运行安装脚本

**注意⚠️：如果找不到 Helm3，将自动安装。**

**注意⚠️：安装脚本会对指定 MySQL pod 的节点进行添加label的操作，标签为 ```mysql.standalone.node=enable```。**

运行安装脚本
```console
# BASH
curl -sSL https://raw.githubusercontent.com/upmio/upm-deploy/main/addons/mysql-standalone/install_el7.sh | sh -
```

等几分钟。 如果所有 mysql pod 都在运行，则 mysql 将成功安装。

```console
kubectl get --namespace default pods -w
```

## 使用 Helm 卸载 Charts

```console
# Helm
helm uninstall -n default mysql
```

这将删除与 Charts 关联的所有 Kubernetes 组件并删除发布。

_请参阅 [helm uninstall](https://helm.sh/docs/helm/helm_uninstall/) 获取命令文档。_

## License

<!-- Keep full URL links to repo files because this README syncs from main to gh-pages.  -->
[Apache 2.0 License](https://raw.githubusercontent.com/upmio/upm-deploy/main/LICENSE).