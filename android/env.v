module android

import common
import net.http
import os
import term

const sdk_platform_version = 'android-34'
const sdk_build_tools_version = '34.0.0'
const sdk_cmdline_launcher = '11076708'

/**
 * 环境预检
 * 逐项检查 JAVA_HOME / 自动准备 Android SDK, 任一缺失打印错误并退出
 * (gradle 由 bny 自动准备, 无需用户配置)
 *
 * @return Android SDK 根路径
 */
fn checked() !string {
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
	// Android SDK 自动准备
	return ensure_sdk()!
}

/**
 * 自动准备 Android SDK, 返回 SDK 根路径
 * 优先级:
 *  1. ANDROID_HOME 有效且组件齐全 -> 直接返回
 *  2. ANDROID_HOME 有效但缺组件 -> 用 sdkmanager 补齐
 *  3. 完全缺失 -> 准备到 bny 自带 script/android-sdk
 *
 * @return SDK 根路径
 */
fn ensure_sdk() !string {
	android_home := os.getenv('ANDROID_HOME')
	// 仅当 ANDROID_HOME 本身是"SDK 根"(含 platforms/cmdline-tools/build-tools 结构) 才直接复用/补齐;
	// 若是 platform-tools 这类只含 adb 的目录, 不算 SDK 根, 回退到 bny 自带位置(避免往只读目录写入)
	if android_home != '' && os.is_dir(android_home) && looks_like_sdk(android_home) {
		if sdk_ready(android_home) {
			return android_home
		}
		sdkmanager := ensure_sdkmanager(android_home)!
		install_components(sdkmanager, android_home)!
		return android_home
	}
	// 缺失或非 SDK 根 -> bny 自带位置完整准备
	sdk_root := common.path_add(common.Dirs{}.script, 'android-sdk')
	if sdk_ready(sdk_root) {
		return sdk_root
	}
	sdkmanager := ensure_sdkmanager(sdk_root)!
	install_components(sdkmanager, sdk_root)!
	return sdk_root
}

/**
 * 判断目录是否形似 Android SDK 根 (含 cmdline-tools / platforms / build-tools 至少其一)
 *
 * @param sdk_root 候选 SDK 根
 * @return 是否看起来是 SDK 根
 */
fn looks_like_sdk(sdk_root string) bool {
	for sub in ['cmdline-tools', 'platforms', 'build-tools'] {
		if os.is_dir(common.path_add(sdk_root, sub)) {
			return true
		}
	}
	return false
}

/**
 * 判断 SDK 根是否已含 platform-34 与 ≥34 的 build-tools
 *
 * @param sdk_root SDK 根路径
 * @return 是否就绪
 */
fn sdk_ready(sdk_root string) bool {
	if !os.is_dir(common.path_add(sdk_root, 'platforms', sdk_platform_version)) {
		return false
	}
	bt_dir := common.path_add(sdk_root, 'build-tools')
	if !os.is_dir(bt_dir) {
		return false
	}
	for v in os.ls(bt_dir) or { return false } {
		if v >= '34' {
			return true
		}
	}
	return false
}

/**
 * 确保 sdkmanager 存在, 缺失则下载 commandline-tools
 *
 * @param sdk_root SDK 根路径
 * @return sdkmanager 可执行文件路径
 */
fn ensure_sdkmanager(sdk_root string) !string {
	found := find_sdkmanager(sdk_root)
	if found != '' {
		return found
	}
	download_cmdline_tools(sdk_root)!
	after := find_sdkmanager(sdk_root)
	if after == '' {
		println(term.red('sdkmanager 准备失败: 未找到 ${after}'))
		exit(1)
	}
	return after
}

/**
 * 查找 SDK 根下的 sdkmanager 脚本
 *
 * @param sdk_root SDK 根路径
 * @return sdkmanager 路径, 未找到返回空串
 */
fn find_sdkmanager(sdk_root string) string {
	mut cands := []string{}
	$if windows {
		cands = [common.path_add(sdk_root, 'cmdline-tools', 'latest', 'bin', 'sdkmanager.bat'),
			common.path_add(sdk_root, 'cmdline-tools', 'bin', 'sdkmanager.bat')]
	} $else {
		cands = [common.path_add(sdk_root, 'cmdline-tools', 'latest', 'bin', 'sdkmanager'),
			common.path_add(sdk_root, 'cmdline-tools', 'bin', 'sdkmanager')]
	}
	for c in cands {
		if os.is_file(c) {
			return c
		}
	}
	return ''
}

/**
 * 下载 commandline-tools 并解压到 <sdk>/cmdline-tools/latest/
 * (参考 gradle.v download_gradle 模式)
 *
 * @param sdk_root SDK 根路径
 */
fn download_cmdline_tools(sdk_root string) !string {
	os_sfx := $if windows {
		'win'
	} $else $if linux {
		'linux'
	} $else $if macos {
		'mac'
	} $else {
		'linux'
	}
	zip_name := 'commandlinetools-${os_sfx}-${sdk_cmdline_launcher}_latest.zip'
	// zip 与解压都放在 sdk_root 内, 不占用 cache; 清理 cache 不影响已备好的 SDK
	zip_path := common.path_add(sdk_root, zip_name)
	if !os.is_file(zip_path) {
		println(term.dim('Android SDK: sdkmanager 缺失, 开始下载 commandline-tools (仅首次)...'))
		url := 'https://dl.google.com/android/repository/${zip_name}'
		res := http.download_file_with_progress(url, zip_path, http.DownloaderParams{
			FetchConfig: http.FetchConfig{
				allow_redirect: true
			}
		}) or {
			println(term.red('commandline-tools 下载失败: ${err}'))
			exit(1)
		}
		if res.status_code != 200 {
			println(term.red('commandline-tools 下载失败, 状态码: ${res.status_code}'))
			exit(1)
		}
	} else {
		println(term.dim('commandline-tools: 使用已有 ${zip_path}'))
	}
	// 解压 (zip 顶层为 cmdline-tools/ 目录)
	// 注意: szip.extract_zip_to_dir 无法正确解压该 zip(仅解出少数条目), 用系统 tar/unzip
	tmp_dir := common.path_add(sdk_root, 'cmdline-tools-extract')
	os.rmdir_all(tmp_dir) or {}
	os.mkdir_all(tmp_dir)!
	extract_zip_system(zip_path, tmp_dir, 'cmdline-tools')!
	zip_cmdline := common.path_add(tmp_dir, 'cmdline-tools')
	if !os.is_dir(zip_cmdline) {
		// zip 损坏 -> 清掉坏压缩包, 避免长期占用且误导后续重试
		os.rm(zip_path) or {}
		os.rmdir_all(tmp_dir) or {}
		println(term.red('commandline-tools 解压结构异常: 未找到 ${zip_cmdline}'))
		println(term.red('已清除损坏压缩包, 请重新运行本命令再次下载'))
		exit(1)
	}
	// 移动到 <sdk>/cmdline-tools/latest/
	latest := common.path_add(sdk_root, 'cmdline-tools', 'latest')
	os.mkdir_all(common.path_add(sdk_root, 'cmdline-tools'))!
	os.rmdir_all(latest) or {}
	os.mv(zip_cmdline, latest)!
	os.rmdir_all(tmp_dir) or {}
	// 解压成功后删除 zip 释放空间 (SDK 本体已持久化在 sdk_root, 需时由 sdkmanager 复用)
	os.rm(zip_path) or {}
	// Unix 下确保 sdkmanager 可执行 (zip 解压可能未保留权限)
	$if linux || macos {
		common.chmod_all(common.path_add(latest, 'bin'), 0o755)!
	}
	mut result := common.path_add(latest, 'bin', 'sdkmanager')
	$if windows {
		result = common.path_add(latest, 'bin', 'sdkmanager.bat')
	}
	return result
}

/**
 * 接受 Android SDK license (预先写 license 哈希文件, 避免交互式 y/N 阻塞)
 *
 * @param sdk_root SDK 根路径
 */
fn accept_licenses(sdk_root string) ! {
	lic_dir := common.path_add(sdk_root, 'licenses')
	os.mkdir_all(lic_dir)!
	// android-sdk-license 的已知可接受哈希集合 (写入后 sdkmanager 不再提示)
	os.write_file(common.path_add(lic_dir, 'android-sdk-license'),
		'8933bad161af4178b1185d1a37fbf41ea5269c55\nd56f5187479451eabf01fb78af6dfcb131a6481e\n24333f8a63b6825ea9c5514f83c2829b004d1fee\n')!
}

/**
 * 用 sdkmanager 安装 platform-34 与 build-tools-34
 *
 * @param sdkmanager sdkmanager 路径
 * @param sdk_root SDK 根路径
 * @return SDK 根路径
 */
fn install_components(sdkmanager string, sdk_root string) !string {
	accept_licenses(sdk_root)!
	mut p := os.new_process(sdkmanager)
	p.set_args(['--sdk_root=' + sdk_root, 'platforms;' + sdk_platform_version, 'build-tools;' +
		sdk_build_tools_version])
	p.run()
	p.wait()
	if p.code != 0 {
		println(term.red('Android SDK 组件安装失败 (exit ${p.code})'))
		exit(1)
	}
	println(term.green('Android SDK 组件安装完成 (platform-34 + build-tools-34)'))
	return sdk_root
}

/**
 * 用系统 zip 工具解压 (tar 自带于 Win10+/Linux/macOS, unzip 为 Linux/macOS 惯用)
 * 项目 szip.extract_zip_to_dir 对部分 zip(如 commandline-tools) 无法完整解压, 故用系统工具
 *
 * @param zip_path zip 文件路径
 * @param dest 目标目录 (已创建)
 * @param top_dir zip 顶层目录名 (用于校验)
 * @return !void
 */
fn extract_zip_system(zip_path string, dest string, top_dir string) ! {
	mut ok := false
	$if windows {
		// 优先系统 tar (bsdtar 支持 zip); 失败再用 PowerShell Expand-Archive
		r := os.execute('tar -xf "${zip_path}" -C "${dest}"')
		if r.exit_code == 0 {
			ok = true
		} else {
			r2 := os.execute('powershell -NoProfile -Command Expand-Archive -Path "${zip_path}" -DestinationPath "${dest}" -Force')
			if r2.exit_code == 0 {
				ok = true
			}
		}
	} $else {
		// Linux/macOS: 优先 unzip, 回退 tar
		r := os.execute('unzip -oq "${zip_path}" -d "${dest}"')
		if r.exit_code == 0 {
			ok = true
		} else {
			r2 := os.execute('tar -xf "${zip_path}" -C "${dest}"')
			if r2.exit_code == 0 {
				ok = true
			}
		}
	}
	if !ok {
		println(term.red('zip 解压失败: ${zip_path}'))
		exit(1)
	}
	// 校验顶目录 (zip 顶层为 cmdline-tools)
	mut found := false
	for e in os.ls(dest) or { exit(1) } {
		if e == top_dir {
			found = true
			break
		}
	}
	if !found {
		println(term.red('zip 解压结构异常: 未找到 ${dest}/${top_dir}'))
		exit(1)
	}
}