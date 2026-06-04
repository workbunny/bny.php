module common

import os
import json

pub struct PhpList {
pub:
	path string
	name string
}

pub struct Url {
pub mut:
	url  string
	name string
}

pub struct Arch {
pub:
	x86_64  []Url
	aarch64 []Url
}

pub struct Os {
pub:
	windows []Url
	linux   Arch
	macos   []Url
}

pub struct Info {
pub mut:
	name     string = 'bny'
	version  string = 'v0.0.7'
	mirror   string
	php      int = -1
	php_list []PhpList
	url      Os
}

/**
 * 获取配置信息
 *
 * @return 应用程序信息
 */
pub fn get_info() !Info {
	mut info := Info{
		url: Os{
			windows: [
				Url{
					url:  'https://github.com/KingBes/static-php-cli/releases/download/download/php-8.5.6-nts-Win32-vs17-x64.zip'
					name: '8.5'
				},
				Url{
					url:  'https://github.com/KingBes/static-php-cli/releases/download/download/php-8.4.21-nts-Win32-vs17-x64.zip'
					name: '8.4'
				},
				Url{
					url:  'https://github.com/KingBes/static-php-cli/releases/download/download/php-8.3.31-nts-Win32-vs16-x64.zip'
					name: '8.3'
				},
				Url{
					url:  'https://github.com/KingBes/static-php-cli/releases/download/download/php-8.2.31-nts-Win32-vs16-x64.zip'
					name: '8.2'
				},
			]
			linux:   Arch{
				x86_64:  [
					Url{
						url:  'https://github.com/KingBes/static-php-cli/releases/download/download/php-cli-8.4-linux-x86_64-glibc.zip'
						name: '8.4'
					},
					Url{
						url:  'https://github.com/KingBes/static-php-cli/releases/download/download/php-cli-8.3-linux-x86_64-glibc.zip'
						name: '8.3'
					},
					Url{
						url:  'https://github.com/KingBes/static-php-cli/releases/download/download/php-cli-8.2-linux-x86_64-glibc.zip'
						name: '8.2'
					},
				]
				aarch64: [
					Url{
						url:  'https://github.com/KingBes/static-php-cli/releases/download/download/php-cli-8.4-linux-aarch64-glibc.zip'
						name: '8.4'
					},
					Url{
						url:  'https://github.com/KingBes/static-php-cli/releases/download/download/php-cli-8.3-linux-aarch64-glibc.zip'
						name: '8.3'
					},
					Url{
						url:  'https://github.com/KingBes/static-php-cli/releases/download/download/php-cli-8.2-linux-aarch64-glibc.zip'
						name: '8.2'
					},
				]
			}
			macos:   [
				Url{
					url:  'https://github.com/KingBes/static-php-cli/releases/download/download/php-8.4-macos-aarch64.zip'
					name: '8.4'
				},
				Url{
					url:  'https://github.com/KingBes/static-php-cli/releases/download/download/php-8.3-macos-aarch64.zip'
					name: '8.3'
				},
				Url{
					url:  'https://github.com/KingBes/static-php-cli/releases/download/download/php-8.2-macos-aarch64.zip'
					name: '8.2'
				},
				Url{
					url:  'https://github.com/KingBes/static-php-cli/releases/download/download/php-8.1-macos-aarch64.zip'
					name: '8.1'
				},
			]
		}
	}
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
