module compile

import base
import os
import net.http
import term
import compress.szip

pub struct Download {
pub mut:
	// windows 所需依赖
	evb   Url = {
		name: 'evb.zip'
		path: '/executables'
		file: base.path_add(base.Dirs{}.script, 'enigmavbconsole.exe')
	}
	cli   Url = {
		name: 'cli.zip'
		path: '/script'
		file: base.path_add(base.Dirs{}.script, 'cli.exe')
	}
	win32 Url = {
		name: 'win32.zip'
		path: '/executables'
		file: base.path_add(base.Dirs{}.script, 'win32.exe')
	}
	// linux 所需依赖
	appimage Url = {
		name: 'appimagetool-x86_64.zip'
		path: '/executables'
		file: base.path_add(base.Dirs{}.script, 'appimagetool-x86_64.AppImage')
	}
	runtime  Url = {
		name: 'runtime-x86_64.zip'
		path: '/executables'
		file: base.path_add(base.Dirs{}.script, 'runtime-x86_64')
	}
}

struct Url {
pub mut:
	name string
	path string
	file string
}

/**
 * 检查文件
 *
 * @return !void
 */
pub fn checked() ! {
	if !os.is_dir(base.Dirs{}.script) {
		os.mkdir(base.Dirs{}.script, os.MkdirParams{})!
	}
	if !os.is_dir(base.Dirs{}.log) {
		os.mkdir(base.Dirs{}.log, os.MkdirParams{})!
	}
	if os.user_os() == 'windows' {
		windows()!
	} else {
		linux()!
	}
}

/**
 * 检查windows文件
 *
 * @return !void
 */
fn windows() ! {
	if !os.is_file(Download{}.evb.path) {
		download(Download{}.evb.id, Download{}.evb.path)!
	}
	if !os.is_file(Download{}.cli.path) {
		download(Download{}.cli.id, Download{}.cli.path)!
	}
	if !os.is_file(Download{}.win32.path) {
		download(Download{}.win32.id, Download{}.win32.path)!
	}
}

/**
 * 检查linux文件
 *
 * @return !void
 */
fn linux() ! {
	if !os.is_file(Download{}.appimage.path) {
		download(Download{}.appimage.id, Download{}.appimage.path)!
	}
	if !os.is_file(Download{}.runtime.path) {
		download(Download{}.runtime.id, Download{}.runtime.path)!
	}
}

/**
 * 下载文件
 *
 * @param name string 文件名
 * @param path string 路径
 * @return !void
 */
fn download(url Url, path string) ! {
	println(term.dim('安装依赖...'))
	/* // 文件名
	name := base.file_name(path)
	// 下载地址
	url := lanzou.download(file)!
	// 下载文件路径
	zip_file := base.path_add(os.dir(path), name + '.zip')
	// 下载文件
	http.download_file(url, zip_file)!
	// 解压文件
	szip.extract_zip_to_dir(zip_file, os.dir(path))!
	// 删除压缩包文件
	os.rm(zip_file)! */
}
