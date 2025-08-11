<?php

// 严格模式

require __DIR__ . '/vendor/autoload.php';

use Bny\Worker\Main;

// 配置文件
if (file_exists($argv[1])) {
    $config = json_decode(file_get_contents($argv[1]), true);
} else {
    throw new \Exception('配置文件不存在');
}
define('BNY_CONFIG', $config);
// 删除第一个参数 防止 workerman 影响
unset($argv[1]);
// 运行
(new Main())->run();
