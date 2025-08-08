<?php

// 严格模式

require __DIR__ . '/vendor/autoload.php';

use Bny\Worker\Main;

// 获取文件夹路径
define('WEB_ROOT', $argv[1]);

// 删除第一个参数 防止 workerman 影响
unset($argv[1]);

(new Main())->run();