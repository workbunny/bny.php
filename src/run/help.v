module run


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