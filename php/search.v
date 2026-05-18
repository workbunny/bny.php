module php

import common
import term

pub fn search_run() ! {
	i := common.get_info()!
	println(term.yellow('\n搜索结果:\n'))
	println(term.green('  版本号      链接\n'))
	data := get_download_list()!
	for item in data {
		mut sele := ' '
		if i.php >= 0 && i.php_list[i.php].name == item.name {
			sele = term.red('※')
		}
		println('${sele} ${item.name}       ${item.url}')
	}
	println('\n')
	println(term.yellow('安装指令:\n'))
	println('  ${i.name} add [版本号]\n')
	println(term.yellow('示例指令:\n'))
	println('  ${i.name} add 8.5')
	println('  ${i.name} add 8.4')
}
