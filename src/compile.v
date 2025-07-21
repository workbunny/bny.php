module compile

import base
import lanzou
import os
import term
import net.http
import compress.szip
import time

pub fn run() ! {
	info := base.get_info()!
	evb_path := base.app_path() + os.path_separator + 'enigmavbconsole.exe'
	base.app_path()
	if info.os == 'windows' {
		if !os.is_file(evb_path) {
			download_evb()!
		}
	}
	if info.php < 0 {
		println(term.red('请先安装php'))
		return
	}
	mut args := base.get_args()
	args.delete(0)
	if args.len == 0 || args[0] == '-h' {
		help()
	} else {
		build(args[0])!
	}
}

/**
 * 编译文件
 *
 * @param file string 目标文件
 * @return !void
 */
fn build(file string) ! {
	info := base.get_info()!
	if file != '.' && !os.is_file(file) {
		println(term.red('文件不存在'))
		return
	}
	// 编译文件
	file_path := if file == '.' {
		os.abs_path('./index.php')
	} else {
		os.abs_path(file)
	}
	// 是否项目
	if_project := if file == '.' { true } else { false }
	ext := if info.os == 'windows' { '.exe' } else { '' }
	// 导出文件
	outfile_path := os.dir(file_path) + if get_outfile() != '' {
		os.path_separator + os.base(get_outfile()) + ext
	} else {
		os.path_separator + os.file_name(file_path).replace(os.file_ext(file_path), '') + ext
	}
	// micro文件
	micro_path := if info.os == 'windows' && is_win32() {
		info.php_list[info.php].path + os.path_separator + 'micro_win32.sfx'
	} else {
		info.php_list[info.php].path + os.path_separator + 'micro.sfx'
	}
	// 开始编译
	println(term.green('开始编译...'))
	command := if info.os == 'windows' {
		'copy /b "${micro_path}" + "${file_path}" "${outfile_path}"'
	} else {
		'cat ${micro_path} "${file_path}" > "${outfile_path}"'
	}
	result := os.execute(command)
	if result.exit_code > 1 {
		println(term.red('编译失败'))
		return
	}
	if if_project && info.os == 'windows' {
		win_project(outfile_path)!
	}
	os.chmod(outfile_path, 755)!
	println(term.green('编译成功'))
}

/**
 * 项目处理
 *
 * @param file string 目标文件
 * @return !void
 */
fn win_project(file string) ! {
	if !os.is_dir(base.app_path() + os.path_separator + 'log') {
		os.mkdir(base.app_path() + os.path_separator + 'log', os.MkdirParams{})!
	}
	out_file := os.dir(file) + os.path_separator + 'evbfile.exe'
	evb_file := base.app_path() + os.path_separator + 'log' + os.path_separator +
		time.now().custom_format('YYMDHms') + '.evb'
	os.write_file(evb_file, get_evb_body(file, out_file)!)!
	evb_path := base.app_path() + os.path_separator + 'enigmavbconsole.exe'

	mut process := os.new_process(evb_path)
	process.set_args([evb_file])
	process.run()
	process.wait()
	name := base.file_name(file)
	os.rm(file)!
	os.rename(out_file, os.dir(file) + os.path_separator + name + '.exe')!
}

fn get_evb_body(file string, outfile string) !string {
	file_dir := os.dir(file)

	mut body := []string{}
	body << '<?xml version="1.0" encoding="windows-1252"?>'
	body << '<>'
	body << '  <InputFile>${file}</InputFile>'
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
	body << evb_glob(file_dir)!
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
	mut str := []string{}
	arr := os.glob(path + '/*')!
	for i in arr {
		file_path := path + os.path_separator + i
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

/**
 * 获取输出文件名
 *
 * @return string
 */
fn get_outfile() string {
	mut args := base.get_args()
	args.delete(0)
	mut out_file := ''
	for arg in args {
		if arg.contains('-outfile=') {
			out_file = arg.replace('-outfile=', '')
			break
		}
	}
	return out_file
}

/**
 * 判断是否为win32程序
 *
 * @return bool
 */
fn is_win32() bool {
	mut args := base.get_args()
	args.delete(0)
	mut res := false
	for arg in args {
		if arg == '-win32' {
			res = true
			break
		}
	}
	return res
}

/**
 * 下载 Enigmavbconsole.exe
 *
 * @return void
 */
fn download_evb() ! {
	println(term.dim('安装相关依赖...'))
	url := lanzou.download('ixPav310im7c')!
	http.download_file(url, base.app_path() + '/evb.zip')!
	szip.extract_zip_to_dir(base.app_path() + '/evb.zip', base.app_path())!
	os.rm(base.app_path() + '/evb.zip')!
}

fn help() {
	mut arr := []string{}
	arr << term.yellow('用法:')
	arr << ''
	arr << term.green('intg compile ') + term.blue('[目标] <指令>')
	arr << ''
	arr << term.yellow('目标:')
	arr << ''
	arr << term.blue('  [file]                     ') + '编译php/phar文件'
	arr << term.blue('  -h                         ') + '编译目录下所有文件'
	arr << ''
	arr << term.yellow('指令:')
	arr << ''
	arr << term.blue('  -win32                     ') + '编译为GUI程序,适用于win平台'
	arr << term.blue('  -outfile=[name]            ') + '编译为指定文件名'
	arr << ''
	arr << term.yellow('示例:')
	arr << ''
	arr << term.green('  intg compile ') + term.blue('test.php')
	arr << term.green('  intg compile ') + term.blue('test.phar')
	println(arr.join('\n'))
}
