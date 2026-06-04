module mirror

import net.http
import regex
import time
import term

/**
 * 单个代理测试结果
 */
struct ProxyResult {
	url  string
	time f64 // 响应耗时(秒)，-1 表示失败
}

/**
 * 获取https代理列表
 */
pub fn get_proxies() ![]string {
	text := http.get_text('https://raw.githubusercontent.com/oopsunix/ghproxy-web/main/static/js/mirrors.js')
	mut re := regex.regex_opt(r'(https?://[^"]+)')!
	matches := re.find_all_str(text)
	return matches
}

const worker_count = 10 // 并发工作线程数
const timeout_sec = 3 // 单个请求超时(秒)

// git 测试文件：用来验证代理是否能真正代理 GitHub 内容
const git_test_path = 'https://raw.githubusercontent.com/oopsunix/ghproxy-web/main/static/js/mirrors.js'

/**
 * HTTP 请求子协程：把耗时发给 channel（-1=失败/无效响应）
 */
fn do_request(url string, result_ch chan f64) {
	start := time.now()
	resp := http.get(url) or {
		result_ch <- -1.0
		return
	}
	// 过滤 Worker 错误页等无效响应
	if resp.body.contains('cfworker error') || resp.body.len < 100 {
		result_ch <- -1.0
		return
	}
	result_ch <- (time.now() - start).seconds()
}

/**
 * 测试单个 URL，返回响应秒数：>0=成功  -1=失败  -2=超时
 */
fn test_one(url string) f64 {
	result_ch := chan f64{cap: 1}
	spawn do_request(url, result_ch)

	for _ in 0 .. timeout_sec * 10 {
		if result_ch.len > 0 {
			return <-result_ch
		}
		time.sleep(100 * time.millisecond)
	}
	return -2.0 // 超时
}

/**
 * 工作线程：按 step 步进分发 URL，逐个测试
 */
fn worker(urls []string, start int, step int, ch chan ProxyResult) {
	for i := start; i < urls.len; i += step {
		url := urls[i]
		// 真正测试代理能力：通过代理请求 GitHub 文件
		test_url := '${url}/${git_test_path}'
		elapsed := test_one(test_url)

		if elapsed == -2.0 {
			println(term.blue('  [SLOW] ${url} (>${timeout_sec}s)'))
			ch <- ProxyResult{url, -1.0}
		} else if elapsed < 0 {
			println(term.red('  [FAIL] ${url}'))
			ch <- ProxyResult{url, -1.0}
		} else {
			ch <- ProxyResult{url, elapsed}
		}
	}
}

/**
 * 获取最快的代理（工作池模式）
 */
pub fn fastest_proxy(urls []string) !(string, f64) {
	if urls.len == 0 {
		return error('empty proxy list')
	}

	ch := chan ProxyResult{cap: urls.len}

	// 只启动固定数量的 worker，避免爆炸式并发
	wc := if urls.len < worker_count { urls.len } else { worker_count }
	for w in 0 .. wc {
		spawn worker(urls, w, wc, ch)
	}

	// 收集结果
	mut fastest_url := ''
	mut fastest_time := f64(999999.0)
	mut success := false

	for _ in 0 .. urls.len {
		result := <-ch
		if result.time < 0 {
			continue
		}
		success = true
		println(term.green('  [OK]   ${result.url}  \t${result.time:.3f}s'))
		if result.time < fastest_time {
			fastest_time = result.time
			fastest_url = result.url
		}
	}

	if !success {
		return error('no proxy available')
	}

	return fastest_url, fastest_time
}