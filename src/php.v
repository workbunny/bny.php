module php

import base
import os
import term

pub fn run()!{
	info := base.get_info()!
	if info.php < 0 {
		println(term.red('\n您没有安装PHP!\n'))
		println(term.yellow('安装指令:'))
		println('  intg add [主键]\n')
		return
	} 
	mut ext := ""
	if info.os == "windows" {
		ext = ".exe"
	}
	cmdpath := info.php_list[info.php].path + "/php" + ext
	mut cmdargs := []string{}
	mut args := base.get_args()
	args.delete(0)
	for i in 0 .. args.len {
		cmdargs << args[i]
	}
	println("")
	os.execvp(cmdpath, cmdargs)!
}