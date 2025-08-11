<?php

// 严格模式

require __DIR__ . '/vendor/autoload.php';

use Bny\Worker\Main;

// 获取文件夹路径
define('WEB_ROOT', $argv[1]);

// 配置文件
$config = dirname(WEB_ROOT) . DIRECTORY_SEPARATOR . 'bny.config.json';
if (file_exists($config)) {
    $config = json_decode(file_get_contents($config), true);
} else {
    throw new \Exception('配置文件不存在');
}
define('BNY_CONFIG', $config);

// 删除第一个参数 防止 workerman 影响
unset($argv[1]);

// 运行
(new Main())->run();
