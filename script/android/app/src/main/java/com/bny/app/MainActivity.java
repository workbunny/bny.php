package com.bny.app;

import android.annotation.SuppressLint;
import android.app.Activity;
import android.content.Intent;
import android.content.pm.PackageInfo;
import android.graphics.Color;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.os.SystemClock;
import android.util.Log;
import android.view.View;
import android.view.WindowManager;
import android.webkit.WebResourceError;
import android.webkit.WebResourceRequest;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.widget.Button;
import android.widget.TextView;
import android.widget.Toast;

import java.util.ArrayList;
import java.util.List;

/**
 * WebView 壳入口
 *
 * 流程: PhpRuntime 部署 payload -> 启动 php -> WebView 加载 127.0.0.1:port
 * 全部进程/部署逻辑见 PhpRuntime, 划掉卡片兜底停止见 PhpService
 */
public class MainActivity extends Activity {

    private static final String TAG = "BnyApp";
    /** 2 秒内连按两次返回才退出 */
    private static final long EXIT_CONFIRM_MS = 2000;

    private WebView webView;
    private View overlay;
    private TextView statusText;
    private Button retryButton;
    private long lastBackAt = 0;
    private BridgeServer bridge;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setupStatusBar();
        setContentView(R.layout.activity_main);
        webView = (WebView) findViewById(R.id.webview);
        overlay = findViewById(R.id.overlay);
        statusText = (TextView) findViewById(R.id.status_text);
        retryButton = (Button) findViewById(R.id.retry_button);
        retryButton.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                boot();
            }
        });
        setupWebView();
        // 启动本地 socket 桥, 并按包名隔离暴露给 JS window.Android
        bridge = new BridgeServer(this);
        bridge.setWebView(webView);
        bridge.start();
        webView.addJavascriptInterface(new PhpBridge(this, bridge), "Android");
        // 注册任务移除回调, 划掉卡片时优雅停止 php
        startService(new Intent(this, PhpService.class));
        boot();
    }

    /**
     * 保留系统状态栏(显示时间/电量), 但让状态栏透明、内容顶到其后。
     * 这样顶部不再是色带，而是透过状态栏露出 WebView 内容自己的一色背景。
     */
    @SuppressWarnings("deprecation")
    private void setupStatusBar() {
        // 不全屏: 移除隐藏状态栏的 FLAG
        getWindow().clearFlags(WindowManager.LayoutParams.FLAG_FULLSCREEN);
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            getWindow().setStatusBarColor(Color.TRANSPARENT);
        }
        // 内容绘制到状态栏后方(edge-to-edge), 状态栏本身透明
        int flags = View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                | View.SYSTEM_UI_FLAG_LAYOUT_STABLE;
        // API 23+: 状态栏图标用深色(白色背景下才看得清时间/电量)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            flags |= View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR;
        }
        getWindow().getDecorView().setSystemUiVisibility(flags);
    }

    /**
     * 每次窗口重新获得焦点(如从通知栏/返回)后, 再重设一次, 避免状态栏被重置。
     */
    @Override
    public void onWindowFocusChanged(boolean hasFocus) {
        super.onWindowFocusChanged(hasFocus);
        if (hasFocus) {
            setupStatusBar();
        }
    }

    @SuppressLint("SetJavaScriptEnabled")
    private void setupWebView() {
        WebSettings s = webView.getSettings();
        s.setJavaScriptEnabled(true);
        s.setDomStorageEnabled(true);
        webView.setWebViewClient(new WebViewClient() {
            @Override
            public boolean shouldOverrideUrlLoading(WebView view, String url) {
                view.loadUrl(url);
                return true;
            }

            @Override
            public void onReceivedError(WebView view, WebResourceRequest request, WebResourceError error) {
                if (Build.VERSION.SDK_INT >= 23 && !request.isForMainFrame()) {
                    return;
                }
                fail(error.getDescription());
            }
        });
    }

    /** 部署 + 启动 + 加载页面 */
    private void boot() {
        runOnUiThread(new Runnable() {
            @Override
            public void run() {
                retryButton.setVisibility(View.GONE);
                overlay.setVisibility(View.VISIBLE);
                statusText.setText(R.string.status_deploying);
            }
        });
        new Thread(new Runnable() {
            @Override
            public void run() {
                try {
                    final PhpRuntime rt = PhpRuntime.init(getApplicationContext());
                    rt.ensureDeployed();
                    setStatus(R.string.status_starting);
                    rt.start();
                    setStatus(R.string.status_loading);
                    runOnUiThread(new Runnable() {
                        @Override
                        public void run() {
                            overlay.setVisibility(View.GONE);
                            webView.loadUrl(rt.url());
                        }
                    });
                } catch (final Exception e) {
                    final String log = PhpRuntime.get() != null ? PhpRuntime.get().logTail() : "";
                    Log.e(TAG, "boot failed", e);
                    Log.e(TAG, "---- php output ----\n" + log);
                    runOnUiThread(new Runnable() {
                        @Override
                        public void run() {
                            fail(e.getMessage() == null ? e.toString() : e.getMessage(), log);
                        }
                    });
                }
            }
        }, "bny-boot").start();
    }

    private void setStatus(final int resId) {
        runOnUiThread(new Runnable() {
            @Override
            public void run() {
                statusText.setText(resId);
            }
        });
    }

    private void fail(CharSequence message) {
        fail(message, "");
    }

    private void fail(CharSequence message, String log) {
        overlay.setVisibility(View.VISIBLE);
        StringBuilder sb = new StringBuilder(getString(R.string.status_failed))
                .append("\n").append(message);
        if (log != null && !log.isEmpty()) {
            sb.append("\n\n").append(log);
        }
        statusText.setText(sb);
        retryButton.setVisibility(View.VISIBLE);
    }

    @Override
    protected void onDestroy() {
        // 关闭本地 socket 桥并让挂起的 pickFile 全部结束
        if (bridge != null) {
            bridge.stop();
        }
        // 退出即停止 (后台线程执行, stop 内部含 stop 命令/端口等待, 避免阻塞 UI)
        final PhpRuntime rt = PhpRuntime.get();
        if (rt != null) {
            new Thread(new Runnable() {
                @Override
                public void run() {
                    rt.stop();
                }
            }, "bny-stop").start();
        }
        super.onDestroy();
    }

    /**
     * 文件选择器结果: 转发给 BridgeServer, 由其把结果写回挂起的 PHP socket (或回调 JS)。
     */
    @Override
    protected void onActivityResult(int requestCode, int resultCode, Intent data) {
        if ((requestCode == BridgeServer.PICK_FILE_REQUEST
                || requestCode == BridgeServer.PICK_FILES_REQUEST) && bridge != null) {
            List<String> paths = new ArrayList<>();
            if (resultCode == Activity.RESULT_OK && data != null) {
                if (data.getData() != null) {
                    paths.add(BridgeServer.uriToFile(this, data.getData()));
                }
                if (data.getClipData() != null && data.getClipData().getItemCount() > 0) {
                    for (int i = 0; i < data.getClipData().getItemCount(); i++) {
                        Uri u = data.getClipData().getItemAt(i).getUri();
                        if (u != null) {
                            paths.add(BridgeServer.uriToFile(this, u));
                        }
                    }
                }
            }
            bridge.onPickResults(paths, resultCode != Activity.RESULT_OK || paths.isEmpty());
            return;
        }
        super.onActivityResult(requestCode, resultCode, data);
    }

    /**
     * 返回键: WebView 可后退则后退, 否则 2 秒内再按一次才退出 (防误触)
     */
    @Override
    public void onBackPressed() {
        if (webView.canGoBack()) {
            webView.goBack();
            return;
        }
        long now = SystemClock.elapsedRealtime();
        if (now - lastBackAt < EXIT_CONFIRM_MS) {
            super.onBackPressed();
        } else {
            lastBackAt = now;
            Toast.makeText(this, R.string.press_back_again, Toast.LENGTH_SHORT).show();
        }
    }
}
