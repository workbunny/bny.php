# Bny.php

一个简易的 PHP 管理工具，基于 [V 语言](https://vlang.io/) 开发。

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

## 特性

- 轻量简洁，无需复杂配置
- PHP 版本管理，支持多版本切换
- 项目一键编译，将 PHP CLI 项目打包为单个可执行文件
- 内置 Composer 支持
- 跨平台支持 (Windows / Linux / macOS)

## 功能概览

| 功能 | 说明 |
|------|------|
| `run` | 运行 PHP 项目或脚本 |
| `php` | 直接运行 PHP 命令 |
| `composer` | 运行 Composer 包管理器 |
| `compile` | 将项目编译为独立可执行文件 |
| `add` | 下载并安装指定 PHP 版本 |
| `search` | 搜索可用的 PHP 版本 |
| `lists` | 查看已安装的 PHP 版本列表 |
| `delete` | 删除指定的 PHP 版本 |
| `clean` | 清理缓存目录 |

## 快速开始

### 安装

下载对应平台的预编译版本，添加到系统 PATH 即可使用。

### 基本用法

```sh
# 查看帮助
bny -h

# 查看版本
bny -v

# 运行 PHP 脚本
bny run index.php

# 运行 Composer 命令
bny composer require package/name

# 添加 PHP 版本
bny add 8.4

# 切换 PHP 版本
bny add 8.5

# 查看已安装的 PHP 版本
bny lists

# 编译当前项目
bny compile .

# 编译为指定名称
bny compile index.php -o myapp

# 编译为指定名称并设置图标
bny compile index.php -o myapp -icon app.ico

# 清理缓存
bny clean
```

## 编译配置

在项目根目录创建 `bny.json` 配置文件：

```json
{
    "name": "myapp",
    "main": "./index.php",
    "icon": "./icon.png",
    "ini": "./php.ini",
    "define": [
        "memory_limit=256M",
        "max_execution_time=300"
    ],
    "ignore": [
        "runtime/",
        ".git/",
        "test/"
    ]
}
```

### 配置说明

| 字段 | 类型 | 说明 |
|------|------|------|
| `name` | string | 编译后的可执行文件名 (默认: `index`) |
| `main` | string | 项目入口文件 (默认: `./index.php`) |
| `icon` | string | 应用程序图标路径 |
| `ini` | string | PHP 配置文件路径 |
| `define` | array | PHP 运行参数，与 `php -d` 相同 |
| `ignore` | array | 打包时忽略的文件或文件夹 |

## 平台支持

| 平台 | 架构 | 状态 |
|------|------|------|
| Windows | x86_64 | 已支持 |
| Linux | x86_64, aarch64 | 已支持 |
| macOS | arm64 | 已支持 |

### Linux AppImage 运行要求

```sh
apt install -y file
export APPIMAGE_EXTRACT_AND_RUN=1
```

## 下载源配置

在 `info.json` 中可以手动配置 PHP 下载源：

```json
{
    "url": {
        "windows": [
            {"name": "8.5", "url": "https://..."}
        ],
        "linux": {
            "x86_64": [
                {"name": "8.4", "url": "https://..."}
            ],
            "aarch64": []
        },
        "macos": []
    }
}
```

支持的平台：`windows`、`linux` (x86_64/aarch64)、`macos`

## 许可证

MIT License