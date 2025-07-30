module compile

import base
import os
import os.cmdline

pub fn rcedit() ! {
	args := base.get_args()
	mut icon := cmdline.option(args, '-icon', '')
	mut new_agrs := []string{}
	
	outfile := get_outfile()!
	if icon != '' {
		new_agrs << '--set-icon'
		new_agrs << icon
	}

	if new_agrs.len > 0 {
		new_agrs.insert(0, outfile)
		set_rcedit(new_agrs)!
	}
}

fn set_rcedit(args []string)! {
	file := Download.rcedit.next().file
	mut process := os.new_process(file)
	process.set_args(args)
	process.run()
	process.wait()
}