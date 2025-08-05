# bny.php

💕 Bny.php 一 个 简 易 的 PHP 管 理 工 具

💕 集 成 各 种 便 捷 工 具 方 便 开 发

💕 大 部 分 编 程 功 能 都 是 PHP 本 身 不 用 担 心 要 逃 离 舒 适 圈

- 编译cli项目 编译为单个可执行文件(方便分发)
- 运行FPM项目 使用cli模式运行FPM项目
- php版本管理 可以安装多个php版本,并在项目中切换使用

```sh
    __                        __
   / /_  ____  __  __  ____  / /_  ____
  / __ \/ __ \/ / / / / __ \/ __ \/ __ \
 / /_/ / / / / /_/ / / /_/ / / / / /_/ /
/_.___/_/ /_/\__, (_) .___/_/ /_/ .___/
            /____/ /_/         /_/

Bny: v0.0.1 PHP: 已安装 Composer: 已安装 2025-07-19 09:50:12

用法:
  bny <指令> [参数] [选项]


指令:
  worker                运行FPM项目
  php                   运行PHP
  composer              运行Composer
  compile               编译项目
  add                   添加/选择php版本
  search                搜索php版本
  delete                删除php版本
  lists                 查看已安装的php
  clean                 清理缓存垃圾


选项:
  -h                      显示帮助信息
  -v                      显示版本信息
```

## 支持

- windows x86_64

- linux x86_64、arrch64(测试)

### Linux 要求

```bash
apt install -y file 
export APPIMAGE_EXTRACT_AND_RUN=1 
```

## 后续目标

- server 模式 

- ffi助手 

- 再说...