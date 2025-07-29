<?php

// 严格模式

require 'vendor/autoload.php';

use Bny\Worker\Main;

$dir = $argv[1];
unset($argv[1]);

(new Main($dir))->run();