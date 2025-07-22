module main

import os

fn main() {
	file:= if os.user_os() == 'windows' {
		'./php.exe'
	} else {
		'./php'
	}
	if !os.is_file(file) {
		panic("The PHP parser file does not exist.")
	}
	mut process := os.new_process(file)
	process.set_args(['index.php'])
	process.run()
	process.wait()
}