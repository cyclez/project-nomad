package com.emergency.nomad;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.Service;
import android.content.Intent;
import android.os.Build;
import android.os.IBinder;
import java.io.File;

/**
 * Minimal foreground service that launches and supervises the emergency daemon.
 * No UI. Starts at boot via BootReceiver, or manually via adb/usb-push.
 *
 * The daemon binary lives at RUNTIME_DIR/daemon/nomad-daemon.
 * This service just keeps it alive.
 */
public class DaemonService extends Service {

    private static final String CHANNEL_ID = "nomad_daemon";
    private static final int NOTIFICATION_ID = 1;
    private static final String RUNTIME_DIR = "/data/local/tmp/emergency-nomad";
    private static final String DAEMON_PATH = RUNTIME_DIR + "/daemon/nomad-daemon";

    private Process daemonProcess;
    private Thread watchdog;
    private volatile boolean running = false;

    @Override
    public void onCreate() {
        super.onCreate();
        createNotificationChannel();
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        // Foreground service required on API 26+
        Notification notification = buildNotification();
        startForeground(NOTIFICATION_ID, notification);

        if (!running) {
            running = true;
            startWatchdog();
        }

        // Restart if killed by system
        return START_STICKY;
    }

    @Override
    public void onDestroy() {
        running = false;
        killDaemon();
        super.onDestroy();
    }

    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }

    private void startWatchdog() {
        watchdog = new Thread(new Runnable() {
            @Override
            public void run() {
                while (running) {
                    if (!isDaemonRunning()) {
                        launchDaemon();
                    }
                    try {
                        Thread.sleep(5000);
                    } catch (InterruptedException e) {
                        break;
                    }
                }
            }
        }, "nomad-watchdog");
        watchdog.setDaemon(true);
        watchdog.start();
    }

    private void launchDaemon() {
        File daemon = new File(DAEMON_PATH);
        if (!daemon.exists()) {
            return;
        }

        try {
            // Use sh to READ the script (not exec) — SELinux allows read
            // on shell_data_file from untrusted_app, but blocks execute.
            ProcessBuilder pb = new ProcessBuilder(
                "/system/bin/sh", DAEMON_PATH
            );
            pb.directory(new File(RUNTIME_DIR));
            // Pass writable temp dir — the daemon can't write to /data/local/tmp/
            // (SELinux shell_data_file), but CAN write to the app's own data dir.
            pb.environment().put("NOMAD_TMPDIR", getFilesDir().getAbsolutePath());
            pb.redirectErrorStream(true);
            pb.redirectOutput(ProcessBuilder.Redirect.to(new File("/dev/null")));
            daemonProcess = pb.start();
        } catch (Exception e) {
            // Silent — watchdog will retry
        }
    }

    private boolean isDaemonRunning() {
        if (daemonProcess == null) return false;
        try {
            daemonProcess.exitValue();
            return false; // exited
        } catch (IllegalThreadStateException e) {
            return true; // still running
        }
    }

    private void killDaemon() {
        if (daemonProcess != null) {
            daemonProcess.destroy();
            daemonProcess = null;
        }
    }

    private void createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= 26) {
            NotificationChannel channel = new NotificationChannel(
                CHANNEL_ID,
                "Emergency Nomad",
                NotificationManager.IMPORTANCE_LOW
            );
            channel.setDescription("Keeps the emergency daemon running");
            channel.setShowBadge(false);
            NotificationManager nm = getSystemService(NotificationManager.class);
            if (nm != null) {
                nm.createNotificationChannel(channel);
            }
        }
    }

    @SuppressWarnings("deprecation")
    private Notification buildNotification() {
        if (Build.VERSION.SDK_INT >= 26) {
            return new Notification.Builder(this, CHANNEL_ID)
                .setContentTitle("Emergency Nomad")
                .setContentText("Offline runtime active")
                .setSmallIcon(android.R.drawable.ic_menu_compass)
                .setOngoing(true)
                .build();
        } else {
            // API 21-25: no channels
            return new Notification.Builder(this)
                .setContentTitle("Emergency Nomad")
                .setContentText("Offline runtime active")
                .setSmallIcon(android.R.drawable.ic_menu_compass)
                .setOngoing(true)
                .setPriority(Notification.PRIORITY_LOW)
                .build();
        }
    }
}
