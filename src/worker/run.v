module worker

import php
import composer
import os
import base

struct Worker {
	dir string = base.path_add(base.app_path(), 'server')
}

pub fn run() ! {
	check()!
	php_path := php.get_php_path()!
	mut process := os.new_process(php_path)
	mut args := base.get_args()
	args[0] = base.path_add(Worker{}.dir, 'main.php')
	process.set_args(args)
	process.run()
	process.wait()
}

fn check() ! {
	dir := Worker{}.dir
	php_path := php.get_php_path()!
	composer_path := composer.get_composer_path()!
	lock_file := base.path_add(dir, 'composer.lock')
	if !os.is_file(lock_file) {
		mut process := os.new_process(php_path)
		process.set_args([composer_path, 'install', '--working-dir=${dir}'])
		process.run()
		process.wait()
	}
	base.chmod_all(dir, 0o755)!
}
