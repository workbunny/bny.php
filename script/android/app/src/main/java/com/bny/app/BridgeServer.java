package com.bny.app;

import android.app.Activity;
import android.content.ClipData;
import android.content.ClipboardManager;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageInfo;
import android.database.Cursor;
import android.net.LocalServerSocket;
import android.net.LocalSocket;
import android.net.Uri;
import android.os.Build;
import android.os.Process;
import android.os.VibrationEffect;
import android.os.Vibrator;
import android.provider.MediaStore;
import android.util.Log;
import android.webkit.WebView;

import org.json.JSONObject;

import java.io.BufferedReader;
import java.io.File;
import java.io.InputStreamReader;
import java.io.OutputStream;
import java.nio.charset.StandardCharsets;
import java.util.concurrent.ConcurrentLinkedQueue;
import java.util.concurrent.atomic.AtomicBoolean;

/**
 * PHP <-> 原生能力桥: 本地 Unix socket server (app 私有目录).
 *
 * socket 文件: getFilesDir()/bridge.sock  (PHP 用 unix:///data/data/<pkg>/files/bridge.sock 连接)
 * 协议: 换行分隔 JSON。请求一行 {"id":<n>,"cmd":"<name>","params":{...}};
 *       响应一行 {"id":<n>,"ok":true,"data":{...}} 或 {"id":<n>,"ok":false,"error":"..."}
 *
 * 同步命令直接回响应; pickFile 为异步命令, 挂起该连接, 由 Activity.onActivityResult 回调写回。
 */
public class BridgeServer {

    private static final String TAG = "BnyApp";

    /** getFilesDir 下 socket 文件名 (按包名隔离的私有目录) */
    private static final String SOCK_FILE = "bridge.sock";

    /** 文件选择请求码 (旧式 startActivityForResult) */
    public static final int PICK_FILE_REQUEST = 9001;

    // 命令分派返回码
    private static final int KEEP = 0;       // 已回响应, 继续读下一行
    private static final int CLOSE = 1;      // 出错, 关闭连接
    private static final int SUSPEND = 2;    // pickFile: 挂起, socket 保留待异步回写

    /** 一次挂起的 pickFile 请求 (PHP socket 或 JS 来源) */
    private static class Pending {
        final long id;
        final OutputStream out;   // PHP socket 来源(用于回写), null 表示 JS 来源
        final WebView jsWebView;  // JS 来源(用于 evaluateJavascript 回调), null 表示 socket 来源
        Pending(long id, OutputStream out, WebView jsWebView) {
            this.id = id;
            this.out = out;
            this.jsWebView = jsWebView;
        }
    }

    private final Context app;
    private final Activity activity;
    private final ConcurrentLinkedQueue<Pending> pendingPicks = new ConcurrentLinkedQueue<>();
    private final AtomicBoolean running = new AtomicBoolean(false);

    private LocalServerSocket server;
    private Thread acceptThread;
    private WebView webView;

    public BridgeServer(Activity activity) {
        this.activity = activity;
        this.app = activity.getApplicationContext();
    }

    /** 供 JS pickFile 回调使用 (MainActivity 注入) */
    public void setWebView(WebView webView) {
        this.webView = webView;
    }

    public String sockPath() {
        return new File(app.getFilesDir(), SOCK_FILE).getAbsolutePath();
    }

    // ------------------------------------------------------------------
    // Lifecycle
    // ------------------------------------------------------------------

    public synchronized void start() {
        if (running.get()) {
            return;
        }
        File sock = new File(app.getFilesDir(), SOCK_FILE);
        if (sock.exists() && !sock.delete()) {
            Log.w(TAG, "stale socket file could not be removed: " + sock.getAbsolutePath());
        }
        try {
            server = new LocalServerSocket(sockPath());
            running.set(true);
            acceptThread = new Thread(this::acceptLoop, "bny-bridge");
            acceptThread.start();
            Log.i(TAG, "bridge listening on " + sockPath());
        } catch (Exception e) {
            Log.e(TAG, "bridge start failed", e);
        }
    }

    public synchronized void stop() {
        running.set(false);
        if (acceptThread != null) {
            acceptThread.interrupt();
            acceptThread = null;
        }
        if (server != null) {
            try {
                server.close();
            } catch (Exception ignored) {
            }
            server = null;
        }
        File sock = new File(app.getFilesDir(), SOCK_FILE);
        if (sock.exists()) {
            sock.delete();
        }
        // 挂起的 pickFile 一律回错误并关闭
        Pending p;
        while ((p = pendingPicks.poll()) != null) {
            if (p.out != null) {
                try {
                    writeLine(p.out, errJson(p.id, "bridge stopped").toString());
                    p.out.close();
                } catch (Exception ignored) {
                }
            }
        }
    }

    // ------------------------------------------------------------------
    // Socket accept / connection
    // ------------------------------------------------------------------

    private void acceptLoop() {
        while (running.get()) {
            LocalSocket client;
            try {
                client = server.accept();
            } catch (Exception e) {
                if (running.get()) {
                    Log.w(TAG, "bridge accept error", e);
                }
                break;
            }
            new Thread(() -> handleConnection(client), "bny-bridge-conn").start();
        }
    }

    private void handleConnection(LocalSocket client) {
        boolean keepOpen = false;
        try {
            OutputStream out = client.getOutputStream();
            BufferedReader in = new BufferedReader(
                    new InputStreamReader(client.getInputStream(), StandardCharsets.UTF_8));
            String line;
            while ((line = in.readLine()) != null) {
                if (line.trim().isEmpty()) {
                    continue;
                }
                int r = dispatch(line, out);
                if (r == SUSPEND) {
                    keepOpen = true; // socket 转移给 pending, 连接线程退出但 socket 保留
                    break;
                }
                if (r == CLOSE) {
                    break;
                }
            }
        } catch (Exception e) {
            Log.w(TAG, "bridge conn error", e);
        } finally {
            if (!keepOpen) {
                try {
                    client.close();
                } catch (Exception ignored) {
                }
            }
        }
    }

    // ------------------------------------------------------------------
    // Command dispatch (PHP over socket)
    // ------------------------------------------------------------------

    private int dispatch(String line, OutputStream out) {
        try {
            JSONObject req = new JSONObject(line);
            long id = req.optLong("id", -1);
            String cmd = req.optString("cmd", "");
            JSONObject params = req.optJSONObject("params");
            if (params == null) {
                params = new JSONObject();
            }

            switch (cmd) {
                case "toast": {
                    String msg = params.optString("message", "");
                    if (msg.isEmpty()) {
                        return respondError(out, id, "missing message");
                    }
                    showToast(msg, params.optBoolean("long", false));
                    return respondOk(out, id, null);
                }
                case "getUid":
                    return respondOk(out, id, Process.myUid());
                case "getVersion": {
                    JSONObject data = new JSONObject();
                    try {
                        PackageInfo pi = app.getPackageManager().getPackageInfo(
                                app.getPackageName(), 0);
                        data.put("versionName", pi.versionName == null ? "" : pi.versionName);
                        data.put("build", pi.versionCode);
                    } catch (Exception e) {
                        data.put("versionName", "");
                        data.put("build", 0);
                    }
                    return respondOk(out, id, data);
                }
                case "clipboard_get":
                    return respondOk(out, id, clipboardGet());
                case "clipboard_set": {
                    String text = params.optString("text", "");
                    if (text.isEmpty()) {
                        return respondError(out, id, "missing text");
                    }
                    clipboardSet(text);
                    return respondOk(out, id, null);
                }
                case "vibrate":
                    vibrate(params.optInt("durationMs", 200));
                    return respondOk(out, id, null);
                case "openUrl": {
                    String url = params.optString("url", "");
                    if (url.isEmpty()) {
                        return respondError(out, id, "missing url");
                    }
                    openUrl(url);
                    return respondOk(out, id, null);
                }
                case "pickFile": {
                    String mime = params.optString("mime", "*/*");
                    pendingPicks.add(new Pending(id, out, null));
                    launchPick(mime);
                    return SUSPEND;
                }
                default:
                    return respondError(out, id, "unknown cmd: " + cmd);
            }
        } catch (Exception e) {
            Log.w(TAG, "dispatch error", e);
            try {
                writeLine(out, errJson(reqIdOf(line), "invalid request").toString());
            } catch (Exception ignored) {
            }
            return CLOSE;
        }
    }

    private static long reqIdOf(String line) {
        try {
            return new JSONObject(line).optLong("id", -1);
        } catch (Exception e) {
            return -1;
        }
    }

    // ------------------------------------------------------------------
    // Response helpers
    // ------------------------------------------------------------------

    private static JSONObject okJson(long id) {
        JSONObject o = new JSONObject();
        try {
            o.put("id", id);
            o.put("ok", true);
        } catch (Exception ignored) {
        }
        return o;
    }

    private static JSONObject errJson(long id, String msg) {
        JSONObject o = new JSONObject();
        try {
            o.put("id", id);
            o.put("ok", false);
            o.put("error", msg);
        } catch (Exception ignored) {
        }
        return o;
    }

    private static void writeLine(OutputStream out, String line) throws Exception {
        out.write(line.getBytes(StandardCharsets.UTF_8));
        out.write('\n');
        out.flush();
    }

    private int respondOk(OutputStream out, long id, Object data) throws Exception {
        JSONObject o = okJson(id);
        if (data != null) {
            o.put("data", data);
        }
        writeLine(out, o.toString());
        return KEEP;
    }

    private int respondError(OutputStream out, long id, String msg) throws Exception {
        writeLine(out, errJson(id, msg).toString());
        return CLOSE;
    }

    // ------------------------------------------------------------------
    // Native capability primitives (供 socket 与 PhpBridge 复用)
    // ------------------------------------------------------------------

    public String androidUid() {
        return String.valueOf(Process.myUid());
    }

    public void showToast(final String message, final boolean longToast) {
        activity.runOnUiThread(new Runnable() {
            @Override
            public void run() {
                android.widget.Toast.makeText(
                        activity, message,
                        longToast ? android.widget.Toast.LENGTH_LONG : android.widget.Toast.LENGTH_SHORT)
                        .show();
            }
        });
    }

    public String clipboardGet() {
        ClipboardManager cm =
                (ClipboardManager) app.getSystemService(Context.CLIPBOARD_SERVICE);
        if (cm == null || !cm.hasPrimaryClip() || cm.getPrimaryClip() == null
                || cm.getPrimaryClip().getItemCount() == 0) {
            return "";
        }
        ClipData.Item item = cm.getPrimaryClip().getItemAt(0);
        CharSequence text = item.getText();
        return text == null ? "" : text.toString();
    }

    public void clipboardSet(String text) {
        ClipboardManager cm =
                (ClipboardManager) app.getSystemService(Context.CLIPBOARD_SERVICE);
        if (cm != null) {
            cm.setPrimaryClip(ClipData.newPlainText("bny", text));
        }
    }

    public void vibrate(int ms) {
        Vibrator v = (Vibrator) app.getSystemService(Context.VIBRATOR_SERVICE);
        if (v == null || !v.hasVibrator()) {
            return;
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            v.vibrate(VibrationEffect.createOneShot(ms, VibrationEffect.DEFAULT_AMPLITUDE));
        } else {
            v.vibrate(ms);
        }
    }

    public void openUrl(String url) {
        try {
            Intent intent = new Intent(Intent.ACTION_VIEW, Uri.parse(url));
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            activity.startActivity(intent);
        } catch (Exception e) {
            Log.w(TAG, "openUrl failed: " + url, e);
        }
    }

    /** JS 来源的 pickFile: 挂起请求, 结果经 WebView 回调 window.bnyOnPick(path, canceled) */
    public void pickFileFromJs(String mime) {
        pendingPicks.add(new Pending(-1, null, webView));
        launchPick(mime == null || mime.isEmpty() ? "*/*" : mime);
    }

    private void launchPick(final String mime) {
        final Intent intent = new Intent(Intent.ACTION_GET_CONTENT);
        intent.addCategory(Intent.CATEGORY_OPENABLE);
        intent.setType(mime);
        activity.runOnUiThread(new Runnable() {
            @Override
            public void run() {
                try {
                    activity.startActivityForResult(intent, PICK_FILE_REQUEST);
                } catch (Exception e) {
                    Log.w(TAG, "no handler for pickFile", e);
                    bridgePickDone(null, true);
                }
            }
        });
    }

    /** Activity.onActivityResult 转发入口 */
    public void onPickResult(String path, boolean canceled) {
        bridgePickDone(path, canceled);
    }

    private void bridgePickDone(String path, boolean canceled) {
        Pending p = pendingPicks.poll();
        if (p == null) {
            return;
        }
        if (p.out != null) {
            // PHP socket 来源: 回写一行 JSON 并关闭
            try {
                if (canceled || path == null) {
                    writeLine(p.out, errJson(p.id, "cancelled").toString());
                } else {
                    JSONObject data = new JSONObject();
                    data.put("path", path);
                    JSONObject o = okJson(p.id);
                    o.put("data", data);
                    writeLine(p.out, o.toString());
                }
                p.out.close();
            } catch (Exception e) {
                Log.w(TAG, "pick write failed", e);
            }
        } else if (p.jsWebView != null) {
            // JS 来源: 回调 window.bnyOnPick(path, canceled)
            final WebView wv = p.jsWebView;
            final String arg;
            try {
                JSONObject a = new JSONObject();
                a.put("path", canceled ? null : path);
                a.put("canceled", canceled);
                arg = a.toString();
            } catch (Exception e) {
                return;
            }
            wv.post(new Runnable() {
                @Override
                public void run() {
                    wv.evaluateJavascript(
                            "window.bnyOnPick && window.bnyOnPick(" + arg + ");", null);
                }
            });
        }
    }

    /** 尝试把 Content Uri 转成真实文件路径; 失败时回退返回原始 uri 字符串。 */
    public static String uriToFile(Context ctx, Uri uri) {
        if (uri == null) {
            return null;
        }
        if ("file".equals(uri.getScheme())) {
            return uri.getPath();
        }
        String path = null;
        try (Cursor cur = ctx.getContentResolver()
                .query(uri, new String[]{MediaStore.MediaColumns.DATA}, null, null, null)) {
            if (cur != null && cur.moveToFirst()) {
                int idx = cur.getColumnIndex(MediaStore.MediaColumns.DATA);
                if (idx >= 0) {
                    path = cur.getString(idx);
                }
            }
        } catch (Exception ignored) {
        }
        return (path != null && !path.isEmpty()) ? path : uri.toString();
    }
}