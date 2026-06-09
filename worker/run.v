module worker

import common
import php
import os

pub fn run() ! {
	php.run_checked()!
	mut args := common.get_args()
	args.delete(0)
	if args.len == 0 || args[0] == '-h' {
		common.dump('run')!
	} else {
		name := args[0]
		php_path := php.get_path()!
		if name == '.' {
			bny_conf := common.get_bny_config()!
			if bny_conf.main != '' {
				args[0] = bny_conf.main
			}
			if bny_conf.ini != '' {
				args.prepend(['-c', bny_conf.ini])
			}
			for v in bny_conf.define {
				args.prepend(['-d', v])
			}
			println(args)
		}
		mut process := os.new_process(php_path)
		process.set_args(args)
		process.run()
		process.wait()
	}
}
