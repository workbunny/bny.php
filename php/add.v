module php

import common
import os
import term
import net.http
import compress.szip

pub fn add_run() ! {
	mut info := common.get_info()!
	add_checked()!
	mut args := common.get_args()
	args.delete(0)

	if args.len == 0 {
		common.dump('php-add')!
	} else {
		name := args[0]
		if name == '-h' {
			common.dump('php-add')!
		} else {
			for k, v in info.php_list {
				if v.name == name {
					info.php = k
					common.set_info(info)!
					println(term.green('添加成功!'))
					exit(1)
				}
			}
			down := download(name)!
			to_dir(down)!
		}
	}
}

/**
 * 下载php
 * @param name string
 * @return common.PhpList
 */
fn download(name string) !common.PhpList {
	// 文件夹路径
	dir_path := common.app_path('/php')
	mut sele_url := common.Url{}
	for i in get_download_list()! {
		if i.name == name {
			sele_url = i
		}
	}
	if sele_url.url == '' {
		println(term.red('未找到php版本!'))
		exit(1)
	}
	println(term.dim('正在下载,请耐心等待...'))
	info := common.get_info()!
	res := http.download_file_with_progress(info.mirror + sele_url.url, common.path_add(dir_path, '${name}.zip'),
		http.DownloaderParams{
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
	return common.PhpList{
		name: name
		path: common.path_add(dir_path, name + '.zip')
	}
}

/**
 * 解压php
 * @param item common.PhpList
 * @return !void
 */
fn to_dir(item common.PhpList) ! {
	dir := common.app_path('/php/${item.name}')
	if !os.is_dir(dir) {
		os.mkdir(dir, os.MkdirParams{})!
	}
	size := szip.extract_zip_to_dir(item.path, dir)!
	if !size {
		println(term.red('解压失败!请重新下载!'))
		exit(1)
	}
	os.rm(item.path)!
	mut info := common.get_info()!
	info.php_list << common.PhpList{
		name: item.name
		path: dir
	}
	info.php = info.php_list.len - 1
	common.set_info(info)!
	println(term.green('添加成功!'))
}

/**
 * 检查php目录是否存在
 *
 * @return !void
 */
fn add_checked() ! {
	path := common.app_path('/php')
	if !os.is_dir(path) {
		os.mkdir(path, os.MkdirParams{})!
	}
}
