module compile

import base
import os
import term
import compress.szip
import files

struct Url {
pub mut:
	name string
	path string
	file string
}

pub enum Download {
	// windows 所需依赖
	evb
	cli
	win32
	rcedit
	// linux 所需依赖
	appimage
	runtime
	linux
}

pub fn (dl Download) next() Url {
	match dl {
		// windows 所需依赖
		.evb {
			return Url{
				name: 'evb.zip'
				path: '/executables'
				file: base.path_add(base.Dirs{}.script, 'enigmavbconsole.exe')
			}
		}
		.rcedit {
			return Url{
				name: 'rcedit-x64.zip'
				path: '/executables'
				file: base.path_add(base.Dirs{}.script, 'rcedit-x64.exe')
			}
		}
		.cli {
			return Url{
				name: 'cli.zip'
				path: '/script'
				file: base.path_add(base.Dirs{}.script, 'cli.exe')
			}
		}
		.win32 {
			return Url{
				name: 'win32.zip'
				path: '/script'
				file: base.path_add(base.Dirs{}.script, 'win32.exe')
			}
		}
		// linux 所需依赖
		.appimage {
			return Url{
				name: 'appimagetool-${base.get_machine()}.zip'
				path: '/executables'
				file: base.path_add(base.Dirs{}.script, 'appimagetool-${base.get_machine()}.AppImage')
			}
		}
		.runtime {
			return Url{
				name: 'runtime-${base.get_machine()}.zip'
				path: '/executables'
				file: base.path_add(base.Dirs{}.script, 'runtime-${base.get_machine()}')
			}
		}
		.linux {
			return Url{
				name: 'linux.zip'
				path: '/script'
				file: base.path_add(base.Dirs{}.script, 'linux')
			}
		}
	}
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
	if !os.is_file(Download.evb.next().file) {
		download(Download.evb.next())!
	}
	if !os.is_file(Download.cli.next().file) {
		download(Download.cli.next())!
	}
	if !os.is_file(Download.win32.next().file) {
		download(Download.win32.next())!
	}
	if !os.is_file(Download.rcedit.next().file) {
		download(Download.rcedit.next())!
	}
}

/**
 * 检查linux文件
 *
 * @return !void
 */
fn linux() ! {
	if !os.is_file(Download.appimage.next().file) {
		download(Download.appimage.next())!
	}
	if !os.is_file(Download.runtime.next().file) {
		download(Download.runtime.next())!
	}
	if !os.is_file(Download.linux.next().file) {
		download(Download.linux.next())!
	}
}

/**
 * 下载文件
 *
 * @param url Url 下载地址
 * @return !void
 */
fn download(url Url) ! {
	println(term.dim('安装依赖...'))
	dir := base.Dirs{}.script
	file_name := base.path_add(dir, url.name)
	// 下载地址
	files.download(url.path, url.name, dir)!
	/* if resp.status_code != 200 {
		println(term.red('下载失败!'))
		exit(1)
	} */
	// 解压文件
	zip := szip.extract_zip_to_dir(file_name, dir)!
	// 删除压缩包文件
	os.rm(file_name)!
	if !zip {
		println(term.red('解压失败!'))
		exit(1)
	}
}


/**
 * 过滤目录
 *
 * @param path string 路径
 * @return bool 是否过滤
 */
fn filter_dir(path string) bool {
	mut none_dir := [".git","runtime","test"]
	for i in none_dir {
		if path.contains(i) {
			ind := path.index(i)or{0}
			if ind == 0 {
				return false
			}
			dir := path[0..ind+i.len]
			if os.is_dir(dir) {
				return true
			}else{
				return false
			}
		}
	}
	return false
}