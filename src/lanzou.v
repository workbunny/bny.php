module lanzou

import net.http
import net.html
import json
import base
import time

struct Configs {
	href       string = 'https://www.lanzoup.com/'
	host       string = 'www.lanzoup.com'
	user_agent string = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/138.0.0.0 Safari/537.36 Edg/138.0.0.0'
}

struct Code {
mut:
	lx  int = 2
	fid string
	pg  int = 1
	t   string
	k   string
	up  int = 1
	ls  int = 1
	pwd string
}

pub struct Text{
	pub:
	icon     string
	id       string
	name_all string
	size     string
}

pub struct Lists {
pub:
	zt   int
	info string
	text []Text
}

pub struct Download {
	zt  int
	dom string
	url string
	inf int
}

/**
 * 获取验证码
 *
 * @param string str 验证地址
 * @return !Code
 */
fn get_code(str string) !Code {
	mut code := Code{}
	body := http.get_text(str)
	// 解析html
	doc := html.parse(body)
	mut script := doc.get_tags(name: 'body')[0].get_tags('script')[0].content
	// 获取js变量k
	k_query := r".*;.*var\s+_\w+\s*=\s*'(.*)';.*"
	k_match := base.preg_match(k_query, script)!
	if k_match.len > 0 {
		code.k = k_match[0]
	}
	// 获取js变量t
	t_query := r".*;.*var\s+i\w+\s*=\s*'(.*)';.*"
	t_match := base.preg_match(t_query, script)!
	if t_match.len > 0 {
		code.t = t_match[0]
	}
	// 获取参数fid
	fid_query := r".*url\s\:\s'/filemoreajax.php\?file=(.*)',.*"
	fid_match := base.preg_match(fid_query, script)!
	if fid_match.len > 0 {
		code.fid = fid_match[0]
	}
	return code
}

/**
 * 获取文件列表
 *
 * @param string str 验证地址
 * @param string pwd 密码
 * @return !Lists
 */
pub fn lists(str string, pwd string) !Lists {
	mut code := get_code(str)!
	code.pwd = pwd
	mut header := http.Header{}
	header.add(.content_type, 'application/x-www-form-urlencoded')
	configs := Configs{}
	request := http.Request{
		method:     .post
		url:        configs.href + 'filemoreajax.php?file=${code.fid}'
		host:       configs.host
		user_agent: configs.user_agent
		data:       'lx=${code.lx}&fid=${code.fid}&pg=${code.pg}&t=${code.t}&k=${code.k}&up=${code.up}&ls=${code.ls}&pwd=${code.pwd}'
		header:     header
	}
	resp := request.do()!
	if resp.status_code != 200 {
		panic('获取文件列表失败')
	}
	return json.decode(Lists, resp.body) or { panic('获取文件列表信息有误') }
}

/**
 * 获取下载地址
 *
 * @param string id 文件id
 * @return !string
 */
pub fn download(id string) !string {
	configs := Configs{}
	// 获取下载的页面链接
	page := http.get_text(configs.href + '${id}')
	time.sleep(1000000)
	page_doc := html.parse(page)
	mut page_url := page_doc
		.get_tags(name: 'body')[0]
		.get_tags('iframe')[0].attributes['src']
	// 获取下载链接
	file_k := http.get_text(configs.href + page_url)
	time.sleep(1000000)
	file_doc := html.parse(file_k)
	file_script := file_doc
		.get_tags(name: 'body')[0]
		.get_tags('script')[0].content
	js_var := base.preg_match_all(r".*var\s+(\w+)\s+=\s+'(\w+|\d+)';", file_script)!
	// println(js_var)
	query_file := base.preg_match(r".*url\s+:\s+'/ajaxm.php\?file=(\w+)',//data", file_script)![0]
	// post
	mut http_post_header := http.Header{}
	http_post_header.add(.referer, configs.href + page_url)
	http_post_header.add(.content_type, 'application/x-www-form-urlencoded')
	mut ajaxdata := ''
	mut wp_sign := ''
	for k, v in js_var[0] {
		if v == 'ajaxdata' {
			ajaxdata = js_var[1][k]
		}
		if v == 'wp_sign' {
			wp_sign = js_var[1][k]
		}
		continue
	}
	http_post := http.Request{
		method:     .post
		url:        configs.href + 'ajaxm.php?file=${query_file}'
		host:       configs.host
		user_agent: configs.user_agent
		header:     http_post_header
		data:       'action=downprocess&websignkey=${ajaxdata}&signs=${ajaxdata}&sign=${wp_sign}&websign=2&kd=1&ves=1'
	}
	time.sleep(1000000)
	resp := http_post.do()!
	if resp.status_code != 200 {
		panic('获取文件下载地址失败01')
	}
	download := json.decode(Download, resp.body) or {
		panic('获取文件下载地址信息有误')
	}
	if download.zt != 1 {
		panic('获取文件下载地址失败02')
	}
	mut download_header := http.Header{}
	download_header.add(.accept, r'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7')
	download_header.add(.accept_encoding, 'gzip, deflate, br, zstd')
	download_header.add(.accept_language, 'zh-CN,zh;q=0.9,en;q=0.8,en-GB;q=0.7,en-US;q=0.6')
	download_header.add(.cache_control, 'no-cache')
	download_header.add(.cookie, 'down_ip=1')
	download_header.add(.dnt, '1')
	download_header.add(.sec_fetch_dest, 'document')
	download_header.add(.sec_fetch_mode, 'navigate')
	download_header.add(.sec_fetch_site, 'cross-site')
	download_header.add(.sec_fetch_user, '?1')
	download_header.add(.upgrade_insecure_requests, '1')
	download_header.add(.pragma, 'no-cache')
	mut download_get := http.Request{
		method:     .get
		url:        download.dom + '/file/' + download.url
		header:     download_header
		user_agent: configs.user_agent
		host:       download.dom
		allow_redirect : false
	}
	download_get.add_custom_header('sec-ch-ua', r'"Not)A;Brand";v="8", "Chromium";v="138", "Microsoft Edge";v="138"')!
	download_get.add_custom_header('sec-ch-ua-mobile', '?0')!
	download_get.add_custom_header('sec-ch-ua-platform', '"Windows"')!
	// println(download_get)
	time.sleep(1000000)
	download_resp := download_get.do()!
	if download_resp.status_code != 302 {
		panic('获取文件下载地址失败03')
	}
	location := (download_resp.header).get(.location)!
	return location
}
