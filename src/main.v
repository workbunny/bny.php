module main

import base
import search
import lists
import add
import composer
import php
import compile

fn main() {

	info := base.get_info()!

	args_main := base.get_args()
	if args_main.len == 0 {
		base.help()!
	} else {
		match args_main[0] {
			'php' {
				php.run()!
			}
			'composer' {
				composer.run()!
			}
			'compile' {
				compile.run()!
			}
			'add' {
				add.run()!
			}
			'lists' {
				lists.run()!
			}
			'search' {
				search.run()!
			}
			'-h' {
				base.help()!
			}
			'-v' {
				println(info.version)
			}
			else {
				base.help()!
			}
		}
	}
}
