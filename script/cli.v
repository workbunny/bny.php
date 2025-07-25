module main

import os

fn main() {
	// index.php 文件
	file := "./php.exe"
	if !os.is_file(file) {
		panic("The PHP parser file does not exist.")
	}
	mut args := os.args.clone()
	args[0] = 'index.php'
	mut process := os.new_process(file)
	process.set_args(args)
	process.run()
	process.wait()
}