# 部署 upm

本文档目标是指导部署 upm 。

## 快速安装指南

### 1. 部署 cert-manager

**注意⚠️：cert-manager 是被依赖的服务，必须在安装 upm 前完成 cert-manager 部署。**

部署方法请使用[cert-manger 部署](https://github.com/upmio/upm-install/tree/main/addons/cert-manager)

### 2. 部署 MySQL

**注意⚠️：MySQL 是被依赖的服务，必须在安装 upm 前完成 MySQL 部署。**

部署方法请使用[MySQL 部署](https://github.com/upmio/upm-install/tree/main/addons/mysql)

设置必要的环境变量

DB_USER：指定 MySQL 数据库用户名。

DB_PWD：指定 MySQL 数据库密码。

DB_HOST：指定 MySQL 数据库主机地址。


```console
export DB_USER="admin"
export DB_PWD="password"
export DB_HOST="mysql-0.mysql"
```

### 5. 运行安装脚本

**注意⚠️：如果找不到 Helm3，将自动安装。**

**注意⚠️：安装脚本会对指定节点进行添加label的操作。**

运行安装脚本
这将删除与 Charts 关联的所有 Kubernetes 组件并删除发布。

_请参阅 [helm uninstall](https://helm.sh/docs/helm/helm_uninstall/) 获取命令文档。_

## License

<!-- Keep full URL links to repo files because this README syncs from main to gh-pages.  -->
[Apache 2.0 License](https://raw.githubusercontent.com/upmio/upm-deploy/main/LICENSE).
