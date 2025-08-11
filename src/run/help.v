module run

import base
import term
import os.cmdline
import os

/**
 * 新的参数
 *
 * @return ![]string
 */
pub fn new_args() ![]string {
	mut args := base.get_args()
	arg := cmdline.option(args, 'run', '')
	args.delete(0)
	if arg == '' {
		panic('请指定目标')
	}
	if arg == '.' {
		if os.is_file(base.path_add(os.getwd(), 'bny.config.json')) {
			args[0] = base.path_add(Worker{}.dir, 'run.php')
			args.insert(1, base.path_add(os.getwd(), 'bny.config.json'))
		} else {
			args[0] = 'index.php'
		}
	}
	return args
}

pub fn help() ! {
	info := base.get_info()!
	mut arr := []string{}
	arr << term.yellow('用法:')
	arr << ''
	arr << term.green('${info.name} run ') + term.blue('[目标] <指令>')
	arr << ''
	arr << term.yellow('目标:')
	arr << ''
	arr << term.blue('  [file]                    ') + 'index.php 入口文件'
	arr << term.blue('  -h                        ') + '帮助查看'
	arr << ''
	arr << term.yellow('指令:') + term.dim('Linux 指令')
	arr << ''
	arr << term.blue('  start                     ') + '启动服务'
	arr << term.blue('  stop                      ') + '停止服务'
	arr << term.blue('  restart                   ') + '重启服务'
	arr << term.blue('  status                    ') + '查看服务状态'
	arr << term.blue('  reload                    ') + '重新加载服务'
	arr << term.blue('  connections               ') + '查看连接数'
	arr << ''
	println(arr.join('\n'))
}