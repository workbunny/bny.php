module compile

import base
import os
import php

/**
 * 编译项目
 *
 * @return !void
 */
pub fn appimage_build() ! {
	create_project()!
	appimage_compile()!
}

/**
 * 创建项目
 *
 * @return !void
 */
fn create_project() ! {
	dir := get_impdir()!
	if !os.is_dir(base.path_add(dir, 'AppRun')) {
		os.mkdir(base.path_add(dir, 'AppRun'), os.MkdirParams{})!
		os.mkdir(base.path_add(dir, 'AppRun', 'usr'), os.MkdirParams{})!
		os.mkdir(base.path_add(dir, 'AppRun', 'usr', 'bin'), os.MkdirParams{})!
	}
	main_filename_ext := base.file_name_ext(get_impfile()!)
	main_filename := base.file_name(get_impfile()!)

	// 执行文件
	mut apprun_file := []string{}
	apprun_file << '#! /usr/bin/env bash'
	apprun_file << 'dir=$(dirname $(realpath $0))'
	apprun_file << 'exec \$dir"/usr/bin/php" \$dir"/usr/bin/${main_filename_ext}" $@'
	os.write_file(base.path_add(dir, 'AppRun', 'AppRun'), apprun_file.join('\n'))!

	// 配置文件
	mut apprun_desktop := []string{}
	apprun_desktop << '[Desktop Entry]'
	apprun_desktop << 'Name=${main_filename}'
	apprun_desktop << 'Type=Application'
	apprun_desktop << 'Exec=AppRun'
	apprun_desktop << 'Icon=php'
	if is_term() {
		apprun_desktop << 'Terminal=true'
	}
	apprun_desktop << 'Categories=Utility;'
	os.write_file(base.path_add(dir, 'AppRun', '.desktop'), apprun_desktop.join('\n'))!

	// 图标文件
	os.write_file(base.path_add(dir, 'AppRun', 'php.png'), '')!

	// 复制项目
	cp_project()!
}

/**
 * 编译项目
 *
 * @return !void
 */
fn appimage_compile() ! {
	// 导出文件
	outfile := get_outfile()!
	// 编译目录
	apprun_dir := base.path_add(get_impdir()!, 'AppRun')
	dl := Download{}
	// 编译工具
	appimage_tool := dl.appimage.path
	// 运行时
	runtime := dl.runtime.path
	// 编译
	os.execute('ARCH=x86_64 ${appimage_tool} ${apprun_dir} --runtime-file ${runtime} -n ${outfile}')
	// 删除编译目录
	base.rm_all(apprun_dir)!
	// 设置权限
	os.chmod(outfile, 0o755)!
}

/**
 * 复制项目
 *
 * @return !void
 */
fn cp_project() ! {
	// php文件路径
	php_path := php.get_php_path()!
	// php 文件名称
	php_name := base.file_name_ext(php_path)

	impdir := get_impdir()!
	// 新的php文件路径
	new_php_path := base.path_add(impdir, 'AppRun', 'usr', 'bin', php_name)
	// 复制文件
	os.cp_all(php_path, new_php_path, true)!

	apprun_dir := base.path_add(impdir, 'AppRun', 'usr', 'bin')
	arr := os.ls(impdir)!
	for i in arr {
		if i.contains('AppRun') || i.contains('runtime') || i.contains('.git')
			|| i.contains(base.file_name_ext(get_outfile()!)) {
			continue
		}
		println('[编译]: ' + base.path_add(impdir, i))
		os.cp_all(base.path_add(impdir, i), base.path_add(apprun_dir, i), true)!
	}

	// 设置权限
	base.chmod_all(base.path_add(impdir, 'AppRun'), 0o755)!
}
