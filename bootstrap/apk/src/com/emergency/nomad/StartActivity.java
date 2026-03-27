package com.emergency.nomad;

import android.app.Activity;
import android.content.Intent;
import android.os.Build;
import android.os.Bundle;
import android.widget.Toast;

/**
 * Invisible activity that starts the DaemonService and exits.
 * Required because Android 12+ blocks background service starts.
 * Triggered by: adb shell am start com.emergency.nomad/.StartActivity
 */
public class StartActivity extends Activity {

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        Intent service = new Intent(this, DaemonService.class);
        if (Build.VERSION.SDK_INT >= 26) {
            startForegroundService(service);
        } else {
            startService(service);
        }

        Toast.makeText(this, "Emergency Nomad: daemon starting", Toast.LENGTH_SHORT).show();

        finish();
    }
}
