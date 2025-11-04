module main

import os
import json

// v -prod xxx
#flag windows -mwindows

// bny.json 配置文件
struct BnyConfig {
	main string = "index.php" // 入口文件
	ini_path string // ini文件路径
	php_ins []string = []string{} // php 指令
}

fn main() {
	mut file := "./php.exe"
	if !os.is_file(file) {
		panic("The PHP parser file does not exist.")
	}
	mut args := os.args.clone()
	if os.exists('bny.json') {
		// 读取 bny.json
		bny := json.decode(BnyConfig, os.read_file('bny.json')!)!
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
	mut process := os.new_process(file)
	process.set_args(args)
	process.create_no_window = true // 不显示窗口
	process.run()
	process.wait()
}