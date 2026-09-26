package fr.g123k.deviceapps.listener;

import android.annotation.SuppressLint;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.net.Uri;
import android.os.Build;

import androidx.annotation.NonNull;

import java.util.HashSet;
import java.util.Set;

import io.flutter.plugin.common.EventChannel;

public class DeviceAppsChangedListener {

    private final DeviceAppsChangedListenerInterface callback;
    private final Set<EventChannel.EventSink> sinks;

    private BroadcastReceiver appsBroadcastReceiver;
    private boolean registered;

    public DeviceAppsChangedListener(DeviceAppsChangedListenerInterface callback) {
        this.callback = callback;
        this.sinks = new HashSet<>(1);
    }

    // Package broadcasts are protected system broadcasts: they are still delivered to a
    // non-exported receiver, and no other app is allowed to send them.
    @SuppressLint("UnspecifiedRegisterReceiverFlag")
    public void register(@NonNull Context context, EventChannel.EventSink events) {
        sinks.add(events);

        if (registered) {
            return;
        }

        if (appsBroadcastReceiver == null) {
            createBroadcastReceiver();
        }

        IntentFilter intentFilter = new IntentFilter();
        intentFilter.addAction(Intent.ACTION_PACKAGE_ADDED);
        intentFilter.addAction(Intent.ACTION_PACKAGE_REPLACED);
        intentFilter.addAction(Intent.ACTION_PACKAGE_CHANGED);
        intentFilter.addAction(Intent.ACTION_PACKAGE_REMOVED);
        intentFilter.addDataScheme("package");

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            context.registerReceiver(appsBroadcastReceiver, intentFilter, Context.RECEIVER_NOT_EXPORTED);
        } else {
            context.registerReceiver(appsBroadcastReceiver, intentFilter);
        }
        registered = true;
    }

    private void createBroadcastReceiver() {
        appsBroadcastReceiver = new BroadcastReceiver() {
            @Override
            public void onReceive(Context context, Intent intent) {
                Uri data = intent.getData();
                String action = intent.getAction();
                if (data == null || action == null) {
                    return;
                }

                String packageName = data.getSchemeSpecificPart();
                boolean replacing = intent.getBooleanExtra(Intent.EXTRA_REPLACING, false);

                switch (action) {
                    case Intent.ACTION_PACKAGE_ADDED:
                        if (!replacing) {
                            onPackageInstalled(packageName);
                        }
                        break;
                    case Intent.ACTION_PACKAGE_REPLACED:
                        onPackageUpdated(packageName);
                        break;
                    case Intent.ACTION_PACKAGE_CHANGED:
                        // Only the whole package being enabled/disabled, not a single component
                        String[] components = intent.getStringArrayExtra(Intent.EXTRA_CHANGED_COMPONENT_NAME_LIST);
                        if (components != null && components.length == 1 && components[0].equalsIgnoreCase(packageName)) {
                            onPackageChanged(packageName);
                        }
                        break;
                    case Intent.ACTION_PACKAGE_REMOVED:
                        if (!replacing) {
                            onPackageUninstalled(packageName);
                        }
                        break;
                }
            }
        };
    }

    void onPackageInstalled(String packageName) {
        for (EventChannel.EventSink sink : sinks) {
            callback.onPackageInstalled(packageName, sink);
        }
    }

    void onPackageUpdated(String packageName) {
        for (EventChannel.EventSink sink : sinks) {
            callback.onPackageUpdated(packageName, sink);
        }
    }

    void onPackageUninstalled(String packageName) {
        for (EventChannel.EventSink sink : sinks) {
            callback.onPackageUninstalled(packageName, sink);
        }
    }

    void onPackageChanged(String packageName) {
        for (EventChannel.EventSink sink : sinks) {
            callback.onPackageChanged(packageName, sink);
        }
    }

    public void unregister(@NonNull Context context) {
        if (appsBroadcastReceiver != null && registered) {
            try {
                context.unregisterReceiver(appsBroadcastReceiver);
            } catch (IllegalArgumentException ignored) {
                // Already unregistered
            }
            registered = false;
        }

        sinks.clear();
    }

}
