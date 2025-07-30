module worker

import php
import composer
import os
import base
import term

struct Worker {
	dir string = base.path_add(base.app_path(), 'server')
}

pub fn run() ! {
	check()!
	mut args := base.get_args()
	args.delete(0)

	if args.len == 0 || args[0] == '-h' {
		help()!
	} else {
		php_path := php.get_php_path()!
		mut process := os.new_process(php_path)
		mut new_args := [base.path_add(Worker{}.dir, 'main.php')]
		new_args << args
		process.set_args(new_args)
		process.run()
		process.wait()
	}
}

/**
 * 检查并安装依赖
 *
 * @return !void
 */
fn check() ! {
	// 文件夹路径
	dir := Worker{}.dir
	// php 文件路径
	php_path := php.get_php_path()!
	// composer 文件路径
	composer_path := composer.get_composer_path()!
	// 判断是否存在 composer.lock 文件
	lock_file := base.path_add(dir, 'composer.lock')
	if !os.is_file(lock_file) {
		// 执行 composer install 命令
		mut process := os.new_process(php_path)
		process.set_args([composer_path, 'install', '--working-dir=${dir}'])
		process.run()
		process.wait()
	}
	// 递归设置文件夹权限
	base.chmod_all(dir, 0o755)!
}

fn help() ! {
	info := base.get_info()!
	mut arr := []string{}
	arr << term.yellow('用法:')
	arr << ''
	arr << term.green('${info.name} worker ') + term.blue('[目标] <指令>')
	arr << ''
	arr << term.yellow('目标:')
	arr << ''
	arr << term.blue('  [dir]                      ') + '入口目录'
	arr << term.blue('  -h                         ') + '帮助查看'
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
