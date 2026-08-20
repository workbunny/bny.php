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

pub struct AndroidConfig {
pub mut:
	port  int    = 8787                 // 服务端口
	start string = '-S 127.0.0.1:8787 ./' // 启动命令 (默认 php 内置服务器)
	stop  string                         // 停止命令 (默认空, 前台模式直接结束进程)
	arch  string = 'all'                 // 架构: aarch64 / x86_64 / all
	ver   string = '1.0'                 // 版本名 (versionName)
	code  int    = 1                     // 版本号 (versionCode)
	sign  string                         // release 签名 CN, 等价于 -release <CN> (空则默认 name.demo.com)
}

pub struct BnyConfig {
pub mut:
	title  string // 项目显示名称(可中文), 安卓应用名/桌面应用名; 默认按 name
	name   string // 项目文件名(编译产物名); 默认按入口文件名(如 index.php -> index)
	root   string // 项目根目录(打包源目录); 指定入口文件时为入口所在目录, 默认当前目录
	main   string = './index.php' // 入口文件(相对 root)
	icon   string   // 图标
	ini    string   // 配置文件或者目录
	define []string // 定义 和 php -d 一样
	ignore []string = ['runtime/', '.git/', 'test/'] // 忽略的文件或者文件夹 用于打包
	android AndroidConfig // android 打包配置
}

/**
 * 获取项目显示名称
 * title 未配置时按 name 推导
 *
 * @param conf 配置
 * @return 显示名称
 */
pub fn (conf BnyConfig) get_title() string {
	if conf.title != '' {
		return conf.title
	}
	return conf.name
}

/**
 * 获取入口文件名(去扩展名)
 * 如 ./index.php -> index
 *
 * @param main 入口文件路径
 * @return 文件名
 */
pub fn main_name(main string) string {
	file := file_name_ext(main)
	if file.len > 4 && file[file.len - 4..] == '.php' {
		return file[..file.len - 4]
	}
	return file
}

/**
 * 获取配置信息
 *
 * @return BnyConfig 配置信息
 */
pub fn get_bny_config() !BnyConfig {
	mut args := get_args()
	args.delete(0)
	// 无位置参数(首个参数为选项)时补 '.', 统一走当前目录配置
	if args.len == 0 || args[0].starts_with('-') {
		args.insert(0, '.')
	}
	mut conf := BnyConfig{}
	if args[0] == '.' {
		// 当前目录为项目根, 读取 bny.json
		conf.root = '.'
		if os.is_file('bny.json') {
			mut file := os.read_file('bny.json')!
			conf = json.decode(BnyConfig, file)!
			conf.root = '.'
		}
	} else {
		// 指定入口文件: 入口所在目录为项目根, 入口转为相对 root 的 ./xxx.php
		if !os.is_file(args[0]) {
			return error('入口文件不存在: ${args[0]}')
		}
		p := os.real_path(args[0]).replace('\\', '/')
		conf.root = p.all_before_last('/')
		conf.main = './' + p.all_after_last('/')
	}
	if cmdline.option(args, '-icon', '') != '' {
		conf.icon = cmdline.option(args, '-icon', '')
	}
	if cmdline.option(args, '-o', '') != '' {
		conf.name = cmdline.option(args, '-o', '')
	}
	// name 默认按入口文件名推导 (如 ./index.php -> index)
	if conf.name == '' {
		conf.name = main_name(conf.main)
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
