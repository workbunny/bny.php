module common

import os

pub fn get_args() []string {
	mut args := os.args.clone()
	args.delete(0)
	return args
}
