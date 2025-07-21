module php

import base
import os
import term

pub fn run() ! {
	info := base.get_info()!
	if info.php < 0 {
		println(term.red('\n您没有安装PHP!\n'))
		println(term.yellow('安装指令:'))
		println('  intg add [主键]\n')
		return
	}
	mut ext := ''
	if info.os == 'windows' {
		ext = '.exe'
	}
	cmdpath := info.php_list[info.php].path + os.path_separator + 'php' + ext
	mut process := os.new_process(cmdpath)
	mut args := base.get_args()
	args.delete(0)
	process.set_args(args)
	process.run()
	process.wait()
}
