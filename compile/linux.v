module compile

import common
import time
import os.cmdline
import os
import term

pub fn linux_build(conf common.BnyConfig) ! {
	println(term.green('开始编译项目...'))
	project := create_cache_project(conf)!
	arch := common.get_os_machine()!
	appimage := common.app_path('/script/appimagetool-${arch}.AppImage')
	runtime := common.app_path('/script/runtime-${arch}')
	// 开始打包
	mut p := os.new_process(appimage)
	p.set_args([
		'--appimage-extract-and-run',
		project,
		'--runtime-file',
		runtime,
		'--output',
		common.shell_path(conf.name + '.bin'),
	])
	p.env << 'ARCH=' + arch
	p.run()
	p.wait()
	// 设置权限
	os.chmod(common.shell_path(conf.name + '.bin'), 0o755)!
	println(term.green('编译完成:${common.shell_path(conf.name + '.bin')}'))
}

/**
 * 创建缓存目录
 * @return 缓存目录
 */
fn create_cache_dir() !string {
	dir := common.path_add(common.Dirs{}.cache, time.now().custom_format('YYMDHms'))
	// 创建目录
	arr := [
		dir,
		common.path_add(dir, 'usr'),
		common.path_add(dir, 'usr', 'bin'),
		common.path_add(dir, 'usr', 'bin', 'php'),
	]
	for i in arr {
		if !os.is_dir(i) {
			os.mkdir(i, os.MkdirParams{})!
		}
	}
	return dir
}

/**
 * 创建缓存项目
 * @param conf 配置
 * @return 缓存项目
 */
fn create_cache_project(conf common.BnyConfig) !string {
	info := common.get_info()!
	dir := create_cache_dir()!
	// 创建cache执行文件
	mut apprun_file := []string{}
	apprun_file << '#! /usr/bin/env bash'
	apprun_file << 'dir=$(dirname $(realpath $0))' // 获取当前目录
	apprun_file << 'exec \$dir"/usr/bin/cli" $@' // 执行cli文件
	// 保存至dir/AppRun文件
	os.write_file(common.path_add(dir, 'AppRun'), apprun_file.join('\n'))!

	// 创建cache配置文件
	mut desktop_file := []string{}
	desktop_file << '[Desktop Entry]' // 桌面开始
	desktop_file << 'Name=${conf.name}' // 名称
	desktop_file << 'Type=Application' // 应用
	desktop_file << 'Exec=AppRun' // 执行文件
	desktop_file << 'Icon=icon' // 图标文件
	if is_noterm() {
		desktop_file << 'Terminal=true' // 是否命名窗口
	}
	desktop_file << 'Categories=Utility;' // 分类
	os.write_file(common.path_add(dir, '.desktop'), desktop_file.join('\n'))!

	// 图标文件
	if conf.icon != '' {
		if os.is_file(common.shell_path(conf.icon)) {
			os.cp(common.shell_path(conf.icon), common.path_add(dir, 'icon.png'))!
		} else {
			error('图标文件不存在:${common.shell_path(conf.icon)}')
		}
	} else {
		if os.is_file(common.app_path('/icon.png')) {
			os.cp(common.app_path('/icon.png'), common.path_add(dir, 'icon.png'))!
		} else {
			os.write_file(common.path_add(dir, 'icon.png'), '')!
		}
	}

	// php文件处理
	php_dir := info.php_list[info.php].path
	os.cp_all(php_dir, common.path_add(dir, 'usr', 'bin', 'php'), true)!

	// 复制cli文件
	os.cp(common.path_add(common.Dirs{}.script, 'cli'), common.path_add(dir, 'usr', 'bin',
		'cli'))!

	// 复制项目内容
	arr := os.ls(common.shell_path(none))!
	println(arr)
	for i in arr {
		if common.filter_path(i,conf.ignore) {
			continue
		}
		println('[打包]:'+ common.path_add(common.shell_path(none), i))
		os.cp_all(common.path_add(common.shell_path(none), i), common.path_add(dir, i), true)!
	}
	println('文件夹:${dir}')
	common.chmod_all(dir, 0o777)!
	return dir
}

/**
 * 是否命名窗口
 * @return 是否命名窗口
 */
fn is_noterm() bool {
	mut args := common.get_args()
	noterm := cmdline.option(args, '-noterm', 'false')
	if noterm != 'flase' {
		return true
	} else {
		return false
	}
}
