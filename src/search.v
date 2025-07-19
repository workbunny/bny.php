module search

import base
import lanzou
import term

pub fn run()!
{
	mut info := base.get_info()!
	http := base.get_http(info.php_href)
	data := lanzou.lists(http[0], http[1])!
	
	if data.zt ==1{
		println(term.yellow("搜索结果:\n"))
		println(term.green("  主键              版本名        大小         类型\n"))
		for item in data.text {
			mut selected := " "
			if info.php >=0 && info.php_list[info.php].id == item.id {
				selected = term.red("※")
			}
			println("${selected} ${item.id}      ${item.name_all.replace('.'+item.icon,'')}           ${item.size}       ${item.icon}")
		}
		println('\n')
	}else{
		panic("获取列表失败!")
	}
}