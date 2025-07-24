module compile

import os
import base
import time
import php

/**
 * 获取evb文件路径
 *
 * @return !string
 */
fn get_evbfile() !string {

	// evb文件名称
	name := time.now().custom_format('YYMDHms')

	// evb文件路径
	evb_file := base.path_add(base.app_path(), 'log', name + '.evb')
	// evb文件内容
	body := evb_body()!
	// 保存文件
	os.write_file(evb_file, body)!

	if !os.is_file(evb_file) {
		panic('evb文件创建失败')
	}
	return evb_file
}

/**
 * 编译
 *
 * @return !void
 */
pub fn evb_compile() ! {
	// 入口文件路径
	impfile := get_impfile()!
	// php文件路径
	php_path := php.get_php_path()!
	// php 文件名称
	php_name := base.file_name_ext(php_path)
	// 新的php文件路径
	new_php_path := base.path_add(os.dir(impfile), php_name)
	// 复制文件
	os.cp_all(php_path, new_php_path, true)!
	dl := Download{}
	// evb编译文件路径
	evb_file := get_evbfile()!
	// evb执行文件路径
	evb_exe := dl.evb.path
	// 编译
	mut process := os.new_process(evb_exe)
	process.set_args([evb_file])
	process.run()
	// 等待编译完成
	process.wait()
	// 删除新的php文件路径
	os.rm(new_php_path)!
}

/**
 * 获取编译文件路径
 *
 * @return !string
 */
fn get_mainfile() !string {
	dl := Download{}
	mainfile := if is_term() {
		dl.cli.path
	} else {
		dl.win32.path
	}
	return mainfile
}

/**
 * 获取evb文件内容
 *
 * @return !string
 */
fn evb_body() !string {
	mainfile := get_mainfile()!
	// 入口文件目录
	impdir := get_impdir()!
	// 导出文件路径
	outfile := get_outfile()!
	evbglob := evb_glob(impdir)!
	mut body := []string{}
	body << '<?xml version="1.0" encoding="windows-1252"?>'
	body << '<>'
	body << '  <InputFile>${mainfile}</InputFile>'
	body << '  <OutputFile>${outfile}</OutputFile>'
	body << '  <Files>'
	body << '    <Enabled>True</Enabled>'
	body << '    <DeleteExtractedOnExit>True</DeleteExtractedOnExit>'
	body << '    <CompressFiles>False</CompressFiles>'
	body << '    <Files>'
	body << '      <File>'
	body << '        <Type>3</Type>'
	body << '        <Name>%DEFAULT FOLDER%</Name>'
	body << '        <Action>0</Action>'
	body << '        <OverwriteDateTime>False</OverwriteDateTime>'
	body << '        <OverwriteAttributes>False</OverwriteAttributes>'
	body << '        <HideFromDialogs>0</HideFromDialogs>'
	body << '        <Files>'
	body << evbglob
	body << '        </Files>'
	body << '      </File>'
	body << '    </Files>'
	body << '  </Files>'
	body << '  <Registries>'
	body << '    <Enabled>False</Enabled>'
	body << '    <Registries>'
	body << '      <Registry>'
	body << '        <Type>1</Type>'
	body << '        <Virtual>True</Virtual>'
	body << '        <Name>Classes</Name>'
	body << '        <ValueType>0</ValueType>'
	body << '        <Value/>'
	body << '        <Registries/>'
	body << '      </Registry>'
	body << '      <Registry>'
	body << '        <Type>1</Type>'
	body << '        <Virtual>True</Virtual>'
	body << '        <Name>User</Name>'
	body << '        <ValueType>0</ValueType>'
	body << '        <Value/>'
	body << '        <Registries/>'
	body << '      </Registry>'
	body << '      <Registry>'
	body << '        <Type>1</Type>'
	body << '        <Virtual>True</Virtual>'
	body << '        <Name>Machine</Name>'
	body << '        <ValueType>0</ValueType>'
	body << '        <Value/>'
	body << '        <Registries/>'
	body << '      </Registry>'
	body << '      <Registry>'
	body << '        <Type>1</Type>'
	body << '        <Virtual>True</Virtual>'
	body << '        <Name>Users</Name>'
	body << '        <ValueType>0</ValueType>'
	body << '        <Value/>'
	body << '        <Registries/>'
	body << '      </Registry>'
	body << '      <Registry>'
	body << '        <Type>1</Type>'
	body << '        <Virtual>True</Virtual>'
	body << '        <Name>Config</Name>'
	body << '        <ValueType>0</ValueType>'
	body << '        <Value/>'
	body << '        <Registries/>'
	body << '      </Registry>'
	body << '    </Registries>'
	body << '  </Registries>'
	body << '  <Packaging>'
	body << '    <Enabled>False</Enabled>'
	body << '  </Packaging>'
	body << '  <Options>'
	body << '    <ShareVirtualSystem>False</ShareVirtualSystem>'
	body << '    <MapExecutableWithTemporaryFile>True</MapExecutableWithTemporaryFile>'
	body << '    <TemporaryFileMask/>'
	body << '    <AllowRunningOfVirtualExeFiles>True</AllowRunningOfVirtualExeFiles>'
	body << '    <ProcessesOfAnyPlatforms>False</ProcessesOfAnyPlatforms>'
	body << '  </Options>'
	body << '  <Storage>'
	body << '    <Files>'
	body << '      <Enabled>False</Enabled>'
	body << '      <Folder>%DEFAULT FOLDER%\\</Folder>'
	body << '      <RandomFileNames>False</RandomFileNames>'
	body << '      <EncryptContent>False</EncryptContent>'
	body << '    </Files>'
	body << '  </Storage>'
	body << '</>'
	return body.join('\n')
}

fn evb_glob(path string) ![]string {
	// 入口文件目录
	mut str := []string{}
	arr := os.glob(path + '/*')!
	outfile := get_outfile()!
	for i in arr {
		file_path := base.path_add(path, i)
		name := base.file_name_ext(file_path)

		// 过滤.git目录
		if file_path.contains('.git') && file_path[file_path.len - 5..file_path.len] != '.git' {
			continue
		}
		if file_path.contains('runtime') && file_path[file_path.len - 8..file_path.len] != 'runtime' {
			continue
		}
		if file_path.contains('test') && file_path[file_path.len - 4..file_path.len] != 'test' {
			continue
		}
		// 过滤输出文件
		if file_path == outfile {
			continue
		}
		if os.is_dir(file_path) {
			str << '<File>'
			str << '  <Type>3</Type>'
			str << '  <Name>${name}</Name>'
			str << '  <Action>0</Action>'
			str << '  <OverwriteDateTime>False</OverwriteDateTime>'
			str << '  <OverwriteAttributes>False</OverwriteAttributes>'
			str << '  <HideFromDialogs>0</HideFromDialogs>'
			str << '  <Files>'
			str << evb_glob(file_path)!
			str << '  </Files>'
			str << '</File>'
		} else {
			str << '<File>'
			str << '  <Type>2</Type>'
			str << '  <Name>${name}</Name>'
			str << '  <File>${file_path}</File>'
			str << '  <ActiveX>False</ActiveX>'
			str << '  <ActiveXInstall>False</ActiveXInstall>'
			str << '  <Action>0</Action>'
			str << '  <OverwriteDateTime>False</OverwriteDateTime>'
			str << '  <OverwriteAttributes>False</OverwriteAttributes>'
			str << '  <PassCommandLine>False</PassCommandLine>'
			str << '  <HideFromDialogs>0</HideFromDialogs>'
			str << '</File>'
		}
	}
	return str
}
