module lists

import base
import term

pub fn run()!
{
	info := base.get_info()!
	if info.php < 0 {
		println(term.red("\n您没有安装PHP!\n"))
		println(term.yellow("安装指令:"))
		println("  intg add [主键]\n")
	}else{
		println(term.yellow("已安装PHP:\n"))
		println(term.green("  主键              版本名        路径\n"))
		for item in info.php_list {
			mut selected := " "
			if info.php >=0 && info.php_list[info.php].id == item.id {
				selected = term.red("※")
			}
			println("${selected} ${item.id}      ${item.name}           ${item.path}")
		}
		println('\n')
	}
}