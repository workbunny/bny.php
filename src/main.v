module main

import base
import search
import lists
import add
import composer
import php
import compile
import os

fn init() {
	php_dir := base.path_add(base.app_path(), 'php')
	script_dir := base.path_add(base.app_path(), 'script')
	composer_file := base.path_add(base.app_path(), 'composer.phar')
	mut arr := []string{}
	arr << php_dir
	arr << script_dir
	arr << composer_file
	for i in arr {
		if os.is_dir(i) {
			base.chmod_all(i, 0o755) or { println('chmod ${i} failed') }
		}
		if os.is_file(i) {
			os.chmod(i, 0o755) or { println('chmod ${i} failed') }
		}
	}
}

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
	impdir := compile.get_impdir()!
	ext := if os.user_os() == 'windows' {
		'.exe'
	} else {
		''
	}
	phpfile := base.path_add(impdir, 'php' + ext)
	if os.is_file(phpfile) {
		os.rm(phpfile)!
	}
	apprun_dir := base.path_add(impdir,'AppRun')
	base.rm_all(apprun_dir)!
}
