module base

import os
import term
import json
import time
import regex

pub struct Phplist {
pub mut:
	id   string
	path string
	name string
}

pub struct Info {
pub mut:
	version  string = 'v0.0.1'
	php      int    = -1
	php_list []Phplist
	php_href string = if os.user_os() == 'windows' {
		'https://kingbes.lanzoub.com/b00668121g?pwd=1f0b'
	} else {
		'https://kingbes.lanzoub.com/b00668140h?pwd=bxjp'
	}
}

pub struct Composer {
pub:
	path string = path_add(app_path(), 'composer.phar')
	url  string = 'https://getcomposer.org/download/latest-stable/composer.phar'
}

pub struct Dirs {
pub:
	script string = path_add(app_path(), 'script')
	log    string = path_add(app_path(), 'log')
}

/**
 * 获取参数
 *
 * @return []string
 */
pub fn get_args() []string {
	mut args := os.args.clone()
	args.delete(0)
	return args
}

/**
 * 获取应用路径
 *
 * @return string
 */
pub fn app_path() string {
	return os.dir(os.executable())
}

/**
 * 获取logo
 *
 * @return string
 */
fn get_logo() []string {
	mut logo := []string{}
	logo << '
    __                        __        
   / /_  ____  __  __  ____  / /_  ____ 
  / __ \\/ __ \\/ / / / / __ \\/ __ \\/ __ \\
 / /_/ / / / / /_/ / / /_/ / / / / /_/ /
/_.___/_/ /_/\\__, (_) .___/_/ /_/ .___/ 
            /____/ /_/         /_/      
			'
	return logo
}

/**
 * 获取信息
 *
 * @return !Info
 */
pub fn get_info() !Info {
	mut info := Info{}
	// 文件路径
	path := path_add(app_path(), 'info.json')
	//判断文件是否存在
	if os.is_file(path) {
		mut file := os.read_file(path)!
		info = json.decode(Info, file)!
	} else {
		mut file := json.encode(info)
		os.write_file(path, file)!
	}
	return info
}

/**
 * 设置信息
 *
 * @param Info info 信息
 * @return !void
 */
pub fn set_info(info Info) ! {
	mut file := json.encode(info)
	os.write_file(path_add(app_path(), 'info.json'), file)!
}

/**
 * 帮助
 *
 * @return !void
 */
pub fn help() ! {
	info := get_info()!
	mut str := get_logo()
	// 版本
	mut version := term.green('Bny: ')
	version += info.version + ' '
	version += term.green('PHP: ')
	version += if info.php > -1 { '已安装 ' } else { term.red('未安装 ') }
	version += term.green('Composer: ')
	version += if os.is_file(Composer{}.path) { '已安装 ' } else { term.red('未安装 ') }
	version += term.blue(time.unix(os.file_last_mod_unix(os.args[0])).str()) + '\n'
	str << version
	// 用法
	mut usage := term.yellow('用法: \n')
	usage += '  bny <指令> [参数] [选项]\n\n'
	str << usage
	// 指令
	mut commands := term.yellow('指令: \n')
	commands += term.green('  php                   ') + '运行PHP\n'
	commands += term.green('  composer              ') + '运行Composer\n'
	commands += term.green('  compile               ') + '编译项目\n'
	commands += term.green('  add                   ') + '添加php版本\n'
	commands += term.green('  search                ') + '搜索php版本\n'
	commands += term.green('  lists                 ') + '查看已安装的php\n'
	commands += term.green('  clean                 ') + '清理缓存垃圾\n'
	commands += '\n'
	str << commands
	// 选项
	mut opt := term.yellow('选项: \n')
	opt += term.green('  -h                      ') + '显示帮助信息\n'
	opt += term.green('  -v                      ') + '显示版本信息\n'
	str << opt
	println(str.join('\n'))
}

/**
 * 获取http链接
 *
 * @param string url 链接
 * @return []string
 */
pub fn get_http(http string) []string {
	hrefs := http.split('?')
	url := hrefs[0]
	pwd := hrefs[1].split('=')[1]
	return [url, pwd]
}

/**
 * 正则匹配
 *
 * @param string query 正则表达式
 * @param string text 文本
 * @return []string
 */
pub fn preg_match(query string, text string) ![]string {
	mut str := []string{}
	re := regex.regex_opt(query)!
	start, _ := re.match_string(text)
	if start < 0 {
		return str
	}
	lists := re.get_group_list()
	for i in 0 .. lists.len {
		str << text[lists[i].start..lists[i].end]
	}
	return str
}

/**
 * 正则匹配所有
 *
 * @param string query 正则表达式
 * @param string text 文本
 * @return ![][]string
 */
pub fn preg_match_all(query string, text string) ![][]string {
	mut str := [][]string{}
	re := regex.regex_opt(query)!
	re.match_string(text)
	lists := re.get_group_list()
	for i in 0 .. lists.len {
		str << preg_match_id(re, text, i)
	}
	return str
}

/**
 * 正则获取所有分组
 *
 * @param regex.RE re 尺寸
 * @param string text 文本
 * @param int id 分组id
 * @return []string
 */
fn preg_match_id(re regex.RE, text string, id int) []string {
	mut str := []string{}
	mut start := 0
	mut end := text.len
	mut str_text := text
	for {
		start_t, _ := re.match_string(str_text)
		if start_t < 0 {
			break
		}
		lists := re.get_group_list()
		str << str_text[lists[id].start..lists[id].end]
		str_text = text[start + lists[id].end..end]
		start = start + lists[id].end
	}
	return str
}

/**
 * 获取文件包括扩展名
 *
 * @param string path 路径
 * @return string
 */
pub fn file_name_ext(path string) string {
	str_path := path
		.replace('/', os.path_separator)
		.replace('\\', os.path_separator)
	arr := str_path.split(os.path_separator)
	str := if arr[arr.len - 1] == '' {
		arr[arr.len - 2]
	} else {
		arr[arr.len - 1]
	}
	return str
}

/**
 * 获取文件名
 *
 * @param string path 路径
 * @return string
 */
pub fn file_name(path string) string {
	mut str := file_name_ext(path)
	mut name := str.split('.')
	if name.len == 1 {
		str = name[0]
	} else if name[name.len - 2] == '' {
		str = '.' + name[name.len - 1]
	} else {
		str = name[name.len - 2]
	}
	return str
}

/**
 * 路径添加
 *
 * @param string ...path 路径
 * @return string
 */
pub fn path_add(path ...string) string {
	mut str := ''
	for k, v in path {
		if k > 0 {
			str += os.path_separator + v
		} else {
			str += v
		}
	}
	return str
}

/**
 * 递归修改权限
 *
 * @param string path 路径
 * @param int mode 权限
 * @return !void
 */
pub fn chmod_all(path string, mode int) ! {
	// 判断是否文件
	if os.is_file(path) {
		os.chmod(path, mode)!
	}
	// 判断是否目录
	if os.is_dir(path) {
		os.chmod(path, mode)!
		mut arr := []string{}
		arr << os.ls(path)!
		for i in arr {
			chmod_all(path_add(path, i), mode)!
		}
	}
}

/**
 * 递归删除
 *
 * @param string path 路径
 * @return !void
 */
pub fn rm_all(path string) ! {
	if os.is_file(path) {
		os.rm(path)!
	}
	if os.is_dir(path) {
		mut arr := []string{}
		arr << os.ls(path)!
		for i in arr {
			rm_all(path_add(path, i))!
		}
		os.rmdir(path)!
	}
}
