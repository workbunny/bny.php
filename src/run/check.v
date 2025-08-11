module run

import os
import composer
import php
import base

/**
 * 检查并安装依赖
 *
 * @return !void
 */
pub fn check_composer() ! {
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
