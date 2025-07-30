module delete

import base
import os
import term

pub fn run() ! {
	mut info := base.get_info()!
	mut args := base.get_args()
	args.delete(0)
	if args.len == 0 {
		help()!
	} else {
		name := args[0]
		for k, v in info.php_list {
			if v.name == name {
				if info.php == k {
					println(term.red('您正在使用该版本,不能删除!'))
					println(term.red('请先切换版本后再删除!'))
					exit(1)
				}
				base.chmod_all(v.path, 0o777)!
				os.rmdir_all(v.path)!
				info.php_list.delete(k)
				if info.php_list.len == 1 {
					info.php = 0
				}else if info.php > k {
					info.php--
				}
				base.set_info(info)!
				println(term.green('删除成功!'))
				exit(1)
			}
		}
	}
}


fn help() ! {
	info := base.get_info()!
	println(term.red('\n请输入版本号!\n'))
	println(term.yellow('删除指令:'))
	println('  ${info.name} delete [版本号]\n')
}