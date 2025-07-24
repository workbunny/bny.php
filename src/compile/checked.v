module compile

import base
import lanzou
import os
import net.http
import term
import compress.szip

pub struct Download {
pub mut:
	// windows 所需依赖
	evb   struct {
	pub:
		id   string = 'ixPav310im7c'
		path string = base.path_add(base.app_path(), 'script', 'enigmavbconsole.exe')
	}
	cli   struct {
	pub:
		id   string = 'irs0C31mdsoh'
		path string = base.path_add(base.app_path(), 'script', 'cli.exe')
	}
	win32 struct {
	pub:
		id   string = 'ij8YQ31pca1i'
		path string = base.path_add(base.app_path(), 'script', 'win32.exe')
	}
	// linux 所需依赖
	appimage struct {
	pub:
		id   string = 'iBMuT31mdlhi'
		path string = base.path_add(base.app_path(), 'script', 'appimagetool-x86_64.AppImage')
	}
	runtime  struct {
	pub:
		id   string = 'is44m31mdl9a'
		path string = base.path_add(base.app_path(), 'script', 'runtime-x86_64')
	}
}

/**
 * 检查文件
 *
 * @return !void
 */
pub fn checked() ! {
	
	if !os.is_dir(base.path_add(base.app_path(),'script')) {
		os.mkdir(base.path_add(base.app_path(),'script'), os.MkdirParams{})!
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

	dl := Download{}

	if !os.is_file(dl.evb.path) {
		download(dl.evb.id, dl.evb.path, 'enigmavbconsole')!
	}
	if !os.is_file(dl.cli.path) {
		download(dl.cli.id, dl.cli.path, 'cli')!
	}
	if !os.is_file(dl.win32.path) {
		download(dl.win32.id, dl.win32.path, 'win32')!
	}
}

/**
 * 检查linux文件
 *
 * @return !void
 */
fn linux() ! {
	dl := Download{}
	if !os.is_file(dl.appimage.path) {
		download(dl.appimage.id, dl.appimage.path, 'appimage')!
	}
	if !os.is_file(dl.runtime.path) {
		download(dl.runtime.id, dl.runtime.path, 'runtime')!
	}
}

/**
 * 下载文件
 *
 * @param file string 文件枚举
 * @param path string 路径
 * @return !void
 */
fn download(file string, path string, depname string) ! {
	println(term.dim('安装依赖:${depname}...'))
	// 文件名
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
	os.rm(zip_file)!
}
