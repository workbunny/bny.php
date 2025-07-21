module add

import base
import term
import lanzou
import os
import compress.szip
import net.http

pub fn run() ! {
	mut info := base.get_info()!

	if !os.is_dir(base.app_path() + os.path_separator + 'php') {
		os.mkdir(base.app_path() + os.path_separator + 'php', os.MkdirParams{})!
	}
	mut args := base.get_args()
	args.delete(0)
	if args.len == 0 {
		help()
	} else {
		id := args[0]
		mut is_lists := false
		for k, v in info.php_list {
			if v.id == id {
				is_lists = true
				info.php = k
				break
			}
		}
		if !is_lists {
			https := base.get_http(info.php_href)
			lists := lanzou.lists(https[0], https[1])!
			mut is_check := false
			mut file_name := ''
			for item in lists.text {
				if item.id == id {
					file_name = item.name_all
					is_check = true
					break
				}
			}
			if !is_check {
				panic('没有该主键的php版本!')
			}
			println(term.dim('正在安装...'))
			url := lanzou.download(id)!
			// os.write_file('./php/' + file_name, content)!
			http.download_file(url, base.app_path() + os.path_separator + 'php' +
				os.path_separator + file_name)!
			szip.extract_zip_to_dir(base.app_path() + os.path_separator + 'php' +
				os.path_separator + file_name, base.app_path() + os.path_separator + 'php')!
			info.php_list << base.Phplist{
				id:   id
				name: file_name.replace('.zip', '')
				path: base.app_path() + os.path_separator + 'php' + os.path_separator +
					file_name.replace('.zip', '')
			}
			info.php = info.php_list.len - 1
			base.set_info(info)!
			os.rm(base.app_path() + os.path_separator + 'php' + os.path_separator + file_name)!
		}
		println(term.green('添加成功!'))
	}
}

fn help() {
	println(term.red('\n请输入主键!\n'))
	println(term.yellow('安装指令:'))
	println('  intg add [主键]\n')
}
