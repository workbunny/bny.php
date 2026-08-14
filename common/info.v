module common

import os
import json

pub struct PhpList {
pub:
	path string
	name string
}

pub struct Info {
pub mut:
	name     string = 'bny'
	version  string = 'v0.1.1'
	php      int = -1
	php_list []PhpList
}

/**
 * 获取配置信息
 *
 * @return 应用程序信息
 */
pub fn get_info() !Info {
	mut info := Info{}
	path := app_path('/info.json')
	if os.is_file(path) {
		mut file := os.read_file(path)!
		info = json.decode(Info, file)!
	} else {
		mut file := json.encode(info)
		os.write_file(path, file)!
	}
	os.chmod(path, 0o777)!
	return info
}

/**
 * 设置配置信息
 *
 * @param Info info 应用程序信息
 * @param !void
 */
pub fn set_info(info Info) ! {
	mut file := json.encode(info)
	os.write_file(app_path('/info.json'), file)!
}
