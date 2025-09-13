module main

import os

fn main() {
	// index.php 文件
	mut file := "./php"
	if os.user_os() == 'windows' {
		file += '.exe'
	}
	if !os.is_file(file) {
		panic("The PHP parser file does not exist.")
	}
	mut args := os.args.clone()
	args[0] = 'index.php'
	if os.is_file("./php.ini"){
		args << ["-c","./php.ini"]
	}
	mut process := os.new_process(file)
	process.set_args(args)
	process.run()
	process.wait()
}