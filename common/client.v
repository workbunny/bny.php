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
	access_key_id:     '__R2_ACCESS_KEY_ID__'
	secret_access_key: '__R2_SECRET_ACCESS_KEY__'
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