module compile

import common
import os.cmdline
import os
import term
import time

pub fn windows_build(conf common.BnyConfig) ! {
	// evb 打包器文件
	evb_exe := common.path_add(common.Dirs{}.script, 'enigmavbconsole.exe')
	evb_bodys := get_config_body(conf)!
	evb_config_file := get_config_file(evb_bodys)!
	println(term.green('开始编译项目...'))
	if os.is_file(common.shell_path('/' + conf.name + '.exe')) {
		os.rm(common.shell_path('/' + conf.name + '.exe'))!
	}
	// 编译
	mut process := os.new_process(evb_exe)
	process.set_args([evb_config_file])
	process.run()
	process.wait()
	if os.is_file(common.shell_path('/' + conf.name + '.exe')) {
		println(term.green('编译成功'))
		if conf.icon != '' {
			rcedit(conf.icon)!
		}
		println(term.green('可执行文件: ' + conf.name + '.exe'))
	} else {
		println(term.red('编译失败'))
	}
}

/**
 * 修改图标
 * @param string icon 图标路径
 */
fn rcedit(icon string) ! {
	println(term.green('开始修改图标...'))
	rcedit_exe := common.path_add(common.Dirs{}.script, 'rcedit-x64.exe')
	mut process := os.new_process(rcedit_exe)
	process.set_args([common.shell_path(icon), '--set-icon', icon])
	process.run()
	process.wait()
	println(term.green('图标修改成功'))
}

/**
 * 获取打包器配置文件
 *
 * @param string str 打包器配置文件内容
 * @return !string 打包器配置文件路径
 */
fn get_config_file(str string) !string {
	config_file := common.path_add(common.Dirs{}.cache, time.now().custom_format('YYMDHms') + '.evb')
	os.write_file(config_file, str)!
	if !os.is_file(config_file) {
		error('evb文件创建失败')
	}
	return config_file
}

/**
 * 获取打包器配置文件内容
 * @param common.BnyConfig conf 项目配置
 * @return !string 打包器配置文件内容
 */
fn get_config_body(conf common.BnyConfig) !string {
	mainfile := noterm()
	outfile := common.shell_path('/' + conf.name + '.exe')
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
	body << php_body()!
	body << get_bodys(common.shell_path(none), conf.ignore)!
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

/**
 * 获取打包器配置文件内容
 * @param string path 路径
 * @param []string ignore 忽略的文件
 * @return ![]string 打包器配置文件内容
 */
fn get_bodys(path string, ignore []string) ![]string {
	mut body := []string{}
	arr := os.glob(common.path_add(path, '*'))!
	for i in arr {
		p := common.path_add(path, i) // 完整路径
		// 过滤
		if common.filter_path(p, ignore) {
			continue
		}
		name := common.file_name_ext(p)
		if os.is_dir(p) {
			body << '<File>'
			body << '  <Type>3</Type>'
			body << '  <Name>${name}</Name>'
			body << '  <Action>0</Action>'
			body << '  <OverwriteDateTime>False</OverwriteDateTime>'
			body << '  <OverwriteAttributes>False</OverwriteAttributes>'
			body << '  <HideFromDialogs>0</HideFromDialogs>'
			body << '  <Files>'
			body << get_bodys(p, ignore)!
			body << '  </Files>'
			body << '</File>'
		} else {
			body << '<File>'
			body << '  <Type>2</Type>'
			body << '  <Name>${name}</Name>'
			body << '  <File>${p}</File>'
			body << '  <ActiveX>False</ActiveX>'
			body << '  <ActiveXInstall>False</ActiveXInstall>'
			body << '  <Action>0</Action>'
			body << '  <OverwriteDateTime>False</OverwriteDateTime>'
			body << '  <OverwriteAttributes>False</OverwriteAttributes>'
			body << '  <PassCommandLine>False</PassCommandLine>'
			body << '  <HideFromDialogs>0</HideFromDialogs>'
			body << '</File>'
		}
	}
	return body
}

/**
 * 获取php文件
 * @return ![]string 打包器配置文件内容
 */
fn php_body() ![]string {
	info := common.get_info()!
	path := info.php_list[info.php].path
	mut body := []string{}
	body << '<File>'
	body << '  <Type>3</Type>'
	body << '  <Name>php</Name>'
	body << '  <Action>0</Action>'
	body << '  <OverwriteDateTime>False</OverwriteDateTime>'
	body << '  <OverwriteAttributes>False</OverwriteAttributes>'
	body << '  <HideFromDialogs>0</HideFromDialogs>'
	body << '  <Files>'
	body << get_bodys(path, [])!
	body << '  </Files>'
	body << '</File>'
	return body
}

fn noterm() string {
	mut args := common.get_args()
	noterm := cmdline.option(args, '-noterm', 'false')
	if noterm != 'flase' {
		return common.path_add(common.Dirs{}.script, 'cli.exe')
	} else {
		return common.path_add(common.Dirs{}.script, 'win32.exe')
	}
}
