<?php

namespace Bny\Worker;

use Workerman\Worker;
use Workerman\Protocols\Http\Request;
use Workerman\Protocols\Http\Response;
use Workerman\Connection\TcpConnection;

class Main
{
    private string $host = '0.0.0.0';
    private int $port = 8787;
    private Worker $worker;

    /**
     * 构造函数
     */
    public function __construct()
    {
        $worker = new Worker("http://{$this->host}:{$this->port}");
        $worker->name = 'Bny-Worker';
        $worker->count = 4;
        $worker->onMessage = function (TcpConnection $connection, Request $request) {
            $this->onMessage($connection, $request);
        };
        $this->worker = $worker;
    }

    /**
     * 处理请求
     *
     * @param TcpConnection $connection 连接对象
     * @param Request $request 请求对象
     * @return void
     */
    public function onMessage(TcpConnection $connection, Request $request)
    {
        // 1. 初始化超全局变量
        $_SERVER = [
            'REQUEST_METHOD'    => $request->method(),
            'REQUEST_URI'       => $request->uri(),
            'QUERY_STRING'      => $request->queryString(),
            'SERVER_PROTOCOL'   => 'HTTP/' . $request->protocolVersion(),
            'HTTP_HOST'         => $request->host(),
            'HTTP_USER_AGENT'  => $request->header('user-agent'),
            'HTTP_ACCEPT'      => $request->header('accept'),
            'CONTENT_TYPE'     => $request->header('content-type'),
            'CONTENT_LENGTH'    => $request->header('content-length'),
            'SCRIPT_NAME'      => '/index.php', // 统一入口
            'SCRIPT_FILENAME'  => WEB_ROOT . '/index.php',
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
            include WEB_ROOT . '/index.php';
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
    }

    /**
     * 运行服务
     *
     * @return void
     */
    public function run()
    {
        $this->worker::runAll();
    }
}
