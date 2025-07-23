module main

import base
import search
import lists
import add
import composer
import php
import compile
import os

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

/**
 * 清理
 *
 * @return !void
 */
fn cleanup() ! {
	// 入口文件路径
	impfile := compile.get_impfile()!
	if os.user_os() == 'windows' {
		phpfile := base.path_add(os.dir(impfile),'php.exe')
		if os.is_file(phpfile) {
			os.rm(phpfile)!
		}
	}
}