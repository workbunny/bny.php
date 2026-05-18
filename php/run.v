module php

import common
import os

pub fn run() ! {
	run_checked()!
	mut args := common.get_args()
	args.delete(0)
	php_path := get_path()!
	mut process := os.new_process(php_path)
	process.set_args(args)
	process.run()
	process.wait()
}

/**
 * 获取php路径
 */
pub fn get_path() !string {
	info := common.get_info()!
	ext := if common.get_os_name()! == 'windows' { '.exe' } else { '' }
	return common.path_add(info.php_list[info.php].path, 'php' + ext)
}

/**
 * 检查参数
 */
pub fn run_checked() ! {
	info := common.get_info()!
	if info.php < 0 {
		common.dump('php-run')!
		exit(1)
	}
}
