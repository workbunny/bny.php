# Bny Android 打包指南

> 将 PHP 项目打包为 Android APK（WebView 壳 + 内嵌 PHP 运行时）。
> 本文覆盖打包命令、配置、环境、签名、产物，以及 PHP / JS 调用 Android 原生能力的桥接方式。
> 固定安卓的PHP版本为 8.5

## 1. 打包命令

```sh
# 基本用法：以当前目录为项目根（存在 bny.json 则读取配置）
bny android .

# 指定入口文件，以其所在目录为项目根（产物名默认按入口文件名推导）
bny android ./index.php

# 架构
bny android . -arch aarch64   # 仅真机（arm64-v8a）
bny android . -arch x86_64    # 仅模拟器（如 MuMu）
bny android . -arch all       # 双架构（默认）

# 版本号 / 版本名
bny android . -ver 2.0 -code 20

# 产物名与图标
bny android . -o myapp -icon icon.png

# release 包（默认自动生成签名）
bny android . -release

# release 并指定证书 CN
bny android . -release example.com

# 帮助
bny android -h
```

命令行选项优先级：`-arch / -ver / -code / -o / -icon / -release` 优先于 `bny.json` 配置。

产物：`<name>-v<版本>-<debug|release>.apk`（默认输出到**当前目录**），安装用 `adb install -r <apk>`。

## 2. bny.json 配置

```json
{
    "title": "我的应用",
    "name": "myapp",
    "main": "./start.php",
    "icon": "./icon.png",
    "ini": "./php.ini",
    "define": ["memory_limit=256M"],
    "ignore": ["runtime/", ".git/", "test/"],
    "android": {
        "port": 8787,
        "start": "./start.php start -d",
        "stop": "./start.php stop",
        "arch": "aarch64",
        "ver": "1.0",
        "code": 1,
        "sign": "example.com"
    }
}
```

### android.* 字段

| 字段 | 类型 | 默认 | 说明 |
|------|------|------|------|
| `port` | int | `8787` | 服务端口，App 内 WebView 访问 `http://127.0.0.1:<port>` |
| `start` | string | `-S 127.0.0.1:8787 ./` | 启动命令。内置服务器填 php 选项；守护型框架（webman/workerman）填 `./start.php start -d` |
| `stop` | string | 空 | 优雅停止命令（守护型框架填 `./start.php stop`）；内置服务器留空 |
| `arch` | string | `all` | `aarch64` / `x86_64` / `all` |
| `ver` | string | `1.0` | 版本名 (versionName) |
| `code` | int | `1` | 版本号 (versionCode) |
| `sign` | string | 空 | release 签名证书 CN，等价 `-release <CN>`；空则默认 `<name>.demo.com` |

### 顶层字段

| 字段 | 说明 |
|------|------|
| `title` | 应用显示名（可中文），默认按 `name` |
| `name` | 产物文件名 |
| `main` | 项目入口文件 |
| `icon` | 应用图标（PNG，会被铺到各 mipmap 密度目录） |
| `ini` / `define` | 透传给 PHP 的配置与 `-d` 参数 |
| `ignore` | 打包进 assets 时忽略的文件/文件夹（如 `runtime/`、`.git/`）。`.apk`、`<name>.keystore` 等产物会被自动忽略 |

## 3. 环境要求与自动准备

| 项 | 要求 | 处理方式 |
|----|------|----------|
| JDK | 17+ | 必须配置 `JAVA_HOME`（否则报错退出） |
| Android SDK | platform-34 + build-tools-34 | **自动准备**，见下 |
| Gradle | 8.9 | 由 bny 自动下载到 `cache/` |

### Android SDK 自动准备

bny 会按以下优先级解析 SDK 根，缺组件时用 `sdkmanager` 自动补齐（platform-34 + build-tools-34）：

1. `ANDROID_HOME` 若本身是“SDK 根”（含 `cmdline-tools` / `platforms` / `build-tools` 结构）→ 直接复用/补齐；
2. 否则回退到 bny 自带的 `script/android-sdk` 目录，在此完整准备（下载 commandline-tools、装组件）。

> 注意：`ANDROID_HOME` 若只是 `platform-tools`（只含 adb、不算 SDK 根），会回退到 bny 自带位置，避免往只读目录写入。
> commandline-tools 与 SDK 组件都放在 SDK 根内持久化，清理 `cache/` 不影响已备好的 SDK。

## 4. 签名

`android.sign` 就是证书 CN，**等价于 `bny android . -release <CN>` 的值**，只控制 release 签名的证书 CN。

同一个 CN 有三种给法，**优先级从高到低**：

1. **命令行**：`bny android . -release example.com` → CN = `example.com`；
2. **bny.json**：`android.sign = "example.com"` → 不用每次敲 `-release`；
3. **默认**：`<name>.demo.com`（如 `myapp.demo.com`）。

> 只写 `bny android . -release`（不带 CN）时，CN 取 `bny.json` 的 `android.sign`，没有再取默认 `name.demo.com`。

签名本体由 bny 自动完成：
- **debug 包**：不签名，直接可装。
- **release 包**（`-release`）：自动生成 keystore（存到项目根 `<name>.keystore` + `<name>.keystore.properties`），首次生成后复用，保证可覆盖升级。

## 5. App 架构与运行原理

APK 内嵌：
- 壳 Java（`MainActivity`）：WebView 壳 + 生命周期管理；
- `assets/app`：你的 PHP 项目文件；
- `assets/usr`：Termux PHP 运行时（含共享库）；
- `jniLibs/libphp.so`：PHP 可执行文件（由运行时 zip 中的 `php` 改名而来，AGP 的 jniLibs 只认 `lib*.so`）；
- `assets/runtime.json`：运行配置（port/start/stop/ini/define）；
- `assets/payload_manifest`：payload 文件清单（MD5 哈希）。

首次启动流程：
1. `PhpRuntime.ensureDeployed()` 把 `assets/app` 与 `assets/usr` 复制到 `getFilesDir/` 下的私有目录；`payload_manifest` 哈希未变时跳过（增量优化）；
2. `PhpRuntime.start()` 执行 `start` 命令（前台 `php -S` 或守护化 start），轮询端口就绪；
3. WebView 加载 `http://127.0.0.1:<port>/`；
4. 退出时按 `stop` 命令优雅停止，或直接销毁前台进程。

启动脚本定位到 `appDir`（即项目根），默认 `-S 127.0.0.1:8787 ./`；WebView 与 PHP 在同一设备本地通信。

## 6. PHP / JS 调用 Android 原生能力（桥接）

APK 内置一个本地 Unix socket 桥（`BridgeServer`），监听于 App 私有目录：

```
unix:///data/data/com.bny.app/files/bridge.sock
```

路径按包名隔离（`applicationId` 固定为 `com.bny.app`），不与其他 App 冲突。
桥随 App 启动而开启：应用运行时才能连接；App 退出后 socket 关闭。

### 协议

换行分隔的 JSON。**一行请求 → 一行响应**（`pickFile` 例外，见下）。请求：

```json
{"id": 1, "cmd": "toast", "params": {"message": "hi"}}
```

- `id`：数字，用于把响应和请求对应起来（建议自增）；
- `cmd`：命令名；
- `params`：该命令的参数对象（无则传 `{}`）。

响应：

```json
{"id": 1, "ok": true, "data": {"key": "value"}}
```

```json
{"id": 1, "ok": false, "error": "错误信息"}
```

> 无返回数据的成功命令（如 `toast`）响应里**没有 `data` 字段**。`id` 与请求一致。

### 支持的命令

| 命令 | 类型 | params | 成功时 `data` |
|------|------|--------|--------------|
| `toast` | 同步 | `message`（必需）、`long`（可选 bool，默认 false） | 无 |
| `getUid` | 同步 | - | 应用 uid（数字） |
| `getVersion` | 同步 | - | 对象：`versionName`、`build` |
| `clipboard_get` | 同步 | - | 剪贴板文本（字符串） |
| `clipboard_set` | 同步 | `text`（必需） | 无 |
| `vibrate` | 同步 | `durationMs`（可选，默认 200） | 无 |
| `openUrl` | 同步 | `url`（必需） | 无 |
| `pickFile` | **异步** | `mime`（可选，默认 `*/*`） | 对象：`path`（文件路径） |

#### 同步命令示例（请求 → 响应）

```json
// toast
{"id":1,"cmd":"toast","params":{"message":"你好","long":true}}
{"id":1,"ok":true}

// getUid → data 为数字
{"id":2,"cmd":"getUid","params":{}}
{"id":2,"ok":true,"data":10881}

// getVersion → data 为对象
{"id":3,"cmd":"getVersion","params":{}}
{"id":3,"ok":true,"data":{"versionName":"1.0","build":1}}

// clipboard_get / clipboard_set
{"id":4,"cmd":"clipboard_get","params":{}}
{"id":4,"ok":true,"data":"剪贴板里的内容"}
{"id":5,"cmd":"clipboard_set","params":{"text":"新的剪贴板内容"}}
{"id":5,"ok":true}

// vibrate / openUrl
{"id":6,"cmd":"vibrate","params":{"durationMs":300}}
{"id":6,"ok":true}
{"id":7,"cmd":"openUrl","params":{"url":"https://example.com"}}
{"id":7,"ok":true}
```

`pickFile` 为**异步**：发出请求后连接挂起、socket 不关闭；用户选择文件后回写一行（取消则 `error=cancelled`）：

```json
{"id":8,"cmd":"pickFile","params":{"mime":"image/*"}}
{"id":8,"ok":true,"data":{"path":"/storage/emulated/0/Download/a.jpg"}}
```

#### 失败响应的 `error`

| 场景 | 返回 `error` |
|------|-------------|
| `toast` 缺 `message` | `missing message` |
| `clipboard_set` 缺 `text` | `missing text` |
| `openUrl` 缺 `url` | `missing url` |
| 未知名命令 | `unknown cmd: <cmd>` |
| JSON 解析失败 | `invalid request` |
| `pickFile` 用户取消 | `cancelled` |

### PHP 侧完整示例

> PHP 需启用 `sockets` 或 `stream` 扩展；以下用 `stream_socket_client`。

```php
<?php
const BRIDGE_SOCK = 'unix:///data/data/com.bny.app/files/bridge.sock';

/** 建立连接（App 须正在运行） */
function bridge_connect(): resource {
    $sock = stream_socket_client(BRIDGE_SOCK, $errno, $errstr, 5);
    if ($sock === false) {
        throw new RuntimeException("无法连接 Android 桥: $errstr ($errno)");
    }
    stream_set_timeout($sock, 10);
    return $sock;
}

/** 发送一个同步命令，读到并返回整行响应（已 json_decode），失败抛异常 */
function bridge_call($sock, string $cmd, array $params = []): array {
    static $id = 0;
    $req = json_encode(['id' => ++$id, 'cmd' => $cmd, 'params' => $params], JSON_UNESCAPED_UNICODE);
    fwrite($sock, $req . "\n");
    $line = fgets($sock);
    if ($line === false || $line === '') {
        throw new RuntimeException("Android 桥无响应: $cmd");
    }
    $resp = json_decode($line, true);
    if (!is_array($resp) || ($resp['ok'] ?? false) !== true) {
        throw new RuntimeException("Android 桥命令失败: " . ($resp['error'] ?? $line));
    }
    $resp['data'] = $resp['data'] ?? null;
    return $resp;
}

/** pickFile：发出请求后连接挂起，需另读一行等回写，返回路径或 null（取消） */
function bridge_pick($sock, string $mime = '*/*'): ?string {
    static $id = 9000;
    $req = json_encode(['id' => ++$id, 'cmd' => 'pickFile', 'params' => ['mime' => $mime]], JSON_UNESCAPED_UNICODE);
    fwrite($sock, $req . "\n");
    $line = fgets($sock); // 阻塞直至用户选择/取消
    $resp = json_decode($line, true);
    if (!is_array($resp)) {
        throw new RuntimeException("pickFile 响应无效: $line");
    }
    return $resp['ok'] ? ($resp['data']['path'] ?? null) : null;
}

$sock = bridge_connect();

// 1) 提示气泡
bridge_call($sock, 'toast', ['message' => '你好，PHP!', 'long' => false]);

// 2) 获取应用 uid
$uid = bridge_call($sock, 'getUid')['data'];
echo "uid=$uid\n";

// 3) 获取应用版本
$ver = bridge_call($sock, 'getVersion')['data'];
echo "version={$ver['versionName']} build={$ver['build']}\n";

// 4) 读写剪贴板
$clip = bridge_call($sock, 'clipboard_get')['data'];
bridge_call($sock, 'clipboard_set', ['text' => "PHP 写入: $clip"]);
echo "clipboard=$clip\n";

// 5) 震动 300ms
bridge_call($sock, 'vibrate', ['durationMs' => 300]);

// 6) 打开网页
bridge_call($sock, 'openUrl', ['url' => 'https://example.com']);

// 7) 选择文件（异步，等待用户选择）
$path = bridge_pick($sock, '*/*');
if ($path !== null) {
    echo "选择文件: $path\n";
} else {
    echo "已取消选择\n";
}

fclose($sock);
```

### JS 侧完整示例

App 把同一个桥以 `window.Android` 暴露给 WebView 页面（`PhpBridge`，同步返回值直接可用；`pickFile` 为异步，结果经 `window.bnyOnPick` 回调）：

```js
// 提示气泡（JS 侧固定短时长）
window.Android.showToast('Hello from JS');

// 获取应用 uid（返回字符串）
var uid = window.Android.getUid();
console.log('uid=', uid);

// 读写剪贴板
var txt = window.Android.clipboardGet();
window.Android.clipboardSet('hi ' + txt);

// 震动 200ms
window.Android.vibrate(200);

// 打开网页
window.Android.openUrl('https://example.com');

// 选择文件：异步，需先注册回调再调用
window.bnyOnPick = function (res) {
    // res = {path: "...", canceled: false}
    if (res.canceled) {
        console.log('user cancelled');
        return;
    }
    console.log('picked=', res.path);
};
window.Android.pickFile('*/*');
```

## 7. 产物与安装

| 构建类型 | 产物 | 说明 |
|----------|------|------|
| debug | `name-v<ver>-debug.apk` | 未签名，开发调试 |
| release | `name-v<ver>-release.apk` | 已签名，可上架/分发 |

```sh
adb install -r name-v1.0-debug.apk
```

真机为 `arm64-v8a`，模拟器（如 MuMu）为 `x86_64`。