module android

import common
import os
import term

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
