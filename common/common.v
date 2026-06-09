module common

import os
import json
import os.cmdline

pub struct Composer {
pub:
	path string = app_path('/composer.phar')
	url  string = 'https://getcomposer.org/download/latest-stable/composer.phar'
}

pub struct Dirs {
pub:
	script string = app_path('/script')
	cache  string = app_path('/cache')
}

pub struct BnyConfig {
pub mut:
	name   string = 'index'       // 项目名称
	main   string = './index.php' // 入口文件
	icon   string   // 图标
	ini    string   // 配置文件或者目录
	define []string // 定义 和 php -d 一样
	ignore []string = ['runtime/', '.git/', 'test/'] // 忽略的文件或者文件夹 用于打包
}

/**
 * 获取配置信息
 *
 * @return BnyConfig 配置信息
 */
pub fn get_bny_config() !BnyConfig {
	mut args := get_args()
	args.delete(0)
	mut conf := BnyConfig{}
	if args[0] == '.' {
		if os.is_file('bny.json'){
			mut file := os.read_file('bny.json')!
			conf = json.decode(BnyConfig, file)!
		} else {
			conf.name = 'index'
		}
	} else {
		conf.main = args[0]
	}
	if cmdline.option(args, '-icon', '') != '' {
		conf.icon = cmdline.option(args, '-icon', '')
	}
	return conf
}

/**
 * 获取应用程序路径
 *
 * @param str 路径后缀
 * @return 应用程序路径
 */
pub fn app_path(str ?string) string {
	mut path := os.dir(os.executable())
	if str != none {
		path = path_add(path, str)
	}
	return path
}

/**
 * 获取当前执行指令路径
 * @param str 路径后缀
 * @return 应用程序路径
 */
pub fn shell_path(str ?string) string {
	mut path := os.getwd()
	if str != none {
		path = path_add(path, str)
	}
	return path
}

/**
 * 过滤路径
 * @param path 路径
 * @param ignore 忽略的路径
 * @return 是否过滤
 */
pub fn filter_path(path string, ignore []string) bool {
	for i in ignore {
		if path.contains(i) {
			ind := path.index(i) or { 0 }
			if ind == 0 {
				return false
			}
			p := path[0..ind + i.len]
			if os.is_dir(p) || os.is_file(p) {
				return true
			} else {
				return false
			}
		}
	}
	return false
}

/**
 * 路径添加
 *
 * @param path ...string 路径
 * @return 添加后的路径
 */
pub fn path_add(path ...string) string {
	mut str := ''
	for k, v in path {
		if k > 0 {
			str += os.path_separator + v
		} else {
			str += v
		}
	}
	str = str.replace('\\\\', '\\')
	str = str.replace('\\', os.path_separator)
	str = str.replace('//', os.path_separator)
	str = str.replace('\\/', os.path_separator)
	return str
}

/**
 * 获取系统架构
 *
 * @return string
 */
pub fn get_os_machine() !string {
	$if amd64 {
		return 'x86_64'
	} $else $if arm64 {
		return 'aarch64'
	} $else {
		return error('不支持该架构!')
	}
}

/**
 * 获取系统名
 *
 * @return string
 */
pub fn get_os_name() !string {
	return $if windows {
		'windows'
	} $else $if linux {
		'linux'
	} $else $if macos {
		'macos'
	} $else {
		error('不支持该系统')
	}
}

/**
 * 获取文件包括扩展名
 *
 * @param string path 路径
 * @return string
 */
pub fn file_name_ext(path string) string {
	str_path := path
		.replace('/', os.path_separator)
		.replace('\\', os.path_separator)
	arr := str_path.split(os.path_separator)
	str := if arr[arr.len - 1] == '' {
		arr[arr.len - 2]
	} else {
		arr[arr.len - 1]
	}
	return str
}

/**
 * 格式化大小
 *
 * @param u64 size 大小
 * @return string
 */
pub fn size_format(size u64) string {
	mut str := ''
	if size > 1024 * 1024 * 1024 {
		str = '${(size / 1024 / 1024 / 1024).str()}GB'
	} else if size > 1024 * 1024 {
		str = '${(size / 1024 / 1024).str()}MB'
	} else if size > 1024 {
		str = '${(size / 1024).str()}KB'
	} else {
		str = '${size.str()}B'
	}
	return str
}

/**
 * 获取路径大小
 *
 * @param string path 路径
 * @return !u64
 */
pub fn path_size(path string) !u64 {
	mut size := u64(0)
	// 判断是否文件
	if os.is_file(path) {
		size += os.file_size(path)
	}
	// 判断是否目录
	if os.is_dir(path) {
		mut arr := []string{}
		arr << os.ls(path)!
		for i in arr {
			size += path_size(path_add(path, i))!
		}
	}
	return size
}

/**
 * 递归修改权限
 *
 * @param string path 路径
 * @param int mode 权限
 * @return !void
 */
pub fn chmod_all(path string, mode int) ! {
	// 判断是否文件
	if os.is_file(path) {
		os.chmod(path, mode)!
	}
	// 判断是否目录
	if os.is_dir(path) {
		os.chmod(path, mode)!
		mut arr := []string{}
		arr << os.ls(path)!
		for i in arr {
			chmod_all(path_add(path, i), mode)!
		}
	}
}

/**
 * 递归删除
 *
 * @param string path 路径
 * @return !void
 */
pub fn rm_all(path string) ! {
	if os.is_file(path) {
		os.rm(path)!
	}
	if os.is_dir(path) {
		mut arr := []string{}
		arr << os.ls(path)!
		for i in arr {
			rm_all(path_add(path, i))!
		}
		os.rmdir(path)!
	}
}
