module common

import term
import os

/**
 * 获取logo
 *
 * @return []string
 */
fn logo() []string {
	mut logo := []string{}
	logo << '
    __                        __        
   / /_  ____  __  __  ____  / /_  ____ 
  / __ \\/ __ \\/ / / / / __ \\/ __ \\/ __ \\
 / /_/ / / / / /_/ / / /_/ / / / / /_/ /
/_.___/_/ /_/\\__, (_) .___/_/ /_/ .___/ 
            /____/ /_/         /_/      
			'
	return logo
}

/**
 * 打印版本
 *
 * @return !void
 */
fn dump_version() ! {
	info := get_info()! // 配置信息
	println(info.version)
}

/**
 * 打印所有帮助信息
 *
 * @return !void
 */
fn dump_help_all() ! {
	info := get_info()! // 配置信息
	mut str := logo() // logo
	clean_size := size_format(path_size(Dirs{}.cache)!)
	// 版本
	mut version := term.green('Bny: ')
	version += info.version + ' '
	version += term.green('PHP: ')
	version += if info.php > -1 { '已安装 ' } else { term.red('未安装 ') }
	version += term.green('Composer: ')
	version += if os.is_file(Composer{}.path) { '已安装 ' } else { term.red('未安装 ') }
	version += term.green('缓存: ') + term.red(clean_size) + '\n'
	str << version
	// 用法
	mut usage := term.yellow('用法: \n')
	usage += '  bny <指令> [参数] [选项]\n\n'
	str << usage
	// 指令
	mut commands := term.yellow('指令: \n')
	commands += term.green('  run                   ') + '运行主程序\n'
	commands += term.green('  php                   ') + '运行PHP\n'
	commands += term.green('  composer              ') + '运行Composer\n'
	commands += term.green('  compile               ') + '编译项目\n'
	commands += term.green('  add                   ') + '添加/选择php版本\n'
	commands += term.green('  search                ') + '搜索php版本\n'
	commands += term.green('  lists                 ') + '查看已安装的php\n'
	commands += term.green('  delete                ') + '删除php版本\n'
	commands += term.green('  clean                 ') + '清理缓存\n'
	commands += term.green('  mirror                ') + '更新代理\n'
	commands += '\n'
	str << commands
	// 选项
	mut opt := term.yellow('选项: \n')
	opt += term.green('  -h                    ') + '显示帮助信息\n'
	opt += term.green('  -v                    ') + '显示版本信息\n'
	str << opt
	println(str.join('\n'))
}

/**
 * 打印php运行帮助信息
 *
 * @return !void
 */
fn dump_help_php_run() ! {
	info := get_info()!
	println(term.red('\n您没有安装PHP!\n'))
	println(term.yellow('安装指令:'))
	println('  ${info.name} add [版本号]\n')
}

/**
 * 打印php添加帮助信息
 *
 * @return !void
 */
fn dump_help_php_add() ! {
	info := get_info()!
	println(term.red('\n请输入版本号!\n'))
	println(term.yellow('安装指令:'))
	println('  ${info.name} add [版本号]\n')
}

/**
 * 打印php删除帮助信息
 *
 * @return !void
 */
fn dump_help_php_delete() ! {
	info := get_info()!
	println(term.red('\n请输入版本号!\n'))
	println(term.yellow('删除指令:'))
	println('  ${info.name} delete [版本号]\n')
}

/**
 * 打印代理帮助信息
 *
 * @return !void
 */
fn dump_help_mirror() ! {
	info := get_info()!
	println(term.yellow('切换代理:'))
	println(term.green('  ${info.name} mirror up             ') + '更新代理\n')
	println(term.green('  ${info.name} mirror none           ') + '清除代理\n')
}

/**
 * 打印运行帮助信息
 *
 * @return !void
 */
fn dump_help_run() ! {
	info := get_info()!
	mut arr := []string{}
	arr << term.yellow('用法:')
	arr << ''
	arr << term.green('${info.name} run ') + term.blue('[目标]')
	arr << ''
	arr << term.yellow('目标:')
	arr << ''
	arr << term.blue('  [file/config]             ') + '入口/配置文件'
	arr << term.blue('  -h                        ') + '帮助查看'
	arr << ''
	println(arr.join('\n'))
	println(term.yellow('示例:\n'))
	println('  ${info.name} run index.php')
	println('  ${info.name} run bny.json\n')
}

fn dump_help_compile() ! {
	info := get_info()!
	mut arr := []string{}
	arr << term.yellow('用法:')
	arr << ''
	arr << term.green('${info.name} compile ') + term.yellow('[目标] <指令>')
	arr << ''
	arr << term.yellow('目标:')
	arr << ''
	arr << term.green('  .                          ') + '编译当前目录'
	arr << term.green('  [path]                     ') + '根据入口文件编译'
	arr << term.green('  -h                         ') + '帮助查看'
	arr << ''
	arr << term.yellow('指令:')
	arr << ''
	arr << term.green('  -noterm                     ') + '不显示终端窗口'
	arr << term.green('  -o [name]                   ') + '编译为指定文件名'
	arr << term.green('  -icon [file]                ') + '编译为指定图标'
	arr << ''
	arr << term.yellow('示例:')
	arr << ''
	arr << '${info.name} compile ' + '.'
	arr << '${info.name} compile ' + 'index.php'
	arr << '${info.name} compile ' + 'index.php' + ' -o ' + 'app'
	println(arr.join('\n'))
}

/**
 * 打印信息
 *
 * @param str string 参数
 * @return !void
 */
pub fn dump(str string) ! {
	match str {
		'compile' { dump_help_compile()! }
		'run' { dump_help_run()! }
		'php-run' { dump_help_php_run()! }
		'php-delete' { dump_help_php_delete()! }
		'php-add' { dump_help_php_add()! }
		'version' { dump_version()! }
		'mirror' { dump_help_mirror()! }
		else { dump_help_all()! }
	}
}
