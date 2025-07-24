# AppImage

### docker 运行

```bash
apt install -y file
export APPIMAGE_EXTRACT_AND_RUN=1
```

### 目录结构

```
AppRun
├─usr
│  └─bin
│    └─... 你的应用
│
├─AppRun 执行文件
├─.desktop 配置文件
└─AppRun.png 图标文件
```

`AppRun` 执行文件

```bash
#! /usr/bin/env bash
# 获取当前执行文件的路径

dir=$(dirname $(realpath $0))

exec $dir"/usr/bin/你的应用"
```

`.desktop` 配置文件

```bash
[Desktop Entry]
Name=应用名称
Comment=应用描述
Exec=AppRun 
Icon=图标名称
Type=Application
Terminal=true # 终端 才添加
Categories=Utility # 分类
```

### AppImage-tool

```bash
ARCH=x86_64 ./appimagetool-x86_64.AppImage /www/AppRun --runtime-file ./runtime-x86_64 -n "webman.bin"
```