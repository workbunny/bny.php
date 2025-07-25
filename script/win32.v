module main

import os

// v -prod xxx
#flag windows -mwindows

fn main() {
	file := "./php.exe"
	if !os.is_file(file) {
		panic("The PHP parser file does not exist.")
	}
	mut args := os.args.clone()
	args[0] = 'index.php'
	mut process := os.new_process(file)
	process.set_args(args)
	process.create_no_window = true // 不显示窗口
	process.run()
	process.wait()
}