module php

import common

/**
 * 获取下载列表
 *
 * @return []common.Url
 */
pub fn get_download_list() ![]common.Url {
	i := common.get_info()!
	mut data := []common.Url{}
	if common.get_os_name()! == 'windows' {
		data = i.url.windows.clone()
	} else if common.get_os_name()! == 'linux' {
		if common.get_os_machine()! == 'x86_64' {
			data = i.url.linux.x86_64.clone()
		} else {
			data = i.url.linux.aarch64.clone()
		}
	} else {
		data = i.url.macos.clone()
	}
	return data
}
