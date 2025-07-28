module add

import base
import term
import os
import compress.szip
import files

pub fn run() ! {
	mut info := base.get_info()!
	checked()!
	mut args := base.get_args()
	args.delete(0)
	if args.len == 0 {
		help()!
	} else {
		name := args[0]

		for k, v in info.php_list {
			if v.name == name {
				info.php = k
				base.set_info(info)!
				println(term.green('添加成功!'))
				exit(1)
			}
		}

		println(term.dim('正在下载...'))
		dir := base.path_add(base.app_path(), 'php')
		path := files.path_php_cli()
		resp := files.download(path, name + '.zip', dir)!
		if resp.status_code != 200 {
			println(term.red('下载失败!'))
			exit(1)
		}
		println(term.dim('正在解压...'))
		size := szip.extract_zip_to_dir(base.path_add(dir, name + '.zip'), dir)!
		if !size {
			println(term.red('解压失败!请重新下载!'))
			exit(1)
		}
		info.php_list << base.Phplist{
			name: name
			path: base.path_add(base.app_path(), 'php', name)
		}
		info.php = info.php_list.len - 1
		base.set_info(info)!
		os.rm(base.path_add(dir, name + '.zip'))!
		println(term.green('添加成功!'))
	}
}

/**
 * 检查php目录
 *
 * @return !void
 */
fn checked() ! {
	path := base.path_add(base.app_path(), 'php')
	if !os.is_dir(path) {
		os.mkdir(path, os.MkdirParams{})!
	}
}

/**
 * 帮助
 *
 * @return !void
 */
fn help() !{
	info := base.get_info()!
	println(term.red('\n请输入版本号!\n'))
	println(term.yellow('安装指令:'))
	println('  ${info.name} add [版本号]\n')
}
