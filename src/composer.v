module composer

import base
import term
import files
import os
import php

pub fn run() ! {
	cmdpath := php.get_php_path()!
	// composer.phar
	mut args := base.get_args()
	args[0] = get_composer_path()!
	mut process := os.new_process(cmdpath)
	process.set_args(args)
	process.run()
	process.wait()
}

/**
 * 获取composer.phar路径
 *
 * @return !string
 */
pub fn get_composer_path() !string {
	str := base.Composer{}.path
	if !os.is_file(base.Composer{}.path) {
		println(term.dim('安装composer...'))
		download_file()!
	}
	return str
}

/**
 * 下载composer.phar
 *
 * @return !void
 */
fn download_file() ! {
	files.download_file(base.Composer{}.url, base.Composer{}.path)!
	// 设置文件权限
	if os.is_file(base.Composer{}.path) {
		os.chmod(base.Composer{}.path, 0o777)!
	}
}
