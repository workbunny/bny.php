package com.bny.app;

import android.content.Context;
import android.util.Log;

import org.json.JSONObject;

import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.net.InetSocketAddress;
import java.net.Socket;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import java.util.Map;
import java.util.concurrent.TimeUnit;

/**
 * Manages the embedded PHP runtime (PHP binary + shared libs) and the PHP
 * application lifecycle: deploy -> start -> poll -> stop.
 */
public final class PhpRuntime {

    private static final String TAG = "BnyApp";
    private static final String HOST = "127.0.0.1";
    private static final int DEFAULT_PORT = 8787;
    private static final String DEFAULT_START = "-S 127.0.0.1:8787 ./";
    private static final String DEFAULT_STOP = "";

    private static PhpRuntime sInstance;

    private final Context app;
    private final File filesDir;
    private final File nativeLibDir;
    private final File appDir;
    private final File tmpDir;
    private final Object lock = new Object();

    private int port = DEFAULT_PORT;
    private String startCommand = DEFAULT_START;
    private String stopCommand = DEFAULT_STOP;
    // php 配置 (复用打包时 bny.json 的 ini / define)
    private String iniPath = "";
    private List<String> defineArgs = new ArrayList<>();
    // 前台进程引用 (stop 未配置时, 如 php -S 内置服务器, 退出时直接销毁)
    private Process foregroundProcess;

    private PhpRuntime(Context context) {
        this.app = context.getApplicationContext();
        this.filesDir = app.getFilesDir();
        this.nativeLibDir = new File(app.getApplicationInfo().nativeLibraryDir);
        this.appDir = new File(filesDir, "app");
        this.tmpDir = new File(filesDir, "tmp");
        loadRuntimeConfig();
    }

    public static synchronized PhpRuntime init(Context context) {
        if (sInstance == null) {
            sInstance = new PhpRuntime(context);
        }
        return sInstance;
    }

    public static PhpRuntime get() {
        return sInstance;
    }

    public String url() {
        return "http://" + HOST + ":" + port + "/";
    }

    // ------------------------------------------------------------------
    // Runtime config, read from assets/runtime.json:
    // {"port":8787,"start":"./start.php start -d","stop":"./start.php stop",
    //  "ini":"./php.ini","define":["memory_limit=256M"]}
    // ------------------------------------------------------------------

    private void loadRuntimeConfig() {
        try {
            JSONObject json = new JSONObject(readAssetText("runtime.json"));
            port = json.optInt("port", DEFAULT_PORT);
            startCommand = json.optString("start", DEFAULT_START).trim();
            stopCommand = json.optString("stop", DEFAULT_STOP).trim();
            iniPath = json.optString("ini", "").trim();
            defineArgs = new ArrayList<>();
            org.json.JSONArray arr = json.optJSONArray("define");
            if (arr != null) {
                for (int i = 0; i < arr.length(); i++) {
                    String d = arr.optString(i, "").trim();
                    if (!d.isEmpty()) {
                        defineArgs.add(d);
                    }
                }
            }
        } catch (Exception e) {
            Log.w(TAG, "runtime.json missing or invalid, using defaults", e);
        }
    }

    // ------------------------------------------------------------------
    // Deployment: copy app + usr trees from APK assets into filesDir
    // ------------------------------------------------------------------

    public void ensureDeployed() throws IOException {
        synchronized (lock) {
            String hash = extractHash(readAssetText("payload_manifest"));
            File markerFile = new File(filesDir, ".deploy_marker");
            String current = readFile(markerFile);
            if (hash.equals(current)) {
                ensureRuntimeDirs();
                return;
            }
            Log.i(TAG, "deploying app from assets...");
            deleteRecursive(appDir);
            deleteRecursive(new File(filesDir, "usr"));

            copyAssetTree("app", appDir);
            copyAssetTree("usr", new File(filesDir, "usr"));
            ensureRuntimeDirs();
            writeFile(markerFile, hash);
            Log.i(TAG, "deploy done");
        }
    }

    private static String extractHash(String json) {
        int i = json.indexOf(':');
        if (i < 0) {
            return json.trim();
        }
        int a = json.indexOf('"', i + 1);
        int b = a >= 0 ? json.indexOf('"', a + 1) : -1;
        return (a >= 0 && b > a) ? json.substring(a + 1, b) : json.trim();
    }

    private String readAssetText(String name) throws IOException {
        try (InputStream in = app.getAssets().open(name)) {
            ByteArrayOutputStream bos = new ByteArrayOutputStream();
            byte[] buf = new byte[8192];
            int n;
            while ((n = in.read(buf)) > 0) {
                bos.write(buf, 0, n);
            }
            return new String(bos.toByteArray(), StandardCharsets.UTF_8);
        }
    }

    /** Recursively copy an asset directory (or a single file) to dest. */
    private void copyAssetTree(String assetPath, File dest) throws IOException {
        String[] children = app.getAssets().list(assetPath);
        if (children == null || children.length == 0) {
            dest.getParentFile().mkdirs();
            try (InputStream in = app.getAssets().open(assetPath);
                 OutputStream out = new FileOutputStream(dest)) {
                byte[] buf = new byte[64 * 1024];
                int n;
                while ((n = in.read(buf)) > 0) {
                    out.write(buf, 0, n);
                }
            }
            return;
        }
        dest.mkdirs();
        for (String c : children) {
            copyAssetTree(assetPath + "/" + c, new File(dest, c));
        }
    }

    private void ensureRuntimeDirs() {
        new File(appDir, "runtime/logs").mkdirs();
        new File(appDir, "runtime/views").mkdirs();
        new File(appDir, "runtime/sessions").mkdirs();
        new File(appDir, "runtime/tmp").mkdirs();
        tmpDir.mkdirs();
    }

    // ------------------------------------------------------------------
    // Process control
    // ------------------------------------------------------------------

    private File phpBinary() {
        return new File(nativeLibDir, "libphp.so");
    }

    /**
     * php absolute path + [-c ini] + [-d ...] + command split on whitespace.
     * 命令以 "-" 开头 (如 "-S 127.0.0.1:8787 -t ./" 内置服务器) 时为 php 选项;
     * 否则为脚本模式 (如 "./start.php start -d")。
     * 注意: 不插入 "--" 分隔符, 部分 PHP 构建遇到 "--" 会静默退出;
     * php 在脚本名之后本就停止解析自身选项, 脚本参数无需转义。
     */
    private List<String> buildCommand(File php, String command) {
        String trimmed = command.trim();
        List<String> cmd = new ArrayList<>();
        cmd.add(php.getAbsolutePath());
        if (!iniPath.isEmpty()) {
            cmd.add("-c");
            cmd.add(iniPath);
        }
        for (String d : defineArgs) {
            cmd.add("-d");
            cmd.add(d);
        }
        for (String arg : trimmed.split("\\s+")) {
            if (!arg.isEmpty()) {
                cmd.add(arg);
            }
        }
        return cmd;
    }

    public boolean isPortOpen() {
        try (Socket s = new Socket()) {
            s.connect(new InetSocketAddress(HOST, port), 300);
            return true;
        } catch (Exception e) {
            return false;
        }
    }

    public void start() throws Exception {
        synchronized (lock) {
            ensureDeployed();
            if (isPortOpen()) {
                Log.i(TAG, "app already running");
                return;
            }
            File php = phpBinary();
            if (!php.exists()) {
                throw new IOException("php binary not found: " + php);
            }
            php.setExecutable(true, true);

            ProcessBuilder pb = new ProcessBuilder(buildCommand(php, startCommand));
            pb.directory(appDir);
            // Output goes to a file, NOT a pipe: the daemonized PHP process
            // inherits the pipe and never closes it, so reading it would block
            // forever waiting for EOF.
            File startLog = new File(filesDir, "php_start.log");
            pb.redirectErrorStream(true);
            pb.redirectOutput(startLog);
            applyEnv(pb);

            Log.i(TAG, "exec: " + pb.command());
            Process p = pb.start();
            if (stopCommand.isEmpty()) {
                // 前台模式 (如 php -S 内置服务器): 进程持续运行, 保存引用, 退出时直接销毁
                foregroundProcess = p;
                boolean exitedEarly = p.waitFor(3, TimeUnit.SECONDS);
                if (exitedEarly) {
                    foregroundProcess = null;
                    throw new IOException("php exited with code " + p.exitValue()
                            + "\n---- php output ----\n" + tail(readFile(startLog), 2500));
                }
            } else {
                // 守护模式 (如 webman start -d): 启动进程应快速退出
                boolean exited = p.waitFor(40, TimeUnit.SECONDS);
                if (!exited) {
                    p.destroy();
                    throw new IOException("php start timed out\n" + logTail());
                } else if (p.exitValue() != 0) {
                    throw new IOException("php exited with code " + p.exitValue()
                            + "\n---- php output ----\n" + tail(readFile(startLog), 2500)
                            + "\n---- app logs ----\n" + logTail());
                }
            }

            long deadline = System.currentTimeMillis() + 30_000;
            while (System.currentTimeMillis() < deadline) {
                if (isPortOpen()) {
                    Log.i(TAG, "app is up on port " + port);
                    return;
                }
                Thread.sleep(250);
            }
            throw new IOException("app did not start listening on port " + port
                    + "\n---- php output ----\n" + tail(readFile(startLog), 2500)
                    + "\n---- app logs ----\n" + logTail());
        }
    }

    public void stop() {
        synchronized (lock) {
            try {
                if (!isPortOpen() && !hasPidFiles() && foregroundProcess == null) {
                    return;
                }
                // 守护模式: 配置了 stop 命令则优雅停止
                if (!stopCommand.isEmpty()) {
                    File php = phpBinary();
                    if (php.exists()) {
                        ProcessBuilder pb = new ProcessBuilder(buildCommand(php, stopCommand));
                        pb.directory(appDir);
                        pb.redirectErrorStream(true);
                        pb.redirectOutput(new File(filesDir, "php_stop.log"));
                        applyEnv(pb);
                        Log.i(TAG, "exec: " + pb.command());
                        Process p = pb.start();
                        p.waitFor(15, TimeUnit.SECONDS);
                    }
                }
                // 前台模式: 直接销毁前台进程 (如 php -S 内置服务器)
                if (foregroundProcess != null) {
                    Log.i(TAG, "destroying foreground php process");
                    foregroundProcess.destroy();
                    foregroundProcess = null;
                }
            } catch (Exception e) {
                Log.w(TAG, "graceful stop failed", e);
            }
            long deadline = System.currentTimeMillis() + 10_000;
            while (System.currentTimeMillis() < deadline && isPortOpen()) {
                try {
                    Thread.sleep(250);
                } catch (InterruptedException e) {
                    break;
                }
            }
            if (isPortOpen()) {
                killByPidFiles();
            }
        }
    }

    private boolean hasPidFiles() {
        List<File> pidFiles = new ArrayList<>();
        collectPidFiles(new File(appDir, "runtime"), pidFiles);
        return !pidFiles.isEmpty();
    }

    /** Scan appDir/runtime/ (including subdirs) for *.pid and force-kill each pid. */
    private void killByPidFiles() {
        List<File> pidFiles = new ArrayList<>();
        collectPidFiles(new File(appDir, "runtime"), pidFiles);
        for (File f : pidFiles) {
            try {
                String content = readFile(f);
                String pidStr = content == null ? "" : content.trim();
                if (!pidStr.isEmpty()) {
                    int pid = Integer.parseInt(pidStr.split("\\s+")[0]);
                    android.os.Process.killProcess(pid);
                    Log.w(TAG, "force killed pid " + pid + " from " + f.getName());
                }
            } catch (Exception ignored) {
            }
        }
    }

    private void collectPidFiles(File dir, List<File> out) {
        File[] children = dir.listFiles();
        if (children == null) {
            return;
        }
        for (File c : children) {
            if (c.isDirectory()) {
                collectPidFiles(c, out);
            } else if (c.getName().endsWith(".pid")) {
                out.add(c);
            }
        }
    }

    private void applyEnv(ProcessBuilder pb) {
        Map<String, String> env = pb.environment();
        env.put("HOME", filesDir.getAbsolutePath());
        env.put("TMPDIR", tmpDir.getAbsolutePath());
        env.put("LD_LIBRARY_PATH", nativeLibDir.getAbsolutePath());
        env.put("PATH", nativeLibDir.getAbsolutePath() + ":/system/bin:/vendor/bin");

        String icu = findIcuDataDir();
        if (icu != null) {
            env.put("ICU_DATA", icu);
        }
        File cert = new File(filesDir, "usr/etc/tls/cert.pem");
        if (cert.exists()) {
            env.put("SSL_CERT_FILE", cert.getAbsolutePath());
            env.put("SSL_CERT_DIR", cert.getParentFile().getAbsolutePath());
        }
        File resolv = new File(filesDir, "usr/etc/resolv.conf");
        if (resolv.exists()) {
            env.put("RWRAPPER_RESOLV_CONF", resolv.getAbsolutePath());
        }
    }

    private String findIcuDataDir() {
        File icuRoot = new File(filesDir, "usr/share/icu");
        File[] versions = icuRoot.listFiles();
        if (versions != null) {
            for (File v : versions) {
                if (v.isDirectory()) {
                    File[] dats = v.listFiles((d, name) -> name.startsWith("icudt"));
                    if (dats != null && dats.length > 0) {
                        return v.getAbsolutePath();
                    }
                }
            }
        }
        return null;
    }

    // ------------------------------------------------------------------
    // Log helpers (shown in the error screen)
    // ------------------------------------------------------------------

    /** Best-effort tails of every file under appDir/runtime/logs/ plus php_start.log. */
    public String logTail() {
        StringBuilder sb = new StringBuilder();
        File[] logs = new File(appDir, "runtime/logs").listFiles(File::isFile);
        if (logs != null) {
            Arrays.sort(logs);
            for (File f : logs) {
                appendTail(sb, f, 1500);
            }
        }
        appendTail(sb, new File(filesDir, "php_start.log"), 1500);
        return sb.toString();
    }

    private void appendTail(StringBuilder sb, File f, int max) {
        String s = readFile(f);
        if (s == null || s.isEmpty()) {
            return;
        }
        sb.append("[").append(f.getName()).append("]\n").append(tail(s, max)).append("\n");
    }

    // ------------------------------------------------------------------
    // Utils
    // ------------------------------------------------------------------

    private static String tail(String s, int max) {
        if (s == null) {
            return "";
        }
        return s.length() <= max ? s : s.substring(s.length() - max);
    }

    private static String readFile(File f) {
        try (FileInputStream in = new FileInputStream(f)) {
            return new String(readAllBytes(in), StandardCharsets.UTF_8);
        } catch (Exception e) {
            return null;
        }
    }

    private static byte[] readAllBytes(InputStream in) throws IOException {
        ByteArrayOutputStream bos = new ByteArrayOutputStream();
        byte[] buf = new byte[8192];
        int n;
        while ((n = in.read(buf)) > 0) {
            bos.write(buf, 0, n);
        }
        return bos.toByteArray();
    }

    private static void writeFile(File f, String content) throws IOException {
        try (FileOutputStream out = new FileOutputStream(f)) {
            out.write(content.getBytes(StandardCharsets.UTF_8));
        }
    }

    private static void deleteRecursive(File f) {
        if (f == null || !f.exists()) {
            return;
        }
        if (f.isDirectory()) {
            File[] children = f.listFiles();
            if (children != null) {
                for (File c : children) {
                    deleteRecursive(c);
                }
            }
        }
        f.delete();
    }
}
