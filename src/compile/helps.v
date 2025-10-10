module compile

import term
import os.cmdline
import os
import base
import json

/**
 * 获取入口文件路径
 *
 * @return !string
 */
pub fn get_impfile() ! string {
	args := base.get_args()
	mut arg := cmdline.option(args, 'compile', '')
	if arg == '.' {
		if os.exists('bny.json') {
			// 读取 bny.json
			bny := json.decode(base.BnyConfig, os.read_file('bny.json')!)!
			arg = bny.main
		}else{
			arg = './index.php'
		}
	}
	impfile := os.abs_path(arg)
	if !os.is_file(impfile) {
		panic('没有目标文件:${impfile}')
	}
	return impfile
}

/**
 * 获取入口文件目录
 *
 * @return !string
 */
pub fn get_impdir() ! string {
	mut file := os.dir(get_impfile()!)
	if os.exists('bny.json') {
		file = os.abs_path(os.dir('bny.json'))
	}
	return file
}

/**
 * 获取输出文件路径
 *
 * @return !string
 */
pub fn get_outfile() ! string {
	ext := if os.user_os() == 'windows' { '.exe' } 
		else if os.user_os() == 'macos' { '.app' } 
		else { '.bin' }
	impfile := get_impfile()!
	args := base.get_args()
	mut str := cmdline.option(args, '-o', '')
	if str == '' {
		str = base.file_name(impfile)
	}
	outfile := base.path_add(os.getwd(), str + ext)
	return outfile
}


/**
 * 是否使用终端
 *
 * @return bool
 */
pub fn is_term() bool {
	args := base.get_args()
	mut res := true
	for item in args {
		if item == '-noterm' {
			res = false
			break
		}
	}
	return res
}

/**
 * 帮助信息
 *
 * @return void
 */
pub fn help() ! {
	info := base.get_info()!
	mut arr := []string{}
	arr << term.yellow('用法:')
	arr << ''
	arr << term.green('intg compile ') + term.blue('[目标] <指令>')
	arr << ''
	arr << term.yellow('目标:')
	arr << ''
	arr << term.blue('  .                          ') + '编译当前目录'
	arr << term.blue('  [path]                     ') + '根据入口文件编译'
	arr << term.blue('  -h                         ') + '帮助查看'
	arr << ''
	arr << term.yellow('指令:')
	arr << ''
	arr << term.blue('  -noterm                     ') + '不显示终端窗口'
	arr << term.blue('  -o [name]                   ') + '编译为指定文件名'
	arr << term.blue('  -icon [file]                ') + '编译为指定图标'
	arr << ''
	arr << term.yellow('示例:')
	arr << ''
	arr << term.green('  ${info.name} compile ') + term.blue('.')
	arr << term.green('  ${info.name} compile ') + term.blue('index.php')
	println(arr.join('\n'))
}
