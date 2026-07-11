module compile

import common
import time
import os.cmdline
import os
import term

pub fn macos_build(conf common.BnyConfig) ! {
	println(term.green('开始编译项目...'))
	project := build_cache_project(conf)!
	p := os.execute('codesign --force --deep --sign - ${project}')
	println(p.exit_code)
	println(p.output)
	if mac_noterm() {
		dir := build_dmg()!
		os.cp_all(project, dir, true)!
		os.execute('hdiutil create -srcfolder ${dir} -volname "${conf.name}" -format UDZO ' +
			common.shell_path(conf.name + '.dmg'))
		os.execute('codesign --force --sign - ' + common.shell_path(conf.name + '.dmg'))
	} else {
		dir := build_pkg()!
		os.cp_all(project, common.path_add(dir, 'Applications'), true)!
		pkg_path := common.shell_path(conf.name + '.pkg')
		pkg_tmp := pkg_path + '.tmp'
		r1 := os.execute('pkgbuild --root ${dir} --identifier app.${conf.name}.bny --version 1.0.0 ${pkg_tmp}')
		println('pkgbuild exit: ${r1.exit_code}')
		println(r1.output)
		if r1.exit_code != 0 {
			error('pkgbuild failed')
		}
		r2 := os.execute('productsign --sign - ${pkg_tmp} ${pkg_path}')
		if r2.exit_code != 0 {
			println(term.yellow('未签名,用户可自行签名'))
			os.cp(pkg_tmp, pkg_path)!
		}
		os.rm(pkg_tmp)!
	}
	println(term.green('编译完成:' + common.shell_path(conf.name + '.(pkg/dmg)')))
}

/**
 * 创建缓存项目
 * @param conf 配置
 * @return 缓存项目
 */
fn build_cache_project(conf common.BnyConfig) !string {
	info := common.get_info()!
	dir := build_cache_dir()!
	// 创建配置文件
	mut info_plist := []string{}
	info_plist << '<?xml version="1.0" encoding="UTF-8"?>'
	info_plist << '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">'
	info_plist << '<plist version="1.0">'
	info_plist << '<dict>'
	info_plist << '     <key>CFBundlePackageType</key>'
	info_plist << '     <string>APPL</string>'

	info_plist << '     <key>CFBundleExecutable</key>'
	info_plist << '     <string>cli</string>'

	info_plist << '     <key>CFBundleIdentifier</key>'
	info_plist << '     <string>app.${info.name}.bny</string>'

	info_plist << '     <key>CFBundleName</key>'
	info_plist << '     <string>${info.name}</string>'

	info_plist << '     <key>CFBundleVersion</key>'
	info_plist << '     <string>1</string>'

	info_plist << '     <key>CFBundleShortVersionString</key>'
	info_plist << '     <string>1.0.0</string>'

	info_plist << '     <key>CFBundleIconFile</key>'
	info_plist << '     <string>icon.icns</string>'

	info_plist << '     <key>NSHighResolutionCapable</key>'
	info_plist << '     <true/>'

	if mac_noterm() {
		info_plist << '     <key>LSUIElement</key>'
		info_plist << '     <true/>'
	}
	info_plist << '</dict>'
	info_plist << '</plist>'
	os.write_file(common.path_add(dir, 'Contents', 'Info.plist'), info_plist.join('\n'))!

	// 图标文件
	if conf.icon != '' {
		icon_dir := common.path_add(dir, 'icon.iconset')
		os.mkdir(icon_dir, os.MkdirParams{})!
		println('正在整理图标文件...')
		os.execute('sips -z 16 16     ${conf.icon} --out ${icon_dir}/icon_16x16.png')
		os.execute('sips -z 32 32     ${conf.icon} --out ${icon_dir}/icon_32x32.png')
		os.execute('sips -z 128 128  ${conf.icon} --out ${icon_dir}/icon_128x128.png')
		os.execute('sips -z 256 256  ${conf.icon} --out ${icon_dir}/icon_256x256.png')
		os.execute('sips -z 512 512  ${conf.icon} --out ${icon_dir}/icon_512x512.png')
		os.execute('sips -z 1024 1024 ${conf.icon} --out ${icon_dir}/icon_1024x1024.png')
		os.execute('iconutil -c icns ${icon_dir} -o ${dir}/${conf.name}.icns')
		os.cp('${dir}/${conf.name}.icns', '${dir}/Contents/Resources/')!
		os.rm('${dir}/${conf.name}.icns')!
	}

	// php文件处理
	php_dir := info.php_list[info.php].path
	os.cp_all(php_dir, common.path_add(dir, 'Contents', 'MacOS', 'php'), true)!

	// 复制cli文件
	os.cp(common.path_add(common.Dirs{}.script, 'cli'), common.path_add(dir, 'Contents',
		'MacOS', 'cli'))!

	// 复制项目内容
	arr := os.ls(common.shell_path(none))!
	// println(arr)
	for i in arr {
		if common.filter_path(i, conf.ignore) {
			continue
		}
		println('[打包]:' + common.path_add(common.shell_path(none), i))
		println('[编译]:' + common.path_add(dir, 'Contents', 'MacOS', i))
		os.cp_all(common.path_add(common.shell_path(none), i), common.path_add(dir, 'Contents',
			'MacOS', i), true)!
	}
	println('文件夹:${dir}')
	common.chmod_all(dir, 0o777)!
	return dir
}

/**
 * 创建缓存目录
 * @return 缓存目录
 */
fn build_cache_dir() !string {
	dir := common.path_add(common.Dirs{}.cache, time.now().custom_format('YYMDHms')) + '.app'
	// 创建目录
	arr := [
		dir,
		common.path_add(dir, 'Contents'),
		common.path_add(dir, 'Contents', 'MacOS'),
		common.path_add(dir, 'Contents', 'Resources'),
	]
	for i in arr {
		if !os.is_dir(i) {
			os.mkdir(i, os.MkdirParams{})!
		}
	}
	return dir
}

/**
 * 创建dmg打包目录
 * @return 打包目录
 */
fn build_dmg() !string {
	dir := common.path_add(common.Dirs{}.cache, 'dmg_' + time.now().custom_format('YYMDHms'))
	arr := [
		dir,
		common.path_add(dir, 'Applications'),
	]
	for i in arr {
		if !os.is_dir(i) {
			os.mkdir(i, os.MkdirParams{})!
		}
	}
	return dir
}

/**
 * 创建pkg打包目录
 * @return 打包目录
 */
fn build_pkg() !string {
	dir := common.path_add(common.Dirs{}.cache, 'pkg_' + time.now().custom_format('YYMDHms'))
	arr := [
		dir,
		common.path_add(dir, 'Applications'),
	]
	for i in arr {
		if !os.is_dir(i) {
			os.mkdir(i, os.MkdirParams{})!
		}
	}
	return dir
}

/**
 * 是否命名窗口
 * @return 是否命名窗口
 */
fn mac_noterm() bool {
	mut args := common.get_args()
	n := cmdline.option(args, '-noterm', 'no')
	if n == 'no' {
		return false
	} else {
		return true
	}
}
