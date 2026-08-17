module android

import common
import compress.szip
import net.http
import os
import term

/**
 * 下载 PHP 运行时并解压到 jniLibs
 *
 * @param arch_opt 架构选项 aarch64/x86_64/all
 * @param project 工程目录
 */
fn fetch_runtime(arch_opt string, project string) ! {
	archs := if arch_opt == 'all' { ['aarch64', 'x86_64'] } else { [arch_opt] }
	// 运行时存放目录 (php/android/, 与远程仓库目录结构一致, 不会被 clean 清理)
	cache_dir := common.app_path('/php/android')
	os.mkdir_all(cache_dir)!
	for arch in archs {
		// abi 映射: aarch64 -> arm64-v8a, x86_64 -> x86_64
		abi := if arch == 'aarch64' { 'arm64-v8a' } else { 'x86_64' }
		// zip 根目录就是 .so 文件集合, 无目录层
		jni_dir := common.path_add(project, 'app', 'src', 'main', 'jniLibs', abi)
		os.mkdir_all(jni_dir)!
		mut zip_path := ''
		cached := find_cached_runtime(cache_dir, arch) or { '' }
		if cached != '' {
			// 缓存优先: 按 termux-php-*-<arch>.zip 模式找本地缓存, 避免每次查 S3
			zip_path = cached
			println(term.dim('PHP运行时: 复用缓存 ${zip_path}'))
		} else {
			url := common.get_android_url(arch)!
			// 从 presign URL 提取文件名: 取 '?' 前部分 split('/') 最后一段
			arr := url.split('?')[0].split('/')
			name := arr[arr.len - 1]
			zip_path = common.path_add(cache_dir, name)
			println(term.dim('PHP运行时: 正在下载 ${name} ...'))
			res := http.download_file_with_progress(url, zip_path, http.DownloaderParams{
				FetchConfig: http.FetchConfig{
					allow_redirect: true
				}
			}) or {
				println(term.red('${arch}: 下载运行时失败: ${err}'))
				exit(1)
			}
			if res.status_code != 200 {
				println(term.red('${arch}: 下载运行时失败, 状态码: ${res.status_code}'))
				exit(1)
			}
		}
		size := szip.extract_zip_to_dir(zip_path, jni_dir)!
		if !size {
			println(term.red('${arch}: 解压运行时失败!'))
			exit(1)
		}
		// php 二进制改名 libphp.so (AGP 的 jniLibs 只认 lib*.so 命名)
		php_bin := common.path_add(jni_dir, 'php')
		if os.is_file(php_bin) {
			os.mv(php_bin, common.path_add(jni_dir, 'libphp.so'))!
		}
		// 用 script/elfpatch 工具修补 SONAME/DT_NEEDED 与打包名不一致的问题
		elf_patch(jni_dir)!
		println(term.green('PHP运行时就绪: ${arch} -> ${abi}'))
	}
}

/**
 * 查找本地缓存的 PHP 运行时 zip
 * 按 termux-php-<版本>-<架构>.zip 模式匹配, 多版本取最高
 *
 * @param cache_dir 缓存目录
 * @param arch 架构 aarch64/x86_64
 * @return zip 路径, 无缓存时返回错误
 */
fn find_cached_runtime(cache_dir string, arch string) !string {
	mut best := ''
	mut best_ver := ''
	for f in os.ls(cache_dir)! {
		if !f.starts_with('termux-php-') || !f.ends_with('-${arch}.zip') {
			continue
		}
		ver := f['termux-php-'.len..f.len - '-${arch}.zip'.len]
		if ver.len == 0 {
			continue
		}
		if best == '' || common.compare_version(ver, best_ver) > 0 {
			best = f
			best_ver = ver
		}
	}
	if best == '' {
		return error('无缓存')
	}
	return common.path_add(cache_dir, best)
}

/**
 * 调用 script/elfpatch 工具修补 jniLibs 中 ELF 的 SONAME/DT_NEEDED
 * 工具由 CI 预编译 (同 cli/win32), 修补原因见 script/elfpatch.v 注释
 *
 * @param jni_dir jniLibs 架构目录
 */
fn elf_patch(jni_dir string) ! {
	ext := if common.get_os_name()! == 'windows' { '.exe' } else { '' }
	bin := common.path_add(common.Dirs{}.script, 'elfpatch' + ext)
	if !os.is_file(bin) {
		println(term.red('未找到 elfpatch 工具: ${bin}'))
		exit(1)
	}
	mut p := os.new_process(bin)
	p.set_args([jni_dir])
	p.run()
	p.wait()
	if p.code != 0 {
		println(term.red('elfpatch 执行失败 (exit ${p.code})'))
		exit(1)
	}
}
