# Vayne
[![Build Status](https://travis-ci.org/mon-suit/vayne_core.svg?branch=master)](https://travis-ci.org/mon-suit/vayne_core)
[![Coverage Status](https://coveralls.io/repos/github/mon-suit/vayne_core/badge.svg?branch=master)](https://coveralls.io/github/mon-suit/vayne_core?branch=master)

通用的Metrics采集框架, 有如下特点:
* 通用的采集以及输出插件([可用的采集插件](#采集插件), [可用的输出插件](#输出插件))
* 多节点支持: 避免单机故障以及性能瓶颈
* GUI查看运行情况包括: 运行任务，错误信息等
* 易于与现有监控系统结合([如何与OpenFalcon合作进行监控](How-to-work-with-openfalcon.md))

图

### Usage

### Plugin

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
