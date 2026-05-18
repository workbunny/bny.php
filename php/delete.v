module php

import common
import term
import os

pub fn delete_run() ! {
	mut info := common.get_info()!
	mut args := common.get_args()
	args.delete(0)
	if args.len == 0 {
		common.dump('php-delete')!
	} else {
		name := args[0]
		if name == '-h' {
			common.dump('php-delete')!
			exit(1)
		}
		for k, v in info.php_list {
			if v.name == name {
				if info.php == k {
					println(term.red('您正在使用该版本,不能删除!'))
					println(term.red('请先切换版本后再删除!'))
					exit(1)
				}
				os.rmdir_all(v.path)!
				info.php_list.delete(k)
				if info.php_list.len == 1 {
					info.php = 0
				}else if info.php > k {
					info.php--
				}
				common.set_info(info)!
				println(term.green('删除成功!'))
				exit(1)
			}
		}
		println(term.red('未找到该版本!'))
	}
}
