# Vayne
[![Build Status](https://travis-ci.org/mon-suit/vayne_core.svg?branch=master)](https://travis-ci.org/mon-suit/vayne_core)
[![Coverage Status](https://coveralls.io/repos/github/mon-suit/vayne_core/badge.svg?branch=master)](https://coveralls.io/github/mon-suit/vayne_core?branch=master)

[中文](README-zh.md)

Common framework for collecting and reporting metrics, with features:
* Many `metric` plugins and `export` plugins support.
* Multi node support: avoid performance bottlenecks and single point of failure.
* UI dashboard to display stats: running tasks, error messages.
* Easy to work together with monitor system you are using now. ([How to work with OpenFalcon](How-to-work-with-openfalcon.md))


### Plugin

#### Metric Plugin

* Http
* Mysql
* Memcache
* Mongodb
* Redis

Cloud service metrics:
* Aws(Rds, Elasticache, Elb)
* Tencent Cloud(腾讯云)(CDB, CMongo, Redis)
* KS Cloud(金山云)(KRDS, KCS)
* Alibaba Cloud(阿里云)(Rds, Redis)

#### Export Plugin
* Console
* OpenFalcon
