module android

import common
import os.cmdline
import term

pub fn run() ! {
	mut args := common.get_args()
	args.delete(0) // 去掉 android
	if args.len == 0 {
		common.dump('android')!
		return
	}
	if args.contains('-h') {
		common.dump('android')!
		return
	}
	// 读取配置 (无位置参数时内部补 '.', 走当前目录 bny.json)
	conf := common.get_bny_config()!
	// 选项优先级: 命令行选项 > bny.json android 块 > 默认值
	arch_opt := cmdline.option(args, '-arch', conf.android.arch)
	if arch_opt !in ['aarch64', 'x86_64', 'all'] {
		println(term.red('不支持的架构: ${arch_opt}, 可选: aarch64 / x86_64 / all'))
		return
	}
	// -release 可携带证书 CN (如 -release XX.com), 不带则按 项目名.demo.com
	mut release := false
	mut cert_cn := ''
	for i, a in args {
		if a == '-release' {
			release = true
			if i + 1 < args.len && !args[i + 1].starts_with('-') {
				cert_cn = args[i + 1]
			}
		}
	}
	ver := cmdline.option(args, '-ver', conf.android.ver)
	code := cmdline.option(args, '-code', conf.android.code.str())
	println(term.green('开始打包 Android 项目...'))
	// 环境预检
	checked()!
	// 签名准备 (release: 复用或生成 keystore, 需在组装工程前确定签名文件名以排除出 assets)
	// CN 优先级: 命令行 -release [CN] > android.sign (bny.json 字符串) > 默认 (默认在 sign.v 内处理)
	if cert_cn == '' {
		cert_cn = conf.android.sign
	}
	mut sign := Signing{}
	if release {
		sign = prepare_signing(conf, cert_cn)!
	}
	// 组装临时工程
	project := build_project(conf)!
	// 品牌定制
	apply_brand(conf, project)!
	// 下载 PHP 运行时
	fetch_runtime(arch_opt, project)!
	// gradle 构建
	typ := if release { 'release' } else { 'debug' }
	apk := gradle_build(project, release, ver, code, sign)!
	// 收集产物
	collect(apk, conf, typ, ver)
}
