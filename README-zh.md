# Vayne Core
[![Build Status](https://travis-ci.org/mon-suit/vayne_core.svg?branch=master)](https://travis-ci.org/mon-suit/vayne_core)
[![Coverage Status](https://coveralls.io/repos/github/mon-suit/vayne_core/badge.svg?branch=master)](https://coveralls.io/github/mon-suit/vayne_core?branch=master)

```
+---------+
|  Http   |
+---------+                            |
                                       |
+---------+                            |  load monitor task
|  Mysql  |                            v
+---------+                 +----------------------+
                            |   +----------+       |            +----------+
+---------+                 |   |   vayne  |       |            |OpenFalcon|
| Mongodb |                 |   +----------+       |            +----------+
+---------+     Collect     |        .             |   Export
             +----------->  |        .             | +--------->
+---------+     Metrics     |   +----------+       |
|Memcached|                 |   |   vayne  |       |            +----------+
+---------+                 |   +----------+       |            | Console  |
                            |               Cluster|            +----------+
+---------+                 +----------------------+
|  Redis  |
+---------+

+---------+
|  Other..|
+---------+
```

通用的Metrics采集框架:
* 通用的采集以及输出插件([可用的采集插件](#采集插件), [可用的输出插件](#输出插件))
* 多节点支持: 避免单机故障以及性能瓶颈
* web ui查看运行情况包括: 运行任务，错误信息等
* 易于与现有监控系统结合([如何与OpenFalcon合作进行监控](How-to-work-with-openfalcon.md))

框架仅仅包含了核心功能，实际使用需要:
0. 包含需要的监控插件
1. 加载监控任务的流程
2. Erlang Node的连接，形成集群. 可使用[libcluster]()之类的库

完整示例参考 [vayne demo](#)

## 说明

### 配置

任务可以有多个分组，每次加载任务会全量更新组内监控任务
这样不同来源的监控任务可以分开加载
```elixir
config :vayne, groups: [:groupA, :groupB]
```

任务持久化方式。默认为`Vayne.Store.File`模块。
加载任务成功后会持久化，用于服务重启后优先加载。
```elixir
config :vayne, store: Vayne.Store.File
```

错误信息默认处理模块`Vayne.Error.Ets`, 每个任务最多保存10条错误信息，保存2天。
```elixir
config :vayne, error: %{
  module: Vayne.Error.Ets,
  keep_count: 10,
  keep_time: 2 * 24 * 60 * 60 # 2 days
}
```

### 使用

参考相关插件需要的参数形成监控任务:
``` elixir
tasks = [
%Vayne.Task{
  uniqe_key:   "uniqe_key",                              #任务唯一标识，不能重复
  interval:    60,                                       #运行间隔
  metric_info: %{
    module: Vayne.Metric.Http,                           #监控插件
    params: %{"url" => "http://httpbin.org/status/200"}  #监控插件需要的参数
  },
  export_info: %{
    module: Vayne.Export.Console,                        #输出插件
    params: nil　　　　　　　　　　　　　　　　　　　　　#输出插件需要的参数
  }
}
...
]
```

加载至任务分组，同时加载进来的任务会hash一个时间间隔，避免大量任务同时运行
```elixir
Vayne.Manager.push_task(:groupA, tasks)
```

查看运行情况
```elixir
Vayne.info_tasks()
Vayne.info_tasks(group: :groupA)
Vayne.info_tasks(match: "sub string of uniqe_key")
```

查看错误信息
```elixir
Vayne.error_recently(60)    #最近60s发生的错误
```

## Plugin

#### 采集插件
* Http
* Mysql
* Memcache
* Mongodb
* Redis

云服务监控数据:
* Aws(Rds, Elasticache, Elb)
* 腾讯云(CDB, CMongo, Redis)
* 金山云(KRDS, KCS)
* 阿里云(Rds, Redis)

#### 输出插件
* Console
* OpenFalcon
