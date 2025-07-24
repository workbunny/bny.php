module php

import base
import os
import term

pub fn run() ! {
	checked()!

	mut args := base.get_args()
	args.delete(0)

	cmdpath := get_php_path()!
	mut process := os.new_process(cmdpath)
	process.set_args(args)
	process.run()
	process.wait()
}

/**
 * 获取php解析器文件路径
 *
 * @return ! string
 */
pub fn get_php_path() ! string {
	info := base.get_info()!
	ext := if os.user_os() == 'windows' { '.exe' } else { '' }
	return base.path_add(info.php_list[info.php].path, 'php' + ext)
}

/**
 * 检查php文件
 *
 * @return !void
 */
pub fn checked() ! {
	info := base.get_info()!
	if info.php < 0 {
		println(term.red('\n您没有安装PHP!\n'))
		println(term.yellow('安装指令:'))
		println('  bny add [主键]\n')
		exit(1)
	}
}
