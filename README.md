# Bny.php

一个简易的 PHP CLI 工具链，基于 [V 语言](https://vlang.io/) 开发。

```sh
    __                        __
   / /_  ____  __  __  ____  / /_  ____
  / __ \/ __ \/ / / / / __ \/ __ \/ __ \
 / /_/ / / / / /_/ / / /_/ / / / / /_/ /
/_.___/_/ /_/\__, (_) .___/_/ /_/ .___/
            /____/ /_/         /_/

Bny: v0.0.0 PHP: 已安装 Composer: 已安装 XXXX-XX-XX XX:XX:XX

用法:
  bny <指令> [参数] [选项]


指令:
  run                   运行主程序
  php                   运行PHP
  composer              运行Composer
  compile               编译项目
  android               打包为Android apk
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
- Android APK 打包，WebView 壳 + 内嵌 PHP 运行时
- 内置 Composer 支持

## 平台支持

| 平台 | 架构 | 状态 |
|------|------|------|
| Windows | x86_64 | 已支持 |
| Linux | x86_64, aarch64 | 已支持 |
| macOS | arm64 | 已支持 |


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
```

## 编译配置

在项目根目录创建 `bny.json` 配置文件：

```json
{
    "title": "我的应用",
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
| `title` | string | 项目显示名称，可中文（安卓应用名、Linux 桌面名），默认按 `name` |
| `name` | string | 编译产物文件名 (默认: 按入口文件名，如 `index.php` -> `index`) |
| `main` | string | 项目入口文件 (默认: `./index.php`) |
| `icon` | string | 应用程序图标路径 |
| `ini` | string | PHP 配置文件路径 |
| `define` | array | PHP 运行参数，与 `php -d` 相同 |
| `ignore` | array | 打包时忽略的文件或文件夹 |

### Android 打包

> 完整说明见 [ANDROID.md](ANDROID.md)：打包命令、配置、环境与 SDK 自动准备、签名、App 架构、以及 PHP/JS 桥接 Android 原生能力。

### 编译说明

- Windows 是采用 `EVB` 进行封包, `内存运行` ，安全指数：⭐⭐⭐⭐ 
- Linux 是采用 `AppImage` 进行封包, `解压运行` ，安全指数：无 
- MacOs 仅封装为 `.app` 目录结构，`open/双击 运行`, 安全指数：无
- Android 是采用 `Gradle` 打包 `WebView壳+内嵌PHP` 的 APK，`App打开即启动` ，安全指数：⭐⭐

### Linux compile 运行/打包要求

```sh
apt install -y file
export APPIMAGE_EXTRACT_AND_RUN=1
```

## 许可证

MIT License
