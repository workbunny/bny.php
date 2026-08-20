package com.bny.app;

import android.app.Activity;
import android.webkit.JavascriptInterface;

/**
 * WebView JS 桥: 暴露给页面 window.Android。
 * 所有能力转发到 BridgeServer 的同名原生实现 (与 PHP socket 复用同一套逻辑)。
 */
public class PhpBridge {

    private final Activity activity;
    private final BridgeServer bridge;

    public PhpBridge(Activity activity, BridgeServer bridge) {
        this.activity = activity;
        this.bridge = bridge;
    }

    @JavascriptInterface
    public void showToast(String message) {
        bridge.showToast(message, false);
    }

    @JavascriptInterface
    public String getUid() {
        return bridge.androidUid();
    }

    @JavascriptInterface
    public String clipboardGet() {
        return bridge.clipboardGet();
    }

    @JavascriptInterface
    public void clipboardSet(String text) {
        bridge.clipboardSet(text);
    }

    @JavascriptInterface
    public void vibrate(int ms) {
        bridge.vibrate(ms);
    }

    @JavascriptInterface
    public void openUrl(String url) {
        bridge.openUrl(url);
    }

    /**
     * 拉起系统文件选择器。结果为异步, 通过 window.bnyOnPick({path,canceled}) 回调。
     */
    @JavascriptInterface
    public void pickFile(String mime) {
        bridge.pickFileFromJs(mime);
    }
}