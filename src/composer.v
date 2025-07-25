module composer

import base
import term
import net.http
import os
import php

pub fn run() ! {
	cmdpath := php.get_php_path()!
	// composer.phar
	if !os.is_file(base.Composer{}.path) {
		println(term.dim('安装composer...'))
		download()!
	}
	mut args := base.get_args()
	args[0] = base.Composer{}.path
	mut process := os.new_process(cmdpath)
	process.set_args(args)
	process.run()
	process.wait()
}

/**
 * 下载composer.phar
 *
 * @return !void
 */
fn download() ! {
	http.download_file(base.Composer{}.url, base.Composer{}.path)!
	// 设置文件权限
	if os.is_file(base.Composer{}.path) {
		os.chmod(base.Composer{}.path, 0o777)!
	}
}
