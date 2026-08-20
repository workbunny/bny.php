module android

import common
import crypto.rand
import os
import term
import time

/** 签名信息 */
struct Signing {
mut:
	store_file string // keystore 路径
	store_pass string // keystore 密码
	key_alias  string // 密钥别名
	key_pass   string // 密钥密码
}

/**
 * 准备 release 签名
 * keystore 与凭据文件固定存放在项目根:
 *   <name>.keystore            签名密钥 (首次自动生成, 之后复用, 保证可覆盖升级)
 *   <name>.keystore.properties 凭据文件 (密码/别名)
 *
 * @param conf 配置
 * @param cert_cn 证书 CN (命令行 -release [CN] > bny.json android.sign; 空则按 项目名.demo.com)
 * @return 签名信息
 */
fn prepare_signing(conf common.BnyConfig, cert_cn string) !Signing {
	// 路径绝对化 (conf.root 可能为 '.', gradle 侧需绝对路径)
	ks := os.real_path(common.path_add(conf.root, conf.name + '.keystore'))
	prop := ks + '.properties'
	// 已有 keystore: 读凭据复用
	if os.is_file(ks) {
		if !os.is_file(prop) {
			println(term.red('已存在签名密钥但缺少凭据文件:${prop}'))
			println(term.red('请补充凭据文件 (UTF-8), 内容格式:'))
			println(term.red('  storePassword=xxx'))
			println(term.red('  keyAlias=xxx'))
			println(term.red('  keyPassword=xxx'))
			exit(1)
		}
		sign := read_signing(ks, prop)!
		println(term.dim('签名:复用 ${ks}'))
		return sign
	}
	if os.is_file(prop) {
		println(term.red('凭据文件存在但签名密钥丢失:${ks}'))
		println(term.red('签名密钥无法重建, 请恢复 keystore 文件后重试'))
		exit(1)
	}
	// CN 含 , = 会破坏 keytool -dname 解析
	if cert_cn.contains(',') || cert_cn.contains('=') {
		println(term.red('证书 CN 不能包含逗号或等号:${cert_cn}'))
		exit(1)
	}
	// 首次生成 (RSA 2048, 有效期 100 年)
	store_pass := gen_password()
	alias := conf.name
	cn := if cert_cn != '' { cert_cn } else { conf.name + '.demo.com' }
	mut keytool := ''
	$if windows {
		keytool = common.path_add(os.getenv('JAVA_HOME'), 'bin', 'keytool.exe')
	} $else {
		keytool = common.path_add(os.getenv('JAVA_HOME'), 'bin', 'keytool')
	}
	if !os.is_file(keytool) {
		println(term.red('未找到 keytool:${keytool}, 请检查 JAVA_HOME'))
		exit(1)
	}
	mut p := os.new_process(keytool)
	p.set_args(['-genkeypair', '-keystore', ks, '-alias', alias, '-keyalg', 'RSA',
		'-keysize', '2048', '-validity', '36500', '-storepass', store_pass, '-keypass',
		store_pass, '-dname', 'CN=${cn}, OU=${alias}, O=Bny, L=City, ST=State, C=CN'])
	p.run()
	p.wait()
	if p.code != 0 || !os.is_file(ks) {
		println(term.red('生成签名密钥失败 (exit ${p.code})'))
		exit(1)
	}
	os.write_file(prop, 'storePassword=${store_pass}\nkeyAlias=${alias}\nkeyPassword=${store_pass}\n')!
	println(term.green('签名:已生成 ${ks}'))
	println(term.yellow('请妥善备份签名密钥与凭据文件, 丢失将无法覆盖安装升级!'))
	return Signing{
		store_file: ks
		store_pass: store_pass
		key_alias: alias
		key_pass: store_pass
	}
}

/**
 * 读取签名凭据文件
 *
 * @param ks keystore 路径
 * @param prop 凭据文件路径
 * @return 签名信息
 */
fn read_signing(ks string, prop string) !Signing {
	mut sign := Signing{
		store_file: ks
	}
	for line in os.read_file(prop)!.split('\n') {
		l := line.trim_space()
		if l == '' || l.starts_with('#') {
			continue
		}
		idx := l.index('=') or { continue }
		key := l[..idx]
		val := l[idx + 1..]
		match key {
			'storePassword' { sign.store_pass = val }
			'keyAlias' { sign.key_alias = val }
			'keyPassword' { sign.key_pass = val }
			else {}
		}
	}
	if sign.store_pass == '' || sign.key_alias == '' || sign.key_pass == '' {
		println(term.red('凭据文件不完整:${prop}'))
		println(term.red('需包含 storePassword / keyAlias / keyPassword 三项'))
		exit(1)
	}
	return sign
}

/**
 * 生成随机密码 (32 位 hex)
 *
 * @return 密码
 */
fn gen_password() string {
	buf := rand.bytes(16) or { return time.now().unix_milli().hex() }
	return buf.hex()
}
