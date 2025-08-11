module run

import php
import composer
import os
import base
import term
import os.cmdline

struct Worker {
	dir string = base.path_add(base.app_path(), 'worker')
}

pub fn run() ! {
	check()!
	mut args := base.get_args()
	args.delete(0)

	if args.len == 0 || args[0] == '-h' {
		help()!
	} else {
		php_path := php.get_php_path()!
		mut process := os.new_process(php_path)
		mut new_arg := new_args()!
		if os.is_file(base.path_add(os.dir(new_arg[0]), 'bny.config.json')) {
			new_arg.insert(0,base.path_add(Worker{}.dir, 'run.php'))
		}
		process.set_args(new_arg)
		process.run()
		process.wait()
	}
}

/**
 * 新的参数
 *
 * @return ![]string
 */
fn new_args() ![]string {
	mut args := base.get_args()
	mut arg := cmdline.option(args, 'run', '.')
	if arg == '.' {
		arg = 'index.php'
	}
	if base.file_name_ext(arg) != 'index.php' {
		panic('入口文件必须是 index.php')
	}
	if !os.is_file(arg) {
		panic('入口文件不存在')
	}
	args.delete(0)
	args[0] = arg
	return args
}

/**
 * 检查并安装依赖
 *
 * @return !void
 */
fn check() ! {
	// 文件夹路径
	dir := Worker{}.dir
	// php 文件路径
	php_path := php.get_php_path()!
	// composer 文件路径
	composer_path := composer.get_composer_path()!
	// 判断是否存在 composer.lock 文件
	lock_file := base.path_add(dir, 'composer.lock')
	if !os.is_file(lock_file) {
		// 执行 composer install 命令
		mut process := os.new_process(php_path)
		process.set_args([composer_path, 'install', '--working-dir=${dir}'])
		process.run()
		process.wait()
	}
	// 递归设置文件夹权限
	base.chmod_all(dir, 0o755)!
}
