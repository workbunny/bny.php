module mirror

import common
import term

pub fn run() ! {
	mut args := common.get_args()
	args.delete(0)
	if args.len == 0 || args[0] == '-h' {
		common.dump('mirror')!
	} else {
		mut info := common.get_info()!
		if args[0] == 'none' {
			info.mirror = ''
			common.set_info(info)!
		}
		if args[0] == 'up' {
			println(term.blue('获取代理...'))
			mut urls := get_proxies()!
			urls = urls.filter(it != 'https://github.starrlzy.cn')
			best_url, _ := fastest_proxy(urls)!
			info.mirror = best_url + '/'
			common.set_info(info)!
			println(term.green('代理设置成功: ') + term.blue(best_url))
		}
	}
}
