# 部署 Redis 单机版

本文档目标是指导安装 Redis 单机版，Redis 版本为 7.2.5。

## 快速安装指南

redis helm chart版本为`19.6.4`

### 1. 设置环境变量

* REDIS_PWD：**必填项**，登录 Redis 登录密码。
* REDIS_NODE_NAMES：**必填项**，指定安装 Redis 的 kubernetes 节点名称，多个节点名称可以使用 `,` 作为分隔符，会对指定的节点进行 label 设置添加`redis.standalone.node=true`标签。
* REDIS_PORT：**非必填项**，指定安装 Redis 端口，默认值为`6379`。
* REDIS_KUBE_NAMESPACE：**非必填项**，指定安装命名空间，默认值为`default`。
* REDIS_SERVICE_TYPE：**非必填项**，指定服务入口类型，支持 `ClusterIP` 、`NodePort` ，默认值为`ClusterIP`。
* REDIS_RESOURCE_LIMITS：**非必填项**，设置 Redis 服务的 CPU 和内存限制，值范围：0-64，`0`表示不限制，大于`0`表示对应内存的大小（单位 Gi ），CPU 数量自动计算，默认值为`1`。

#### 设置环境变量样例如下：
```console
export REDIS_PWD='password'
export REDIS_NODE_NAMES="redis-node01"
export REDIS_KUBE_NAMESPACE="upm-system"
export REDIS_RESOURCE_LIMITS=0
```

### 3. 执行安装脚本

**注意⚠️：如果找不到 Helm3，将自动安装。**

**注意⚠️：安装脚本会对 `REDIS_NODE_NAMES` 节点进行设置 `label` 的操作。**

运行安装脚本：
```console
# BASH
curl -sSL https://raw.githubusercontent.com/upmio/upm-deploy/main/addons/redis-standalone/install_el7.sh | sh -
```

⌛️等待几分钟，可用以下命令查看安装状态：

```console
export REDIS_KUBE_NAMESPACE="upm-system"
kubectl get --namespace ${REDIS_KUBE_NAMESPACE} pods -w
```
若 Redis pod 在运行即 READY [1/1] ，则安装成功。

## 使用 Helm 卸载

```console
# Helm
export REDIS_KUBE_NAMESPACE="upm-system"
helm uninstall --namespace ${REDIS_KUBE_NAMESPACE} redis
```

这将删除与 Charts 关联的所有 Kubernetes 组件并删除发布。

_请参阅 [helm uninstall](https://helm.sh/docs/helm/helm_uninstall/) 获取命令文档。_