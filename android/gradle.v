module android

import common
import compress.szip
import net.http
import os
import term

/**
 * 定位 gradle 可执行文件
 * 优先 bny 自备的 script/gradle, 其次 GRADLE_HOME / PATH, 都没有则自动下载准备
 *
 * @return gradle 可执行文件路径
 */
fn find_gradle() !string {
	// bny 自备
	mut local_bin := ''
	$if windows {
		local_bin = common.path_add(common.Dirs{}.script, 'gradle', 'bin', 'gradle.bat')
	} $else {
		local_bin = common.path_add(common.Dirs{}.script, 'gradle', 'bin', 'gradle')
	}
	if os.is_file(local_bin) {
		return local_bin
	}
	// GRADLE_HOME
	home := os.getenv('GRADLE_HOME')
	if home != '' {
		mut path := ''
		$if windows {
			path = common.path_add(home, 'bin', 'gradle.bat')
		} $else {
			path = common.path_add(home, 'bin', 'gradle')
		}
		if os.is_file(path) {
			return path
		}
	}
	// PATH
	$if windows {
		res := os.execute('where gradle.bat')
		if res.exit_code == 0 {
			for line in res.output.split('\n') {
				str := line.trim_space()
				if str != '' && os.is_file(str) {
					return str
				}
			}
		}
	} $else {
		res := os.execute('which gradle')
		if res.exit_code == 0 {
			str := res.output.trim_space()
			if str != '' && os.is_file(str) {
				return str
			}
		}
	}
	// 自动下载准备
	return download_gradle(local_bin)
}

/**
 * 自动准备 gradle 并解压到 script/gradle
 *
 * @param bin gradle 可执行文件期望路径
 * @return gradle 可执行文件路径
 */
fn download_gradle(bin string) !string {
	// 已就绪直接返回
	if os.is_file(bin) {
		return bin
	}
	zip_name := 'gradle-8.9-bin.zip'
	// zip 与解压后的 gradle/ 都放 script 目录 (与 CI 内置 zip 同一位置, clean 只清 cache 不会删)
	zip_path := common.path_add(common.Dirs{}.script, zip_name)
	if !os.is_file(zip_path) {
		println(term.dim('gradle: 未找到, 开始自动下载准备 (仅首次)...'))
		os.mkdir_all(common.Dirs{}.script)!
		url := 'https://services.gradle.org/distributions/${zip_name}'
		res := http.download_file_with_progress(url, zip_path, http.DownloaderParams{
			FetchConfig: http.FetchConfig{
				allow_redirect: true
			}
		}) or {
			println(term.red('gradle 下载失败: ${err}'))
			exit(1)
		}
		if res.status_code != 200 {
			println(term.red('gradle 下载失败, 状态码: ${res.status_code}'))
			exit(1)
		}
	} else {
		println(term.dim('gradle: 使用内置 ${zip_path}'))
	}
	// 解压 (zip 顶层为 gradle-8.9/ 目录)
	tmp_dir := common.path_add(common.Dirs{}.cache, 'gradle-extract')
	os.rmdir_all(tmp_dir) or {}
	os.mkdir_all(tmp_dir)!
	size := szip.extract_zip_to_dir(zip_path, tmp_dir)!
	if !size {
		println(term.red('gradle 解压失败!'))
		exit(1)
	}
	extracted := common.path_add(tmp_dir, 'gradle-8.9')
	if !os.is_dir(extracted) {
		println(term.red('gradle 解压结构异常: 未找到 ${extracted}'))
		exit(1)
	}
	// 移除旧的 script/gradle 目录, 防止 os.mv 覆盖失败
	gradle_dir := common.path_add(common.Dirs{}.script, 'gradle')
	os.rmdir_all(gradle_dir) or {}
	os.mv(extracted, gradle_dir)!
	os.rmdir_all(tmp_dir) or {}
	// Unix 下确保 gradle 二进制可执行 (zip 解压可能未保留权限)
	$if linux || macos {
		os.chmod(bin, 0o755) or {}
	}
	if !os.is_file(bin) {
		println(term.red('gradle 准备失败: 未找到 ${bin}'))
		exit(1)
	}
	println(term.green('gradle 准备就绪'))
	return bin
}
