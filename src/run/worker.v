module run

import php
import os
import base

struct Worker {
	dir string = base.path_add(base.app_path(), 'worker')
}

pub fn run() ! {
	check_composer()!
	mut args := base.get_args()
	args.delete(0)

	if args.len == 0 || args[0] == '-h' {
		help()!
	} else {
		php_path := php.get_php_path()!
		mut process := os.new_process(php_path)
		new_arg := new_args()!
		process.set_args(new_arg)
		process.run()
		process.wait()
	}
}
