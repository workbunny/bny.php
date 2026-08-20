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

桥接代码实现了 **12 个能力**（PHP socket 与 WebView JS 侧共用同一套原生实现），本节对每个能力给出：说明、参数、请求/响应、PHP 示例、JS 示例与注意事项。

### 6.1 socket 与协议

APK 内置本地 Unix socket 桥（`BridgeServer`），监听于 App 私有目录：

```
unix:///data/data/com.bny.app/files/bridge.sock
```

路径按包名隔离（`applicationId` 固定为 `com.bny.app`），不与其他 App 冲突。桥随 App 启动而开启：应用运行时才能连接；退出后 `stop()` 关闭 socket 并向挂起的请求回 `error=bridge stopped`。

协议为换行分隔 JSON，请求：

```json
{"id": 1, "cmd": "toast", "params": {"message": "hi"}}
```

- `id`：数字，把响应与请求对应（建议自增）；
- `cmd`：命令名；`params`：参数对象（无则 `{}`）。

响应：

```json
{"id": 1, "ok": true, "data": {"key": "value"}}
{"id": 1, "ok": false, "error": "错误信息"}
```

> 无返回数据的成功命令（`toast`/`clipboard_set`/`vibrate`/`openUrl`）响应里**没有 `data` 字段**；`id` 回显请求里的 `id`。

### 6.2 命令总览

| 命令 | 类型 | 参数 | 成功时 `data` |
|------|------|------|--------------|
| `toast` | 同步 | `message`（必需）、`long`（可选） | 无 |
| `getUid` | 同步 | - | 数字 uid |
| `getVersion` | 同步 | - | 对象 `versionName`/`build` |
| `clipboard_get` | 同步 | - | 字符串 |
| `clipboard_set` | 同步 | `text`（必需） | 无 |
| `vibrate` | 同步 | `durationMs`（可选，默认 200） | 无 |
| `openUrl` | 同步 | `url`（必需） | 无 |
| `pickFile` | **异步** | `mime`（可选，默认 `*/*`） | 对象 `path` |
| `pickFiles` | **异步** | `mime`（可选，默认 `*/*`） | 对象 `paths`（数组） |
| `pickImages` | **异步** | - | 对象 `paths`（数组） |
| `openFile` | 同步 | `path`（必需）、`mime`（可选） | 无 |
| `listDir` | 同步 | `path`（必需） | 对象 `path`/`entries` |

### 6.3 逐功能详解

#### ① toast —— 顶部气泡提示

显示一条短暂的气泡提示。

- 参数：`message`（内容，必须）、`long`（bool，可选，`true` 显示更久）。
- 请求/响应：
  ```json
  {"id":1,"cmd":"toast","params":{"message":"你好","long":true}}
  {"id":1,"ok":true}
  ```
- PHP：`bridge_call($sock, 'toast', ['message' => '你好', 'long' => true]);`
- JS：`window.Android.showToast('你好');`（JS 侧固定短时长）

#### ② getUid —— 获取应用 UID

返回当前应用的 Linux UID（数字），用于识别 App 身份。

- 请求/响应：
  ```json
  {"id":2,"cmd":"getUid","params":{}}
  {"id":2,"ok":true,"data":10881}
  ```
- PHP：`$uid = bridge_call($sock, 'getUid')['data'];`
- JS：`var uid = window.Android.getUid();`（返回字符串）

#### ③ getVersion —— 获取应用版本

返回版本名与版本号（来自包信息）。

- 请求/响应：
  ```json
  {"id":3,"cmd":"getVersion","params":{}}
  {"id":3,"ok":true,"data":{"versionName":"1.0","build":1}}
  ```
- PHP：`$ver = bridge_call($sock, 'getVersion')['data']; // $ver['versionName'], $ver['build']`
- JS：无对应 JS 方法（仅 PHP socket）。

#### ④ clipboard_get / clipboard_set —— 剪贴板读写

读写系统剪贴板（主剪贴板）。

- `clipboard_get`：无参数，成功 `data` 为剪贴板文本；剪贴板为空或无文本时返回空字符串 `""`。
  ```json
  {"id":4,"cmd":"clipboard_get","params":{}}
  {"id":4,"ok":true,"data":"剪贴板里的内容"}
  ```
- `clipboard_set`：参数 `text`（内容，必须），无返回 `data`。
  ```json
  {"id":5,"cmd":"clipboard_set","params":{"text":"新的剪贴板内容"}}
  {"id":5,"ok":true}
  ```
- 注意：Android 10+ 限制后台应用读取剪贴板；本桥在 App 前台运行时读取可用。App 无前台焦点时 `clipboard_get` 可能返回空。
- PHP：见 6.4 示例 `bridge_call`。
- JS：`var txt = window.Android.clipboardGet();`、`window.Android.clipboardSet('hi');`

#### ⑤ vibrate —— 震动

触动设备震动指定毫秒数。

- 参数：`durationMs`（int，可选，默认 `200`）。
- 请求/响应：
  ```json
  {"id":6,"cmd":"vibrate","params":{"durationMs":300}}
  {"id":6,"ok":true}
  ```
- 注意：设备无震动马达时该命令**静默返回成功**（不报错）。
- PHP：`bridge_call($sock, 'vibrate', ['durationMs' => 300]);`
- JS：`window.Android.vibrate(200);`

#### ⑥ openUrl —— 用默认浏览器打开链接

用系统 `ACTION_VIEW` 打开一个 URL（网页/跳转外部应用）。

- 参数：`url`（必须）。
- 请求/响应：
  ```json
  {"id":7,"cmd":"openUrl","params":{"url":"https://example.com"}}
  {"id":7,"ok":true}
  ```
- 注意：当前页面会切到系统浏览器/对应应用打开；`url` 为空返回 `error=missing url`。
- PHP：`bridge_call($sock, 'openUrl', ['url' => 'https://example.com']);`
- JS：`window.Android.openUrl('https://example.com');`

#### ⑦ pickFile —— 选择文件（**异步**）

拉起系统文件选择器（`ACTION_GET_CONTENT`），按 `mime` 过滤类型。

- 参数：`mime`（可选，默认 `*/*`），如 `image/*`、`text/plain`、`application/pdf`。
- **异步行为**：发出请求后连接挂起、socket 不关闭（区别于 6 个同步命令的一行一答）；用户选完文件后，App 回写一行并**关闭该连接**。返回的 `path` 会把 `content://` 尝试解析为真实文件路径，失败时回退为原始 `content://...` 字符串。
- 请求/响应（成功、取消）：
  ```json
  {"id":8,"cmd":"pickFile","params":{"mime":"image/*"}}
  {"id":8,"ok":true,"data":{"path":"/storage/emulated/0/Download/a.jpg"}}

  {"id":8,"cmd":"pickFile","params":{"mime":"*/*"}}
  {"id":8,"ok":false,"error":"cancelled"}
  ```
- PHP：因是异步，用单独的等待函数（见 6.4 的 `bridge_pick`）。
- JS：`window.Android.pickFile('*/*');`，结果异步回调 `window.bnyOnPick(res)`，`res = {path, canceled}`。

#### ⑧ pickFiles —— 选择本地文件（**异步·可多选**）

拉起系统文件选择器并**多选**本地文件，按 `mime` 过滤类型。

- 参数：`mime`（可选，默认 `*/*`）。
- 异步行为同 `pickFile`；成功返回 `data.paths`（字符串数组，每个元素为文件路径，`content://` 尽可能解析为真实路径）。
- 请求/响应：
  ```json
  {"id":9,"cmd":"pickFiles","params":{"mime":"application/pdf"}}
  {"id":9,"ok":true,"data":{"paths":["/sdcard/a.pdf","/sdcard/b.pdf"]}}

  {"id":9,"cmd":"pickFiles","params":{}}
  {"id":9,"ok":false,"error":"cancelled"}
  ```
- PHP：`bridge_pick_multi($sock, 'application/pdf')` → 路径数组或 `null`（取消，见 6.4）。
- JS：`window.Android.pickFiles('*/*');`，`window.bnyOnPick(res).paths` 为数组。

#### ⑨ pickImages —— 相册多选图片（**异步·可多选**）

拉起系统图片选择器（相册/图库），可一次选多张图；等价于 `pickFiles` 固定 `mime=image/*` 且多选。

- 无参数。
- 请求/响应（成功 `data.paths` 数组；取消 `error=cancelled`）：
  ```json
  {"id":10,"cmd":"pickImages","params":{}}
  {"id":10,"ok":true,"data":{"paths":["/storage/emulated/0/Download/a.jpg","/storage/emulated/0/Download/b.png"]}}
  ```
- PHP：`bridge_pick_multi($sock, 'image/*')`（或直接用 `pickImages`）。
- JS：`window.Android.pickImages();`，结果在 `window.bnyOnPick(res).paths`。

#### ⑩ openFile —— 用系统查看器打开文件

把某个文件（本地路径或 `content://` URI）交给系统对应应用查看（看图、PDF、文本等）。

- 参数：`path`（必需，可为真实路径或 `content://...`）、`mime`（可选，帮助系统选应用）。
- 请求/响应：
  ```json
  {"id":11,"cmd":"openFile","params":{"path":"/sdcard/Documents/报告.pdf","mime":"application/pdf"}}
  {"id":11,"ok":true}
  ```
- 错误：`path` 为空 → `error=missing path`；系统无可用查看器 → `error=no viewer for: <path>`。
- PHP：`bridge_call($sock, 'openFile', ['path' => $p, 'mime' => 'application/pdf']);`
- JS：`window.Android.openFile('/sdcard/a.pdf', 'application/pdf');`

#### ⑪ listDir —— 列出本地目录内容

按路径列出目录下的文件与子目录（App 有权限访问的目录，如 App 私有目录、已授权可读路径）。

- 参数：`path`（必需）。
- 成功 `data`：
  ```json
  {"id":12,"cmd":"listDir","params":{"path":"/sdcard/Download"}}
  {"id":12,"ok":true,"data":{"path":"/sdcard/Download","entries":[{"name":"a.jpg","isDir":false,"size":12345,"modified":1690000000000},{"name":"sub","isDir":true,"size":0,"modified":1690000000000}]}}
  ```
  `entries` 每项：`name`（名称）、`isDir`（是否目录）、`size`（字节，目录为 0）、`modified`（毫秒时间戳）。
- 错误：`path` 为空 → `error=missing path`；不是目录/不可访问 → `error=not a directory: <path>`。
- PHP：`bridge_call($sock, 'listDir', ['path' => '/sdcard/Download'])['data']['entries']`
- JS：无对应 JS 方法（仅 PHP socket）。

### 6.4 PHP 侧完整封装

> 需启用 PHP `stream` 或 `sockets` 扩展；以下用 `stream_socket_client`。

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

/** pickFile：异步，发出请求后连接挂起，需另读一行等回写；返回路径或 null（取消） */
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

/** pickFiles/pickImages 多选：返回路径数组，取消返回 null */
function bridge_pick_multi($sock, string $cmd, string $mime = '*/*'): ?array {
    static $id = 9100;
    $params = $cmd === 'pickImages' ? [] : ['mime' => $mime];
    $req = json_encode(['id' => ++$id, 'cmd' => $cmd, 'params' => $params], JSON_UNESCAPED_UNICODE);
    fwrite($sock, $req . "\n");
    $line = fgets($sock); // 阻塞直至用户选择/取消
    $resp = json_decode($line, true);
    if (!is_array($resp)) {
        throw new RuntimeException("$cmd 响应无效: $line");
    }
    return $resp['ok'] ? ($resp['data']['paths'] ?? []) : null;
}

// 使用示例
$sock = bridge_connect();

bridge_call($sock, 'toast', ['message' => '准备读取设备信息']);
$uid = bridge_call($sock, 'getUid')['data'];                  // 数字
$ver = bridge_call($sock, 'getVersion')['data'];              // ['versionName', 'build']
$clp = bridge_call($sock, 'clipboard_get')['data'];           // 字符串，可为 ""
bridge_call($sock, 'clipboard_set', ['text' => '由 PHP 写入']);
bridge_call($sock, 'vibrate', ['durationMs' => 300]);
bridge_call($sock, 'openUrl', ['url' => 'https://example.com']);

// 单选文件
$path = bridge_pick($sock, '*/*');                            // 异步
echo "选择文件: " . ($path ?? '(取消)') . "\n";

// 多选本地文件
$files = bridge_pick_multi($sock, 'pickFiles', 'application/pdf');
foreach (($files ?? []) as $f) { echo "PDF: $f\n"; }

// 相册多选图片
$images = bridge_pick_multi($sock, 'pickImages');

// 用系统查看器打开一个文件
bridge_call($sock, 'openFile', ['path' => '/sdcard/Documents/报告.pdf', 'mime' => 'application/pdf']);

// 列出目录内容
$entries = bridge_call($sock, 'listDir', ['path' => '/sdcard/Download'])['data']['entries'];
foreach ($entries as $e) { echo ($e['isDir'] ? '[D] ' : '    ') . $e['name'] . "\n"; }

fclose($sock);
```

### 6.5 JS 侧使用

App 把同一个桥以 `window.Android` 暴露给页面（`PhpBridge`；同步方法返回字符串，`pickFile` 异步、结果经 `window.bnyOnPick` 回调）：

```js
// toast（短时长）
window.Android.showToast('Hello from JS');

// getUid（返回字符串）
var uid = window.Android.getUid();
console.log('uid=', uid);

// 剪贴板读写
var txt = window.Android.clipboardGet();
window.Android.clipboardSet('hi ' + txt);

// 震动
window.Android.vibrate(200);

// 打开网页
window.Android.openUrl('https://example.com');

// 选择文件：先注册回调再调用（异步）
window.bnyOnPick = function (res) {
    // 单选: res = {path: "...", canceled: false}
    // 多选: res = {paths: [...], canceled: false}
    if (res.canceled) { console.log('user cancelled'); return; }
    if (Array.isArray(res.paths)) { console.log('picked=', res.paths); } else { console.log('picked=', res.path); }
};
window.Android.pickFile('*/*');   // 单选
window.Android.pickFiles('*/*');  // 多选本地文件
window.Android.pickImages();      // 相册多选图片

// 用系统查看器打开文件
window.Android.openFile('/sdcard/a.pdf', 'application/pdf');
```

### 6.6 错误与注意事项

| 触发条件 | `error` |
|----------|---------|
| `toast` 缺 `message` | `missing message` |
| `clipboard_set` 缺 `text` | `missing text` |
| `openUrl` 缺 `url` | `missing url` |
| `openFile`/`listDir` 缺 `path` | `missing path` |
| `openFile` 无可用查看器 | `no viewer for: <path>` |
| `listDir` 目录不可访问/非目录 | `not a directory: <path>` |
| 未知名命令 | `unknown cmd: <cmd>` |
| JSON 解析失败 | `invalid request` |
| `pickFile`/`pickFiles`/`pickImages` 取消 | `cancelled` |
| App 退出，挂起的请求 | `bridge stopped` |

- 同步命令一请求一响；`pickFile`/`pickFiles`/`pickImages` 例外（异步、发完保持连接直到用户选择）。别在选择命令没完成前复用同一连接发别的同步命令。
- `pickFile` 返回 `data.path`；`pickFiles`/`pickImages` 返回 `data.paths`（数组）。
- 上述选择命令返回的路径优先把 `content://` 解析为真实文件路径，解析不到时返回原始 `content://...` 字符串。
- `listDir`/`openFile` 只能访问 App 有权限的目录（App 私有目录、已授权可读路径）；Android 分区存储下 `listDir('/sdcard/...')` 可能因权限返回 `not a directory`。
- Android 10+ 后台无法读剪贴板；App 失焦时 `clipboard_get` 可能为空。
- 无震动马达的设备上 `vibrate` 静默成功。

## 7. 产物与安装

| 构建类型 | 产物 | 说明 |
|----------|------|------|
| debug | `name-v<ver>-debug.apk` | 未签名，开发调试 |
| release | `name-v<ver>-release.apk` | 已签名，可上架/分发 |

```sh
adb install -r name-v1.0-debug.apk
```

真机为 `arm64-v8a`，模拟器（如 MuMu）为 `x86_64`。