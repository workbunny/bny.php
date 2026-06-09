module compile

import common
import term
import php

pub fn run() ! {
	php.run_checked()!
	mut args := common.get_args()
	args.delete(0)
	if args.len == 0 || args[0] == '-h' {
		common.dump('compile')!
	} else {
		conf := common.get_bny_config()!
		match common.get_os_name()! {
			'windows' {
				windows_build(conf)!
			}
			'linux' {
				linux_build(conf)!
			}
			else {
				println(term.red('暂不支持的操作系统'))
			}
		}
	}
}
