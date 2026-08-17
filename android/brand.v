module android

import common
import os
import term

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
	// 图标: 用户配置 > bny 自带 icon.png (随 release 打包) > 壳模板默认
	mut icon_path := ''
	if conf.icon != '' {
		// 用户配置 (相对项目根目录解析)
		icon_path = common.path_add(conf.root, conf.icon)
	} else {
		// 默认使用 bny 自带图标
		icon_path = common.app_path('/icon.png')
	}
	if !os.is_file(icon_path) {
		if conf.icon != '' {
			println(term.red('图标文件不存在:${icon_path}'))
			exit(1)
		}
		return
	}
	println(term.dim('图标:${icon_path}'))
	// PNG 魔数校验
	data := os.read_bytes(icon_path)!
	if data.len < 8 || data[0..8].hex() != '89504e470d0a1a0a' {
		println(term.red('图标必须是 PNG 格式:${icon_path}'))
		exit(1)
	}
	// 复制到各密度 mipmap 目录
	// ic_launcher.png: legacy 图标 (Android <8)
	// ic_launcher_fg.png: 自适应图标前景位图 (不能叫 ic_launcher, 会与 anydpi-v26 的 xml 循环引用)
	for dpi in ['mdpi', 'hdpi', 'xhdpi', 'xxhdpi', 'xxxhdpi'] {
		mipmap_dir := common.path_add(project, 'app', 'src', 'main', 'res', 'mipmap-' + dpi)
		os.mkdir_all(mipmap_dir)!
		os.cp_all(icon_path, common.path_add(mipmap_dir, 'ic_launcher.png'), true)!
		os.cp_all(icon_path, common.path_add(mipmap_dir, 'ic_launcher_fg.png'), true)!
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
