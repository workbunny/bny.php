<?php

// 根据你的实际情况，修改下面的路径
require "/vendor/autoload.php";

use Kingbes\PebView\Window; // 引入 Window 类

// 创建一个窗口
$win = new Window();
$win->setTitle("PebView") // 设置窗口标题
    ->setHtml( // 设置窗口的 HTML 内容
        <<<HTML
    <h1>hello PebView!</h1>
HTML)
    // 运行窗口
    ->run()
    // 销毁窗口
    ->destroy();