module compile

import base
import os
import php
import os.cmdline

/**
 * 编译项目
 *
 * @return !void
 */
pub fn appimage_build() ! {
	create_project()!
	appimage_compile()!
}

fn get_dir() !string {
	dir_name := (get_impdir()!).replace('\\', '').replace('/', '')
	// 创建目录
	dir := base.path_add(base.Dirs{}.log, dir_name)
	arr := [dir, base.path_add(dir, 'usr'), base.path_add(dir, 'usr', 'bin')]
	for i in arr {
		if !os.is_dir(i) {
			os.mkdir(i, os.MkdirParams{})!
		}
	}
	return dir
}

/**
 * 创建项目
 *
 * @return !void
 */
fn create_project() ! {
	dir := get_dir()!

	main_filename_ext := base.file_name_ext(get_impfile()!)
	main_filename := base.file_name(get_impfile()!)

	// 执行文件
	mut apprun_file := []string{}
	apprun_file << '#! /usr/bin/env bash'
	apprun_file << 'dir=$(dirname $(realpath $0))'
	apprun_file << 'exec \$dir"/usr/bin/php" \$dir"/usr/bin/${main_filename_ext}" $@'
	os.write_file(base.path_add(dir, 'AppRun'), apprun_file.join('\n'))!

	// 配置文件
	mut apprun_desktop := []string{}
	apprun_desktop << '[Desktop Entry]'
	apprun_desktop << 'Name=${main_filename}'
	apprun_desktop << 'Type=Application'
	apprun_desktop << 'Exec=AppRun'
	apprun_desktop << 'Icon=icon'
	if is_term() {
		apprun_desktop << 'Terminal=true'
	}
	apprun_desktop << 'Categories=Utility;'
	os.write_file(base.path_add(dir, '.desktop'), apprun_desktop.join('\n'))!

	// 图标文件
	mut icon := cmdline.option(base.get_args(), '-icon', '')
	if icon != '' {
		if os.is_file(icon) {
			os.cp(icon, base.path_add(dir, 'icon.png'))!
		} else {
			panic('图标文件不存在:${icon}')
		}
	} else {
		os.write_file(base.path_add(dir, 'icon.png'), '')!
	}

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
	apprun_dir := get_dir()!
	// 编译工具
	appimage_tool := Download.appimage.next().file
	// 运行时
	runtime := Download.runtime.next().file
	// 编译
	mut process := os.new_process(appimage_tool)
	process.set_args(['--appimage-extract-and-run',apprun_dir, '--runtime-file', runtime, '-n', outfile])
	process.env << 'ARCH=' + base.get_machine()
	process.run()
	process.wait()
	// 设置权限
	os.chmod(outfile, 0o755)!
}

/**
 * 复制项目
 *
 * @return !void
 */
fn cp_project() ! {
	dir := get_dir()!

	// php文件路径
	php_path := php.get_php_path()!
	// php 文件名称
	php_name := base.file_name_ext(php_path)
	apprun_dir := base.path_add(dir, 'usr', 'bin')
	impdir := get_impdir()!
	// 新的php文件路径
	new_php_path := base.path_add(apprun_dir, php_name)
	// 复制文件
	os.cp(php_path, new_php_path)!

	arr := os.ls(impdir)!
	for i in arr {
		if i.contains('AppRun') || i.contains('runtime') || i.contains('.git')
			|| i.contains(base.file_name_ext(get_outfile()!)) {
			continue
		}
		println('[编译]: ' + base.path_add(impdir, i))
		os.cp_all(base.path_add(impdir, i), base.path_add(apprun_dir, i), true)!
	}
	println(dir)
	// 设置权限
	base.chmod_all(dir, 0o777)!
}
