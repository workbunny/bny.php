# bny.php

💕 Bny.php 一 个 简 易 的 PHP 管 理 工 具

💕 集 成 各 种 便 捷 工 具 方 便 开 发

💕 大 部 分 编 程 功 能 都 是 PHP 本 身 不 用 担 心 要 逃 离 舒 适 圈

- 编译cli项目 编译为单个可执行文件(方便分发)
- php版本管理 可以安装多个php版本,并在项目中切换使用

```sh
    __                        __
   / /_  ____  __  __  ____  / /_  ____
  / __ \/ __ \/ / / / / __ \/ __ \/ __ \
 / /_/ / / / / /_/ / / /_/ / / / / /_/ /
/_.___/_/ /_/\__, (_) .___/_/ /_/ .___/
            /____/ /_/         /_/

Bny: v0.0.0 PHP: 已安装 Composer: 已安装 2025-07-19 09:50:12

用法:
  bny <指令> [参数] [选项]


指令:
  run                   运行主程序
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

- linux x86_64、arrch64

- macos x86_64、arm64

### Linux 要求

```bash
apt install -y file 
export APPIMAGE_EXTRACT_AND_RUN=1 
```

## 使用技巧

### 指令`run`运行主程序

`bny run -h` 查看帮助

```base
用法:

bny run [目标] <指令>

目标:

  .                         当前目录
  [file]                    入口文件
  -v [number]               指定PHP版本号
  -h                        帮助查看
```

入口文件可以为 ".",比如`bny run .` 表示运行当前目录下的入口文件,默认是`index.php`,你也可以添加`bny.json`配置文件来指定入口文件.

`bny.json`配置文件示例:

```json
{
    "main": "./demo/index.php", // 入口文件
    "ini_path": "./demo/php.ini", // php.ini 配置文件路径(可选)
    "php_ins" :[  // php.ini 配置参数(可选)
      "-d post_max_size=128M",
      "-d upload_max_filesize=128M"
    ]
}
```

### 指令`compile`编译项目

`bny compile -h` 查看帮助

```base
用法:

bny compile [目标] <指令>

目标:

  .                          编译当前目录
  [path]                     根据入口文件编译
  -h                         帮助查看

指令:

  -noterm                     不显示终端窗口
  -o [name]                   编译为指定文件名
  -icon [file]                编译为指定图标

示例:

  bny compile .  # 编译当前目录可加配置文件bny.json
  bny compile index.php  # 编译指定入口文件
  bny compile index.php -o myapp  # 编译指定入口文件并指定输出文件名
  bny compile . -icon icon.ico  # 编译当前目录并指定图标
```

## 后续目标

- server 模式 

- ffi助手 

- 再说...