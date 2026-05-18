module main

import os
import json

// v -prod xxx
#flag windows -mwindows

// bny.json 配置文件
struct BnyConfig {
mut:
	name   string = 'index'       // 项目名称
	main   string = './index.php' // 入口文件
	icon   string   // 图标
	ini    string   // 配置文件或者目录
	define []string // 定义 和 php -d 一样
	ignore []string // 忽略的文件或者文件夹 用于打包
}

fn main() {
	mut file := 'php'
	if os.user_os() == 'windows' {
		file += '.exe'
	}
	php_file := '.' + os.path_separator + 'php' + os.path_separator + file
	mut args := os.args.clone()
	if !os.exists(php_file) {
		error('php 文件不存在')
	}
	if os.exists('bny.json') {
		bny_config := json.decode(BnyConfig, os.read_file('bny.json')!)!
		args << ['-f', bny_config.main]
		if bny_config.ini != '' {
			args << ['-c', bny_config.ini]
		}
		for d in bny_config.define {
			args << ['-d', d]
		}
	} else if os.exists('index.php') {
		args << ['-f', 'index.php']
	} else {
		error('bny.json 和 index.php 文件不存在')
	}

	mut process := os.new_process(php_file)
	process.set_args(args)
	process.create_no_window = true // 不显示窗口
	process.run()
	process.wait()
}
