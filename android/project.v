module android

import common
import crypto.md5
import json
import os
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
	// 签名/构建产物不出现在 assets 里 (纯名称规则, 任意层级命中)
	mut ignore := conf.ignore.clone()
	ignore << '${conf.name}.keystore'
	ignore << '${conf.name}.keystore.properties'
	ignore << '*.apk' // 之前打包的 apk 若在项目根, 不能裹进新包(否则会逐次翻倍变大)
	copy_project(conf.root, assets_app, ignore)!
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
			// 纯名称: 任意一层命中即忽略 (支持 *.ext 后缀通配)
			for s in segs {
				if match_seg(s, p) {
					return true
				}
			}
		}
	}
	return false
}

/**
 * 名称段匹配 (支持简单通配)
 * 仅当 pattern 不含 '/' 且含 '*' 时做通配: *.ext 后缀匹配 / pre* 前缀匹配 / *sub* 包含匹配
 * 否则做精确匹配
 *
 * @param seg 名称段
 * @param pattern 匹配规则
 * @return 是否命中
 */
fn match_seg(seg string, pattern string) bool {
	if pattern.contains('*') {
		if pattern.starts_with('*') && pattern.ends_with('*') {
			sub := pattern[1..pattern.len - 1]
			return sub == '' || seg.contains(sub)
		} else if pattern.starts_with('*') {
			return seg.ends_with(pattern[1..])
		} else if pattern.ends_with('*') {
			return seg.starts_with(pattern[..pattern.len - 1])
		}
	}
	return seg == pattern
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
	sdk := ensure_sdk()!
	// properties 转义: 先 \ -> \\, 再 : -> \:
	esc := sdk.replace('\\', '\\\\').replace(':', '\\:')
	os.write_file(common.path_add(project, 'local.properties'), 'sdk.dir=${esc}\n')!
}
