module worker

import common
import php
import os
import json

pub fn run() ! {
	php.run_checked()!
	mut args := common.get_args()
	args.delete(0)
	if args.len == 0 || args[0] == '-h' {
		common.dump('run')!
	} else {
		name := args[0]
		php_path := php.get_path()!
		if os.file_ext(name) == '.json' {
			config := json.decode(common.BnyConfig, os.read_file(name)!)!
			args[0] = config.main
			if config.ini != '' {
				args << ['-c', config.ini]
			}
			for v in config.define {
				args << ['-d', v]
			}
		}
		mut process := os.new_process(php_path)
		process.set_args(args)
		process.run()
		process.wait()
	}
}
