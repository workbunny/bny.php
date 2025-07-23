module compile

import term
import os.cmdline
import os
import base

/**
 * 获取入口文件路径
 *
 * @return !string
 */
pub fn get_impfile() ! string {
	args := base.get_args()
	mut arg := cmdline.option(args, 'compile', '')
	if arg == '.' {
		arg = './index.php'
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
	return os.dir(get_impfile()!)
}

/**
 * 获取输出文件路径
 *
 * @return !string
 */
pub fn get_outfile() ! string {
	ext := if os.user_os() == 'windows' { '.exe' } else { '.bin' }
	impfile := get_impfile()!
	args := base.get_args()
	mut str := cmdline.option(args, '-o', '')
	if str == '' {
		str = base.file_name(impfile)
	}
	outfile := base.path_add(os.dir(impfile), str + ext)
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
pub fn help() {
	mut arr := []string{}
	arr << term.yellow('用法:')
	arr << ''
	arr << term.green('intg compile ') + term.blue('[目标] <指令>')
	arr << ''
	arr << term.yellow('目标:')
	arr << ''
	arr << term.blue('  .                          ') + '编译项目'
	arr << term.blue('  [file]                     ') + '编译php/phar文件'
	arr << term.blue('  -h                         ') + '编译目录下所有文件'
	arr << ''
	arr << term.yellow('指令:')
	arr << ''
	arr << term.blue('  -noterm                     ') + '不使用终端'
	arr << term.blue('  -o [name]                   ') + '编译为指定文件名'
	arr << ''
	arr << term.yellow('示例:')
	arr << ''
	arr << term.green('  intg compile ') + term.blue('test.php')
	arr << term.green('  intg compile ') + term.blue('test.phar')
	println(arr.join('\n'))
}
