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
	phar := base.path_add(base.app_path(), 'composer.phar')
	mut ext := ''
	if os.user_os() == 'windows' {
		ext = '.exe'
	}
	cmdpath := base.path_add(info.php_list[info.php].path, 'php' + ext)
	mut cmdargs := []string{}
	cmdargs << phar
	mut args := base.get_args()
	args.delete(0)
	cmdargs << args
	mut process := os.new_process(cmdpath)
	process.set_args(cmdargs)
	process.run()
	process.wait()
}

fn download() ! {
	phar := base.path_add(base.app_path(), 'composer.phar')
	mut info := base.get_info()!
	http.download_file(info.composer_href, phar)!
	info.composer = true
	base.set_info(info)!
}
