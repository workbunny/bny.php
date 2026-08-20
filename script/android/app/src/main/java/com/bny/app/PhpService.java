package com.bny.app;

import android.app.Service;
import android.content.Intent;
import android.os.IBinder;

/**
 * Keeps track of the app being removed from recents (swipe close),
 * so we can stop the PHP app before the process dies.
 */
public class PhpService extends Service {

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        return START_NOT_STICKY;
    }

    @Override
    public void onTaskRemoved(Intent rootIntent) {
        Thread t = new Thread(() -> {
            try {
                PhpRuntime.init(this).stop();
            } catch (Exception ignored) {
            }
            stopSelf();
        });
        t.start();
    }

    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }
}
