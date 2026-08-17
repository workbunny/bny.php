module android

import common
import os
import term

/**
 * gradle 构建
 *
 * @param project 工程目录
 * @param release 是否 release 构建
 * @param ver 版本名
 * @param code 版本号
 * @param sign 签名信息 (release 时注入 gradle)
 * @return apk 路径
 */
fn gradle_build(project string, release bool, ver string, code string, sign Signing) !string {
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
	// 构建 (release 时注入签名, 路径统一正斜杠避免 -P 参数反斜杠转义问题)
	mut p := os.new_process(gradle)
	mut cmd_args := ['-p', project, ':app:' + task, '--console=plain', '--no-daemon',
		'-PversionName=' + ver, '-PversionCode=' + code]
	if release && sign.store_file != '' {
		cmd_args << ['-PstoreFile=' + sign.store_file.replace('\\', '/'), '-PstorePassword=' +
			sign.store_pass, '-PkeyAlias=' + sign.key_alias, '-PkeyPassword=' + sign.key_pass]
	}
	p.set_args(cmd_args)
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
