module main

import os

// v -prod xxx
#flag windows -mwindows

fn main() {
	file := "./php.exe"
	if !os.is_file(file) {
		panic("The PHP parser file does not exist.")
	}
	mut process := os.new_process(file)
	process.set_args(['index.php'])
	process.create_no_window = true
	process.run()
	process.wait()
}