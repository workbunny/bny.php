<?php

// 严格模式

require 'vendor/autoload.php';

use Workerman\Worker;
use Workerman\Protocols\Http\Request;
use Workerman\Protocols\Http\Response;
use Workerman\Connection\TcpConnection;

// 配置参数
$webRoot = __DIR__ . '/tp/public';    // 项目public目录（存放入口文件）
$host = '0.0.0.0';                // 监听地址
$port = 8787;                     // 监听端口

// 创建HTTP Worker
$worker = new Worker("http://{$host}:{$port}");
$worker->name = 'Bny-Server';
$worker->count = 4; // 根据CPU核心数设置

$worker->onMessage = function (TcpConnection $connection, Request $request) use ($webRoot) {
    // 1. 初始化超全局变量
    $_SERVER = [
        'REQUEST_METHOD'    => $request->method(),
        'REQUEST_URI'       => $request->uri(),
        'QUERY_STRING'      => $request->queryString(),
        'SERVER_PROTOCOL'   => 'HTTP/'.$request->protocolVersion(),
        'HTTP_HOST'         => $request->host(),
        'HTTP_USER_AGENT'  => $request->header('user-agent'),
        'HTTP_ACCEPT'      => $request->header('accept'),
        'CONTENT_TYPE'     => $request->header('content-type'),
        'CONTENT_LENGTH'    => $request->header('content-length'),
        'SCRIPT_NAME'      => '/index.php', // 统一入口
        'SCRIPT_FILENAME'  => $webRoot . '/index.php',
        'PHP_SELF'          => '/index.php',
    ];

    // 2. 填充请求数据
    $_GET = $request->get();
    $_POST = $request->post();
    $_COOKIE = $request->cookie();
    $_FILES = $request->file();
    $_REQUEST = array_merge($_GET, $_POST);

    // 3. 设置临时文件路径（用于文件上传）
    if (!empty($_FILES)) {
        foreach ($_FILES as &$file) {
            $file['tmp_name'] = tempnam(sys_get_temp_dir(), 'workerman_upload_');
            file_put_contents($file['tmp_name'], $file['file_data']);
            unset($file['file_data']);
        }
    }

    // 4. 捕获输出缓冲区
    ob_start();
    
    try {
        // 执行入口文件（模拟FPM环境）
        include $webRoot . '/index.php';
    } catch (\Throwable $e) {
        // 异常处理
        ob_end_clean();
        $connection->send(new Response(500, [], "Internal Server Error: " . $e->getMessage()));
        return;
    }

    $content = ob_get_clean();

    // 5. 发送响应
    $response = new Response(
        200,
        ['Content-Type' => 'text/html; charset=utf-8'],
        $content
    );

    $connection->send($response);
};

// 运行Worker
Worker::runAll();