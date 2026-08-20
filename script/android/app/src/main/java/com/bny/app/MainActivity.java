package com.bny.app;

import android.annotation.SuppressLint;
import android.app.Activity;
import android.content.Intent;
import android.os.Build;
import android.os.Bundle;
import android.os.SystemClock;
import android.util.Log;
import android.view.View;
import android.webkit.WebResourceError;
import android.webkit.WebResourceRequest;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.widget.Button;
import android.widget.TextView;
import android.widget.Toast;

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

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
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
        // 注册任务移除回调, 划掉卡片时优雅停止 php
        startService(new Intent(this, PhpService.class));
        boot();
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
