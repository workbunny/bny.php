module main

import os
import common
import worker
import php
import composer
import compile
import mirror

fn init() {
	php_dir := common.app_path('/php')
	cache_dir := common.app_path('/cache')
	script_dir := common.app_path('/script')
	mut arr := []string{}
	arr << php_dir
	arr << script_dir
	arr << cache_dir
	// 创建文件夹
	for i in arr {
		if os.is_dir(i) {
			common.chmod_all(i, 0o777) or { println('chmod ${i} failed') }
		} else {
			os.mkdir(i, os.MkdirParams{}) or { println('Failed to create the "${i}" directory') }
		}
	}
}

fn main() {
	args := common.get_args()
	if args.len == 0 {
		common.dump('help')!
	} else {
		match args[0] {
			'run' { worker.run()! }
			'php' { php.run()! }
			'composer' { composer.run()! }
			'compile' { compile.run()! }
			'add' { php.add_run()! }
			'search' { php.search_run()! }
			'lists' { php.lists_run()! }
			'delete' { php.delete_run()! }
			'clean' { clean()! }
			'mirror' { mirror.run()! }
			'-v' { common.dump('version')! }
			'-h' { common.dump('help')! }
			else { common.dump('help')! }
		}
	}
}

fn clean() ! {
	println('清理缓存...')
	cache_dir := common.app_path('/cache')
	common.rm_all(cache_dir)!
	println('清理完成')
}
