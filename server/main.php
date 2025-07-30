<?php

// 严格模式

require 'vendor/autoload.php';

use Bny\Worker\Main;

// 获取文件夹路径
$dir = $argv[1];

// 删除第一个参数 防止 workerman 影响
unset($argv[1]);

(new Main($dir))->run();