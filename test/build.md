# 构建方式

- golang 环境(暂时需要弥补部分bug)
- vlang 环境

## 1.lang install

```bash
v install KingBes.libgo
```

## 2.预构建

```bash
# The Golang environment needs to be installed.
~/.vmodules/kingbes/libgo/go/build.sh  # linux
~/.vmodules/kingbes/libgo/go/build.cmd # windows
```

## 3.构建

```bash
v -cc gcc -os macos -o bny . # macos
v -cc gcc -os windows -o bny.exe . # windows
v -cc gcc -os linux -o bny . # linux
```