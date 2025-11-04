module run

import base
import term
import os.cmdline
import os
import json

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
		//判断 bny.json 是否存在
		if os.exists('bny.json') {
			// 读取 bny.json
			bny := json.decode(base.BnyConfig, os.read_file('bny.json')!)!
			args[0] = bny.main
			if bny.php_ins.len > 0 {
				args.insert(0,bny.php_ins)
			}
			if bny.ini_path != '' {
				args.insert(0,['-c',bny.ini_path])
			}
		}else{
			args[0] = 'index.php'
		}
	}
	for i, v in args {
		if v == '-v' {
			if args[i+1] != '' {
				args.delete(i+1)
			}
			args.delete(i)
			break
		}
	}
	return args
}

/**
 * 获取php解析器文件路径
 *
 * @return ! string
 */
pub fn get_php_path() !string {
	info := base.get_info()!
	args := base.get_args()
	ver := cmdline.option(args, '-v', info.php_list[info.php].name)
	mut index := -1
	for k, v in info.php_list {
		if v.name == ver {
			index = k
			break
		}
	}
	ext := if os.user_os() == 'windows' { '.exe' } else { '' }
	return base.path_add(info.php_list[index].path, 'php' + ext)
}

/**
 * 帮助查看
 *
 * @return !
 */
pub fn help() ! {
	info := base.get_info()!
	mut arr := []string{}
	arr << term.yellow('用法:')
	arr << ''
	arr << term.green('${info.name} run ') + term.blue('[目标] <指令>')
	arr << ''
	arr << term.yellow('目标:')
	arr << ''
	arr << term.blue('  [file]                    ') + '入口文件'
	arr << term.blue('  -v [number]               ') + '指定PHP版本号'
	arr << term.blue('  -h                        ') + '帮助查看'
	arr << ''
	println(arr.join('\n'))
}