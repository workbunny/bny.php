module main

import base
import search
import lists
import add
import composer
import php
import compile
import os
import clean
import worker
import delete

/**
 * 初始化
 *
 * @return void
 */
fn init() {
	php_dir := base.path_add(base.app_path(), 'php')
	log_dir := base.path_add(base.app_path(), 'log')
	script_dir := base.path_add(base.app_path(), 'script')
	mut arr := []string{}
	arr << php_dir
	arr << script_dir
	arr << log_dir
	// 创建文件夹
	for i in arr {
		if os.is_dir(i) {
			base.chmod_all(i, 0o777) or { println('chmod ${i} failed') }
		} else {
			os.mkdir(i, os.MkdirParams{}) or { println('Failed to create the "${i}" directory') }
		}
	}
}

/**
 * 主函数
 *
 * @return void
 */
fn main() {
	info := base.get_info()!

	args_main := base.get_args()
	if args_main.len == 0 {
		base.help()!
	} else {
		match args_main[0] {
			'worker' {
				worker.run()!
			}
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
			'delete' {
				delete.run()!
			}
			'clean' {
				clean.run()!
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
