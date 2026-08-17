module main

/**
 * ELF SONAME/DT_NEEDED 修补工具 (Android 打包用)
 *
 * termux 运行时打包时把库文件改名为 lib*.so (AGP 的 jniLibs 只认该命名),
 * 但库文件内部的 SONAME/DT_NEEDED 仍是带版本号的旧名 (如 libssl.so.3)。
 * Android 链接器按 SONAME 匹配依赖, 名称对不上会报:
 *   cannot find "libssl.so" from verneed[1] in DT_NEEDED list
 *
 * 本工具把目录中 ELF 动态字符串表里的旧名就地改写为目录中实际存在的
 * 文件名 (旧名去掉尾部版本号); 新名总是更短, 原位覆写不改变 ELF 布局。
 *
 * 用法: elfpatch <目录>
 */

import os
import encoding.binary
import term

fn main() {
	args := os.args[1..]
	if args.len < 1 {
		println('用法: elfpatch <目录>')
		println('修补目录中 ELF 的 SONAME/DT_NEEDED 为实际文件名')
		exit(1)
	}
	dir := args[0]
	if !os.is_dir(dir) {
		println(term.red('目录不存在: ${dir}'))
		exit(1)
	}
	changes := patch_elf_names(dir)
	for c in changes {
		println('[修补]:' + c)
	}
	println(term.green('完成, 共 ${changes.len} 处'))
}

/**
 * 修补目录中所有 ELF 的 SONAME/DT_NEEDED
 *
 * @param jni_dir 目录
 * @return 修补记录 "文件: 旧名 -> 新名"
 */
fn patch_elf_names(jni_dir string) []string {
	mut changes := []string{}
	files := os.ls(jni_dir) or { return changes }
	for f in files {
		if !f.ends_with('.so') {
			continue
		}
		path := os.join_path(jni_dir, f)
		mut data := os.read_bytes(path) or { continue }
		cs := patch_elf_dynstr(mut data, files)
		if cs.len > 0 {
			os.write_file(path, data.bytestr()) or {
				println(term.red('ELF 修补写入失败: ${f}'))
				continue
			}
			for c in cs {
				changes << '${f}: ${c}'
			}
		}
	}
	return changes
}

/**
 * 解析 ELF64 并改写动态字符串表中的 SONAME/NEEDED
 *
 * @param data 文件字节 (会被就地修改)
 * @param files 同目录文件名列表 (映射目标)
 * @return 修补记录 "旧名 -> 新名"
 */
fn patch_elf_dynstr(mut data []u8, files []string) []string {
	mut changes := []string{}
	n := data.len
	if n < 64 {
		return changes
	}
	// 仅处理 ELF64 小端
	if data[0] != 0x7f || data[1] != `E` || data[2] != `L` || data[3] != `F` || data[4] != 2 {
		return changes
	}
	phoff := binary.little_endian_u64(data[0x20..0x28])
	phentsize := binary.little_endian_u16(data[0x36..0x38])
	phnum := binary.little_endian_u16(data[0x38..0x3a])
	// 遍历 program header, 记录 PT_LOAD (vaddr->offset 换算) 和 PT_DYNAMIC
	mut load_vaddr := []u64{}
	mut load_off := []u64{}
	mut load_sz := []u64{}
	mut dyn_off := u64(0)
	mut dyn_sz := u64(0)
	for i in 0 .. int(phnum) {
		b := int(phoff) + i * int(phentsize)
		if b + 56 > n {
			break
		}
		match binary.little_endian_u32(data[b..b + 4]) {
			1 { // PT_LOAD
				load_off << binary.little_endian_u64(data[b + 8..b + 16])
				load_vaddr << binary.little_endian_u64(data[b + 16..b + 24])
				load_sz << binary.little_endian_u64(data[b + 32..b + 40])
			}
			2 { // PT_DYNAMIC
				dyn_off = binary.little_endian_u64(data[b + 8..b + 16])
				dyn_sz = binary.little_endian_u64(data[b + 32..b + 40])
			}
			else {}
		}
	}
	if dyn_off == 0 {
		return changes
	}
	// 遍历 dynamic 段, 取 DT_STRTAB 与 SONAME/NEEDED 的字符串偏移
	mut strtab := u64(0)
	mut refs := []u64{}
	mut pos := int(dyn_off)
	end := int(dyn_off + dyn_sz)
	for pos + 16 <= end && pos + 16 <= n {
		tag := binary.little_endian_u64(data[pos..pos + 8])
		val := binary.little_endian_u64(data[pos + 8..pos + 16])
		if tag == 0 {
			break
		}
		if tag == 5 { // DT_STRTAB
			strtab = val
		}
		if tag == 1 || tag == 14 { // DT_NEEDED / DT_SONAME
			refs << val
		}
		pos += 16
	}
	if strtab == 0 || refs.len == 0 {
		return changes
	}
	strtab_off := vaddr_to_off(strtab, load_vaddr, load_off, load_sz)
	if strtab_off == 0 {
		return changes
	}
	for val in refs {
		off := int(strtab_off + val)
		if off >= n {
			continue
		}
		// 读 C 字符串
		mut e := off
		for e < n && data[e] != 0 {
			e++
		}
		old := data[off..e].bytestr()
		if old.len == 0 {
			continue
		}
		new := map_dyn_name(old, files)
		if new == old || new.len > old.len {
			continue
		}
		// 原位覆写: 新名 + '\0', 尾部剩余字节保留不动 (不影响其他字符串表项)
		for i, c in new.bytes() {
			data[off + i] = c
		}
		data[off + new.len] = 0
		changes << '${old} -> ${new}'
	}
	return changes
}

/**
 * 旧名映射为目录中实际存在的文件名
 * 精确命中保留; 否则去掉尾部版本号 (纯数字和点) 后命中则映射
 * 如 libssl.so.3 -> libssl.so, libicuuc.so.78 -> libicuuc.so
 *
 * @param old 动态字符串表中的旧名
 * @param files 同目录文件名列表
 * @return 实际使用的名字
 */
fn map_dyn_name(old string, files []string) string {
	for f in files {
		if old == f {
			return old
		}
	}
	for f in files {
		if !old.starts_with(f + '.') {
			continue
		}
		rest := old[f.len + 1..]
		mut ok := rest.len > 0
		for c in rest {
			if c != `.` && (c < `0` || c > `9`) {
				ok = false
				break
			}
		}
		if ok {
			return f
		}
	}
	return old
}

/**
 * 虚拟地址转文件偏移 (PT_LOAD 映射)
 *
 * @param vaddr 虚拟地址
 * @return 文件偏移, 0 表示未找到
 */
fn vaddr_to_off(vaddr u64, l_vaddr []u64, l_off []u64, l_sz []u64) u64 {
	for i, v in l_vaddr {
		if vaddr >= v && vaddr < v + l_sz[i] {
			return l_off[i] + (vaddr - v)
		}
	}
	return 0
}
