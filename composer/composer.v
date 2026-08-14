module composer

import php
import common
import json
import os
import net.http
import term

pub fn run() ! {
	php.run_checked()!
	checked()!
	comp := common.Composer{}
	mut args := common.get_args()
	php_path := php.get_path()!
	args[0] = comp.path
	if os.is_file('bny.json') {
		mut file := os.read_file('bny.json')!
		bny_conf := json.decode(common.BnyConfig, file)!
		if bny_conf.ini != '' {
			args.prepend(['-c', bny_conf.ini])
		}
		for v in bny_conf.define {
			args.prepend(['-d', v])
		}
	}
	mut process := os.new_process(php_path)
	process.set_args(args)
	process.run()
	process.wait()
}

fn checked() ! {
	comp := common.Composer{}
	if !os.is_file(comp.path) {
		println(term.dim('下载composer...'))
		res := http.download_file_with_progress(comp.url, comp.path, http.DownloaderParams{
			FetchConfig: http.FetchConfig{
				allow_redirect: true
			}
		}) or {
			println(term.red('下载文件失败,未知错误~'))
			exit(1)
		}
		if res.status_code == 200 {
			println(term.green('下载完成!'))
		} else {
			println(term.red('下载文件失败,请检查网络连接'))
			exit(1)
		}
	}
}
