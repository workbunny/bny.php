module compile

import common
import term
import php
import json
import os.cmdline
import os

pub fn run() ! {
	php.run_checked()!
	mut args := common.get_args()
	args.delete(0)
	if args.len == 0 || args[0] == '-h' {
		common.dump('compile')!
	} else {
		conf := get_data()!
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

/**
 * 获取配置信息
 *
 * @return common.BnyConfig 配置信息
 */
fn get_data() !common.BnyConfig {
	mut args := common.get_args()
	args.delete(0)
	mut conf := common.BnyConfig{}
	if args[0] == '.' || os.is_file('bny.json') {
		mut file := os.read_file('bny.json')!
		conf = json.decode(common.BnyConfig, file)!
	}
	if args[0] != '.' {
		conf.main = args[0]
	}
	conf.name = cmdline.option(args, '-o', 'index')
	conf.icon = cmdline.option(args, '-icon', '')
	return conf
}
