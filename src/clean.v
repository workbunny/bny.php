module clean

import base
import term

pub fn run() ! {
	println(term.dim('清理中...'))
	base.rm_all(base.path_add(base.app_path(), 'log'))!
	println(term.green('清理完成'))
}
