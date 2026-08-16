module android

import common
import compress.szip
import crypto.md5
import json
import net.http
import os
import os.cmdline
import term
import time

// 运行时配置文件 (app/src/main/assets/runtime.json)
struct RuntimeJson {
	port   int       // 服务端口
	start  string    // 启动命令
	stop   string    // 停止命令
	ini    string    // php 配置文件 (复用 bny.json 的 ini)
	define []string // php 运行参数 (复用 bny.json 的 define)
}

// payload 清单文件 (app/src/main/assets/payload_manifest)
struct ManifestJson {
	hash string // 清单哈希
}

pub fn run() ! {
	mut args := common.get_args()
	args.delete(0) // 去掉 android
	if args.len == 0 {
		common.dump('android')!
		return
	}
	if args.contains('-h') {
		common.dump('android')!
		return
	}
	// 读取配置 (无位置参数时内部补 '.', 走当前目录 bny.json)
	conf := common.get_bny_config()!
	// 选项优先级: 命令行选项 > bny.json android 块 > 默认值
	arch_opt := cmdline.option(args, '-arch', conf.android.arch)
	if arch_opt !in ['aarch64', 'x86_64', 'all'] {
		println(term.red('不支持的架构: ${arch_opt}, 可选: aarch64 / x86_64 / all'))
		return
	}
	release := args.contains('-release')
	ver := cmdline.option(args, '-ver', conf.android.ver)
	code := cmdline.option(args, '-code', conf.android.code.str())
	println(term.green('开始打包 Android 项目...'))
	// 环境预检
	checked()
	// 组装临时工程
	project := build_project(conf)!
	// 品牌定制
	apply_brand(conf, project)!
	// 下载 PHP 运行时
	fetch_runtime(arch_opt, project)!
	// gradle 构建
	typ := if release { 'release' } else { 'debug' }
	apk := gradle_build(project, release, ver, code)!
	// 收集产物
	collect(apk, conf, typ, ver)
}

/**
 * 环境预检
 * 逐项检查 JAVA_HOME / ANDROID_HOME, 任一缺失打印错误并退出
 * (gradle 由 bny 自动准备, 无需用户配置)
 */
fn checked() {
	// JAVA_HOME 检查
	java_home := os.getenv('JAVA_HOME')
	if java_home == '' {
		println(term.red('JAVA_HOME 未设置, 请配置 JDK 17+, 示例: set JAVA_HOME=C:\\path\\to\\jdk'))
		exit(1)
	}
	mut java_bin := ''
	$if windows {
		java_bin = common.path_add(java_home, 'bin', 'java.exe')
	} $else {
		java_bin = common.path_add(java_home, 'bin', 'java')
	}
	if !os.is_file(java_bin) {
		println(term.red('JAVA_HOME 无效, 未找到: ${java_bin}, 请配置 JDK 17+'))
		exit(1)
	}
	// ANDROID_HOME 检查
	android_home := os.getenv('ANDROID_HOME')
	if android_home == '' || !os.is_dir(android_home) {
		println(term.red('ANDROID_HOME 未设置或无效, 需 Android SDK(platform 34 + build-tools 34), 示例: set ANDROID_HOME=C:\\path\\to\\android-sdk'))
		exit(1)
	}
}

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

/**
 * 组装临时 gradle 工程
 *
 * @param conf 配置
 * @return 工程目录
 */
fn build_project(conf common.BnyConfig) !string {
	// 唯一临时目录 (毫秒时间戳, 已存在则等待重试, 防止同秒/同毫秒打包冲突)
	mut dir := ''
	for {
		dir = common.path_add(common.Dirs{}.cache, time.now().unix_milli().str() + '-android')
		if !os.exists(dir) {
			break
		}
		time.sleep(2 * time.millisecond)
	}
	// 复制壳模板
	os.cp_all(common.app_path('/script/android'), dir, true)!
	// 铺项目文件到 assets/app (指定入口文件时, 入口所在目录为项目根)
	assets_app := common.path_add(dir, 'app', 'src', 'main', 'assets', 'app')
	os.mkdir_all(assets_app)!
	copy_project(conf.root, assets_app, conf.ignore)!
	// 复制壳模板自带的 payload_extra
	os.cp_all(common.path_add(dir, 'payload_extra', 'usr'), common.path_add(dir, 'app',
		'src', 'main', 'assets', 'usr'), true)!
	// runtime.json (ini/define 复用 bny.json 顶层配置)
	os.write_file(common.path_add(dir, 'app', 'src', 'main', 'assets', 'runtime.json'),
		json.encode(RuntimeJson{ port: conf.android.port, start: conf.android.start, stop: conf.android.stop, ini: conf.ini, define: conf.define }))!
	// payload_manifest
	write_manifest(dir)!
	// local.properties
	write_local_properties(dir)!
	println('工程目录:${dir}')
	return dir
}

/**
 * 递归复制项目文件
 * 过滤隐藏文件与 ignore 规则
 *
 * @param src 源目录(项目根)
 * @param dst 目标目录
 * @param ignore 忽略规则
 */
fn copy_project(src string, dst string, ignore []string) ! {
	copy_project_rel(src, dst, '', ignore)!
}

/**
 * 递归复制项目文件 (携带项目根相对路径用于 ignore 匹配)
 *
 * @param src 源目录
 * @param dst 目标目录
 * @param rel 相对项目根路径
 * @param ignore 忽略规则
 */
fn copy_project_rel(src string, dst string, rel string, ignore []string) ! {
	for i in os.ls(src)! {
		// 隐藏文件跳过
		if i.starts_with('.') {
			continue
		}
		// ignore 规则过滤 (按项目根相对路径匹配, 与 compile 一致)
		entry := if rel == '' { i } else { '${rel}/${i}' }
		if filter_ignore(entry, ignore) {
			println('[忽略]:' + entry)
			continue
		}
		src_path := common.path_add(src, i)
		dst_path := common.path_add(dst, i)
		println('[打包]:' + src_path + ' -> ' + dst_path)
		if os.is_dir(src_path) {
			os.mkdir_all(dst_path)!
			copy_project_rel(src_path, dst_path, entry, ignore)!
		} else {
			os.cp(src_path, dst_path)!
		}
	}
}

/**
 * ignore 规则匹配
 * 纯名称(如 runtime/)匹配任意层级; 含路径(如 vendor/pkg)按项目根前缀匹配
 *
 * @param rel 相对项目根路径
 * @param ignore 忽略规则
 * @return 是否忽略
 */
fn filter_ignore(rel string, ignore []string) bool {
	segs := rel.split('/')
	for pattern in ignore {
		p := pattern.replace('\\', '/').trim('/')
		if p == '' {
			continue
		}
		if p.contains('/') {
			// 含路径层级: 前缀匹配
			if rel == p || rel.starts_with(p + '/') {
				return true
			}
		} else {
			// 纯名称: 任意一层命中即忽略
			for s in segs {
				if s == p {
					return true
				}
			}
		}
	}
	return false
}

/**
 * 生成 payload 清单
 * 递归计算 assets/app 与 assets/usr 每个文件的 md5, 按路径排序拼接后整体再 md5
 *
 * @param project 工程目录
 */
fn write_manifest(project string) ! {
	assets_dir := common.path_add(project, 'app', 'src', 'main', 'assets')
	// 相对 assets/ 的路径 -> 文件 md5
	mut files := map[string]string{}
	for sub in ['app', 'usr'] {
		dir := common.path_add(assets_dir, sub)
		if !os.is_dir(dir) {
			continue
		}
		manifest_files(dir, sub, mut files)!
	}
	// 按路径排序累积
	mut keys := files.keys()
	keys.sort()
	mut str := ''
	for k in keys {
		str += '${k}:${files[k]}\n'
	}
	sum := md5.sum(str.bytes()).hex()
	os.write_file(common.path_add(assets_dir, 'payload_manifest'), json.encode(ManifestJson{
		hash: sum
	}))!
}

/**
 * 递归收集清单文件
 *
 * @param dir 目录
 * @param prefix 相对 assets/ 的路径前缀
 * @param files 收集结果
 */
fn manifest_files(dir string, prefix string, mut files map[string]string) ! {
	for i in os.ls(dir)! {
		path := common.path_add(dir, i)
		rel := prefix + '/' + i
		if os.is_dir(path) {
			manifest_files(path, rel, mut files)!
		} else {
			data := os.read_bytes(path)!
			files[rel] = md5.sum(data).hex()
		}
	}
}

/**
 * 写 local.properties (sdk.dir 需转义 \ 和 :)
 *
 * @param project 工程目录
 */
fn write_local_properties(project string) ! {
	sdk := os.getenv('ANDROID_HOME')
	// properties 转义: 先 \ -> \\, 再 : -> \:
	esc := sdk.replace('\\', '\\\\').replace(':', '\\:')
	os.write_file(common.path_add(project, 'local.properties'), 'sdk.dir=${esc}\n')!
}

/**
 * 品牌定制: 应用名称与图标
 *
 * @param conf 配置
 * @param project 工程目录
 */
fn apply_brand(conf common.BnyConfig, project string) ! {
	// 应用名称
	strings_xml := common.path_add(project, 'app', 'src', 'main', 'res', 'values', 'strings.xml')
	if os.is_file(strings_xml) {
		mut content := os.read_file(strings_xml)!
		// XML 转义 (应用名称用 title, 未配置时按 name)
		name := conf.get_title().replace('&', '&amp;').replace('<', '&lt;').replace('>',
			'&gt;')
		content = replace_app_name(content, name)
		os.write_file(strings_xml, content)!
	}
	// 图标
	if conf.icon == '' {
		return
	}
	// 图标 (相对项目根目录解析)
	icon_path := common.path_add(conf.root, conf.icon)
	if !os.is_file(icon_path) {
		println(term.red('图标文件不存在:${icon_path}'))
		exit(1)
	}
	// PNG 魔数校验
	data := os.read_bytes(icon_path)!
	if data.len < 8 || data[0..8].hex() != '89504e470d0a1a0a' {
		println(term.red('图标必须是 PNG 格式:${icon_path}'))
		exit(1)
	}
	// 复制到各密度 mipmap 目录
	for dpi in ['mdpi', 'hdpi', 'xhdpi', 'xxhdpi', 'xxxhdpi'] {
		mipmap_dir := common.path_add(project, 'app', 'src', 'main', 'res', 'mipmap-' + dpi)
		os.mkdir_all(mipmap_dir)!
		os.cp_all(icon_path, common.path_add(mipmap_dir, 'ic_launcher.png'), true)!
	}
	// 删除自适应图标 xml (存在才删)
	anydpi := common.path_add(project, 'app', 'src', 'main', 'res', 'mipmap-anydpi-v26', 'ic_launcher.xml')
	if os.is_file(anydpi) {
		os.rm(anydpi)!
	}
}

/**
 * 替换 strings.xml 中的 app_name 文本
 *
 * @param content 原内容
 * @param name 应用名称
 * @return 替换后内容
 */
fn replace_app_name(content string, name string) string {
	tag := '<string name="app_name">'
	idx := content.index(tag) or { return content }
	start := idx + tag.len
	end := content.index_after('</string>', start) or { return content }
	return content[0..start] + name + content[end..]
}

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
		url := common.get_android_url(arch)!
		// 从 presign URL 提取文件名: 取 '?' 前部分 split('/') 最后一段
		arr := url.split('?')[0].split('/')
		name := arr[arr.len - 1]
		zip_path := common.path_add(cache_dir, name)
		if os.is_file(zip_path) {
			println(term.dim('PHP运行时: 复用缓存 ${zip_path}'))
		} else {
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
		// abi 映射: aarch64 -> arm64-v8a, x86_64 -> x86_64
		abi := if arch == 'aarch64' { 'arm64-v8a' } else { 'x86_64' }
		// zip 根目录就是 .so 文件集合, 无目录层
		jni_dir := common.path_add(project, 'app', 'src', 'main', 'jniLibs', abi)
		os.mkdir_all(jni_dir)!
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
		println(term.green('PHP运行时就绪: ${arch} -> ${abi}'))
	}
}

/**
 * gradle 构建
 *
 * @param project 工程目录
 * @param release 是否 release 构建
 * @param ver 版本名
 * @param code 版本号
 * @return apk 路径
 */
fn gradle_build(project string, release bool, ver string, code string) !string {
	typ := if release { 'release' } else { 'debug' }
	// 首字母大写: assembleDebug / assembleRelease
	task := 'assemble' + typ[0..1].to_upper() + typ[1..]
	gradle := find_gradle()!
	// 删除旧产物
	out_dir := common.path_add(project, 'app', 'build', 'outputs', 'apk', typ)
	if os.is_dir(out_dir) {
		for apk in os.glob(common.path_add(out_dir, '*.apk')) or { []string{} } {
			os.rm(apk)!
		}
	}
	// 构建
	mut p := os.new_process(gradle)
	p.set_args(['-p', project, ':app:' + task, '--console=plain', '--no-daemon',
		'-PversionName=' + ver, '-PversionCode=' + code])
	p.run()
	p.wait()
	if p.code != 0 {
		println(term.red('编译失败 (exit ${p.code})'))
		exit(1)
	}
	// 收集产物
	apks := os.glob(common.path_add(out_dir, '*.apk')) or { []string{} }
	if apks.len == 0 {
		return error('未找到构建产物: ${out_dir}')
	}
	return apks[0]
}

/**
 * 收集构建产物
 *
 * @param apk apk 路径
 * @param conf 配置
 * @param typ 构建类型
 * @param ver 版本名
 */
fn collect(apk string, conf common.BnyConfig, typ string, ver string) {
	dst := common.shell_path('${conf.name}-v${ver}-${typ}.apk')
	os.cp_all(apk, dst, true) or {
		println(term.red('复制产物失败: ${err}'))
		exit(1)
	}
	println(term.green('编译完成:' + dst))
	println('安装到设备: adb install -r "${dst}"')
}
