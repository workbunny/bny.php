module php

import term
import common

pub fn lists_run() ! {
	info := common.get_info()!
	if info.php < 0 {
		println(term.red('\n您没有安装PHP!请搜索可下载版本!\n'))
		println(term.yellow('搜索指令:'))
		println('  ${info.name} search\n')
	} else {
		println(term.yellow('已安装PHP:\n'))
		println(term.green('  版本号        路径\n'))
		for item in info.php_list {
			mut selected := ' '
			if info.php >= 0 && info.php_list[info.php].name == item.name {
				selected = term.red('※')
			}
			println('${selected} ${item.name}           ${item.path}')
		}
		println('\n')
	}
}
