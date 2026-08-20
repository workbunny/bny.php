module common

import net.s3
import regex
import term

struct Lists {
	name string
	size i64
}

const client = s3.new_client(s3.Credentials{
	endpoint:          'https://07cdb9614bf61acdd41411c8d123d08c.r2.cloudflarestorage.com'
	access_key_id:     '9d8c6ad2bb2a231b8f9217ebe0e9ac9a'
	secret_access_key: '98c6d2c61540265f14c9ebfc58a0949da0ca9e097241460c6e25d5148f3ed030'
	bucket:            'bny-php'
	region:            'auto'
})

// 打印搜索列表
pub fn php_search(name string)! 
{
	str := get_os_with()!
	list := client.list(s3.ListOptions{
        max_keys: 50
    })!
	for obj in list.objects {
		key := obj.key
		if key.starts_with(str) {
			versions := get_version_regex(key)
			if versions == '' {
				continue
			}
			mut selected := ' '
			if name != '' && versions.starts_with(name) {
				selected = term.red('※')
			}
			println('${selected} ${versions}      ${obj.size}')
		}
	}
}

// 获取下载链接
pub fn get_clinet_url(version string) !string {
	str := get_os_with()!
	list := client.list(s3.ListOptions{
		max_keys: 50
	})!
	mut find_key := ''
	for obj in list.objects {
		key := obj.key
		if !key.starts_with(str) {
			continue
		}
		versions := get_version_regex(key)
		if versions == '' {
			continue
		}
		if versions == version {
			find_key = key
			break
		}
		if find_key == '' && versions.starts_with(version) {
			find_key = key
		}
	}
	if find_key == '' {
		return error('未找到php版本: ${version}')
	}
	url := client.presign(find_key, expires_in: 360)!
	return url
}

fn get_os_with() !string
{
	// 当前系统
	os_name := get_os_name()!
	os_machine := get_os_machine()!
	mut str := 'php/${os_name}'
	if os_name == 'linux' {
		str = str + '/${os_machine}'
	}
	return str
}

// 获取php版本号
fn get_version_regex(path string) string
{
    // 匹配 php- 后的版本号：至少两段数字，支持多段修订号
    mut re := regex.regex_opt(r'php-(\d+\.\d+(?:\.\d+)*)') or { return '' }
    start, _ := re.find(path)
    if start == -1 {
        return ''
    }
    // 注意: V 的 regex 分组编号从 0 开始(0 = 第一个捕获组)
    gs, ge := re.get_group_bounds_by_id(0)
    if gs >= 0 && ge > gs {
        return path[gs..ge]
    }
    return ''
}

// 获取 android php 运行时下载链接
// 列出 php/android/ 前缀对象, 按 termux-php-<版本>-<架构>.zip 匹配指定架构, 多版本取最高
pub fn get_android_url(arch string) !string {
	list := client.list(s3.ListOptions{
		max_keys: 100
	})!
	// 匹配 termux-php-<版本>-<架构>.zip 的正则 (raw 字符串不支持插值, 用拼接)
	pattern := r'termux-php-(\d+\.\d+(?:\.\d+)*)-' + arch + r'\.zip$'
	mut re := regex.regex_opt(pattern) or { return error('正则编译失败') }
	mut find_key := ''
	mut find_version := ''
	for obj in list.objects {
		key := obj.key
		// 只要 php/android/ 前缀的对象
		if !key.starts_with('php/android/') {
			continue
		}
		start, _ := re.find(key)
		if start == -1 {
			continue
		}
		// 注意: V 的 regex 分组编号从 0 开始(0 = 第一个捕获组)
		gs, ge := re.get_group_bounds_by_id(0)
		if gs < 0 || ge <= gs {
			continue
		}
		version := key[gs..ge]
		// 多版本取最高
		if find_version == '' || compare_version(version, find_version) > 0 {
			find_version = version
			find_key = key
		}
	}
	if find_key == '' {
		return error('未找到android php运行时: ${arch}')
	}
	url := client.presign(find_key, expires_in: 360)!
	return url
}

// 比较版本号 按 . 拆成数字逐段比较
// 返回 1 表示 a>b, -1 表示 a<b, 0 表示相等 (如 8.5.1 > 8.5 > 8.4.9)
pub fn compare_version(a string, b string) int {
	arr_a := a.split('.')
	arr_b := b.split('.')
	length := if arr_a.len > arr_b.len { arr_a.len } else { arr_b.len }
	for i in 0 .. length {
		na := if i < arr_a.len { arr_a[i].int() } else { 0 }
		nb := if i < arr_b.len { arr_b[i].int() } else { 0 }
		if na > nb {
			return 1
		} else if na < nb {
			return -1
		}
	}
	return 0
}