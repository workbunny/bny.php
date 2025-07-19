module composer

import base
import term
import net.http
import os

pub fn run() ! {
	info := base.get_info()!
	if info.php < 0 {
		println(term.red('\n您没有安装PHP!\n'))
		println(term.yellow('安装指令:'))
		println('  intg add [主键]\n')
		return
	} 
	
	if !info.composer {
		println(term.dim('安装composer...'))
		download()!
	}
	phar := base.app_path() + "/composer.phar"
	mut ext := ""
	if info.os == "windows" {
		ext = ".exe"
	}
	cmdpath := info.php_list[info.php].path + "/php" + ext
	mut cmdargs := [phar]
	mut args := base.get_args()
	args.delete(0)
	for i in 0 .. args.len {
		cmdargs << args[i]
	}
	println("")
	os.execvp(cmdpath, cmdargs)!
}

fn download() ! {
	phar := base.app_path() + "/composer.phar"
	mut info := base.get_info()!
	http.download_file(info.composer_href, phar)!
	info.composer = true
	base.set_info(info)!
}
