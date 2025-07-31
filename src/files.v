module files

import net.http
import json
import os
import base

struct Http {
	url string = 'http://tool.kllxs.top/'
}

struct Res {
pub:
	code int
	msg  string
	data []struct {
	pub:
		name string
		ext  string
		type string
		size string
	}
}

/**
 * 获取文件列表
 *
 * @param string path 路径
 * @return !Res
 */
pub fn search(path string) !Res {
	text := http.get_text(Http{}.url + 'search?path=${path}')
	return json.decode(Res, text) or { panic('获取文件列表信息有误') }
}

/**
 * 获取php cli路径
 *
 * @return string
 */
pub fn path_php_cli() string {
	mut path := '/php'
	if os.user_os() == 'windows' {
		path += '/windows/x86_64/cli'
	} else if os.user_os() == 'linux' {
		path += '/linux/${base.get_machine()}/cli'
	}
	return path
}

/**
 * 下载文件
 *
 * @param string path 路径
 * @param string file 文件名
 * @param string dir 目录
 * @return !http.Response
 */
pub fn download(path string, file string, dir string) ! http.Response{
	url := Http{}.url + 'download?path=${path}&file=${file}'
	params := http.DownloaderParams{
		FetchConfig: http.FetchConfig{
			method: .post
		}
	}
	resp := http.download_file_with_progress(url, base.path_add(dir, file), params)!
	return resp
}
