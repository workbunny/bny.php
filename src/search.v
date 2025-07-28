module search

import files
import term
import base

pub fn run() ! {
	info := base.get_info()!
	path := files.path_php_cli()
	data := files.search(path)!
	if data.code == 0 {
		println(term.yellow('\n搜索结果:\n'))
		println(term.green('  版本号        后缀      类型      大小\n'))
		for item in data.data {
			mut selected := ' '
			if info.php >= 0 && info.php_list[info.php].name == item.name {
				selected = term.red('※')
			}
			println('${selected} ${item.name}           ${item.ext}       ${item.type}      ${item.size}')
		}
		println('\n')
		println(term.yellow('安装指令:\n'))
		println('  ${info.name} add [版本号]\n')
	}else{
		panic('获取列表失败!')
	}
}
