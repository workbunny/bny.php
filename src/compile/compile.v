module compile

import base
import os
import term
import php

pub fn run() ! {
	// 验证php
	php.checked()!
	// 验证文件
	checked()!
	// 验证参数
	mut args := base.get_args()
	args.delete(0)
	if args.len == 0 || args[0] == '-h' {
		help()!
	} else {
		build()!
	}
}

/**
 * 编译项目
 *
 * @return !void
 */
fn build() ! {
	println(term.yellow('开始编译项目...'))
	if os.user_os() == 'windows' {
		evb_compile()!
	} else if os.user_os() == 'linux' {
		appimage_build()!
	}else{
		println(term.red('不支持的操作系统'))
	}
	println(term.blue('编译项目完成'))
	outfile := get_outfile()!
	println(term.green('输出文件: ' + outfile))
}
