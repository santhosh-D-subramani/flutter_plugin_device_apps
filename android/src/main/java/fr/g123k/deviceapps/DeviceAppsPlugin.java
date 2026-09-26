package fr.g123k.deviceapps;

import android.content.Context;
import android.content.Intent;
import android.content.pm.ApplicationInfo;
import android.content.pm.PackageInfo;
import android.content.pm.PackageManager;
import android.content.pm.ResolveInfo;
import android.content.pm.Signature;
import android.net.Uri;
import android.os.Build;
import android.os.Handler;
import android.os.Looper;
import android.provider.Settings;
import android.text.TextUtils;
import android.util.Log;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import java.io.File;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.ExecutionException;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.RejectedExecutionException;

import fr.g123k.deviceapps.listener.DeviceAppsChangedListener;
import fr.g123k.deviceapps.listener.DeviceAppsChangedListenerInterface;
import fr.g123k.deviceapps.utils.AppDataConstants;
import fr.g123k.deviceapps.utils.AppDataEventConstants;
import fr.g123k.deviceapps.utils.IconUtils;
import fr.g123k.deviceapps.utils.IntentUtils;
import fr.g123k.deviceapps.utils.PackageManagerCompat;
import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.EventChannel;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;

/**
 * DeviceAppsPlugin
 */
public class DeviceAppsPlugin implements
        FlutterPlugin,
        MethodCallHandler,
        EventChannel.StreamHandler,
        DeviceAppsChangedListenerInterface {

    private static final String LOG_TAG = "DEVICE_APPS";
    private static final int SYSTEM_APP_MASK = ApplicationInfo.FLAG_SYSTEM | ApplicationInfo.FLAG_UPDATED_SYSTEM_APP;

    private static final char[] HEX_DIGITS = "0123456789ABCDEF".toCharArray();

    private final Handler mainHandler = new Handler(Looper.getMainLooper());

    /**
     * Runs whole requests (eg: listing every app), which may wait on {@link #workers}.
     */
    private ExecutorService requestExecutor;
    /**
     * Runs leaf tasks only (one app, one icon…) and never waits on itself, so it can't deadlock.
     * Loading labels and icons means opening each APK's resources: doing it on several cores
     * is what makes {@code getInstalledApps} fast.
     */
    private ExecutorService workers;

    private Context context;
    private MethodChannel methodChannel;
    private EventChannel eventChannel;
    private DeviceAppsChangedListener appsListener;

    @Override
    public void onAttachedToEngine(@NonNull FlutterPluginBinding binding) {
        context = binding.getApplicationContext();

        int threads = Math.max(2, Math.min(4, Runtime.getRuntime().availableProcessors()));
        requestExecutor = Executors.newCachedThreadPool();
        workers = Executors.newFixedThreadPool(threads);

        BinaryMessenger messenger = binding.getBinaryMessenger();
        methodChannel = new MethodChannel(messenger, "g123k/device_apps");
        methodChannel.setMethodCallHandler(this);

        eventChannel = new EventChannel(messenger, "g123k/device_apps_events");
        eventChannel.setStreamHandler(this);
    }

    @Override
    public void onMethodCall(@NonNull MethodCall call, @NonNull final Result result) {
        if (context == null) {
            result.error("ERROR", "The plugin is not attached to an engine", null);
            return;
        }

        switch (call.method) {
            case "getInstalledApps": {
                final boolean systemApps = boolArg(call, "system_apps");
                final boolean includeAppIcons = boolArg(call, "include_app_icons");
                final boolean onlyAppsWithLaunchIntent = boolArg(call, "only_apps_with_launch_intent");
                final int iconSize = intArg(call, "icon_size");
                runAsync(requestExecutor, result,
                        () -> getInstalledApps(systemApps, includeAppIcons, onlyAppsWithLaunchIntent, iconSize));
                break;
            }
            case "getApp": {
                final String packageName = packageNameArg(call, result);
                if (packageName != null) {
                    final boolean includeAppIcon = boolArg(call, "include_app_icon");
                    final int iconSize = intArg(call, "icon_size");
                    runAsync(workers, result, () -> getApp(packageName, includeAppIcon, iconSize));
                }
                break;
            }
            case "getAppIcon": {
                final String packageName = packageNameArg(call, result);
                if (packageName != null) {
                    final int iconSize = intArg(call, "icon_size");
                    runAsync(workers, result, () -> getAppIcon(packageName, iconSize));
                }
                break;
            }
            case "getAppDetails": {
                final String packageName = packageNameArg(call, result);
                if (packageName != null) {
                    runAsync(workers, result, () -> getAppDetails(packageName));
                }
                break;
            }
            case "isAppInstalled": {
                final String packageName = packageNameArg(call, result);
                if (packageName != null) {
                    result.success(isAppInstalled(packageName));
                }
                break;
            }
            case "openApp": {
                final String packageName = packageNameArg(call, result);
                if (packageName != null) {
                    result.success(openApp(packageName));
                }
                break;
            }
            case "openAppSettings": {
                final String packageName = packageNameArg(call, result);
                if (packageName != null) {
                    result.success(openPackageIntent(packageName,
                            new Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:" + packageName))));
                }
                break;
            }
            case "uninstallApp": {
                final String packageName = packageNameArg(call, result);
                if (packageName != null) {
                    result.success(openPackageIntent(packageName,
                            new Intent(Intent.ACTION_DELETE, Uri.parse("package:" + packageName))));
                }
                break;
            }
            case "openAppInStore": {
                final String packageName = packageNameArg(call, result);
                if (packageName != null) {
                    result.success(openAppInStore(packageName));
                }
                break;
            }
            default:
                result.notImplemented();
        }
    }

    // region Method channel helpers

    private interface Task {
        Object run() throws Exception;
    }

    private void runAsync(ExecutorService executor, final Result result, final Task task) {
        try {
            executor.execute(() -> {
                try {
                    final Object value = task.run();
                    mainHandler.post(() -> result.success(value));
                } catch (final Exception e) {
                    Log.e(LOG_TAG, "Unable to process the request", e);
                    mainHandler.post(() -> result.error("ERROR", e.getMessage(), null));
                }
            });
        } catch (RejectedExecutionException e) {
            result.error("ERROR", "The plugin is detached", null);
        }
    }

    private static boolean boolArg(MethodCall call, String key) {
        Boolean value = call.argument(key);
        return value != null && value;
    }

    private static int intArg(MethodCall call, String key) {
        Number value = call.argument(key);
        return value != null ? value.intValue() : 0;
    }

    @Nullable
    private static String packageNameArg(MethodCall call, Result result) {
        Object value = call.argument("package_name");
        if (value == null || TextUtils.isEmpty(value.toString())) {
            result.error("ERROR", "Empty or null package name", null);
            return null;
        }
        return value.toString();
    }

    // endregion

    // region Listing

    private List<Map<String, Object>> getInstalledApps(boolean includeSystemApps,
                                                       boolean includeAppIcons,
                                                       boolean onlyAppsWithLaunchIntent,
                                                       final int iconSize) throws InterruptedException {
        final PackageManager packageManager = context.getPackageManager();
        List<PackageInfo> packages = PackageManagerCompat.getInstalledPackages(packageManager, 0);
        final Set<String> launchablePackages = getLaunchablePackages(packageManager);

        List<Future<Map<String, Object>>> futures = new ArrayList<>(packages.size());
        for (final PackageInfo packageInfo : packages) {
            if (packageInfo.applicationInfo == null) {
                continue;
            }
            if (!includeSystemApps && isSystemApp(packageInfo.applicationInfo)) {
                continue;
            }
            final boolean launchable = launchablePackages.contains(packageInfo.packageName);
            if (onlyAppsWithLaunchIntent && !launchable) {
                continue;
            }

            futures.add(workers.submit(() ->
                    getAppData(packageManager, packageInfo, launchable, includeAppIcons, iconSize)));
        }

        List<Map<String, Object>> installedApps = new ArrayList<>(futures.size());
        for (Future<Map<String, Object>> future : futures) {
            try {
                installedApps.add(future.get());
            } catch (ExecutionException e) {
                // One broken package (eg: uninstalled while listing) shouldn't fail the whole list
                Log.w(LOG_TAG, "Unable to read an application", e.getCause());
            }
        }

        return installedApps;
    }

    /**
     * Resolves launchable packages with two queries, rather than calling
     * {@link PackageManager#getLaunchIntentForPackage} (which does the same two queries) once
     * per installed package.
     */
    private static Set<String> getLaunchablePackages(PackageManager packageManager) {
        Set<String> packages = new HashSet<>();
        for (String category : new String[]{Intent.CATEGORY_LAUNCHER, Intent.CATEGORY_INFO}) {
            Intent intent = new Intent(Intent.ACTION_MAIN).addCategory(category);
            for (ResolveInfo info : PackageManagerCompat.queryIntentActivities(packageManager, intent, 0)) {
                if (info.activityInfo != null) {
                    packages.add(info.activityInfo.packageName);
                }
            }
        }
        return packages;
    }

    @Nullable
    private Map<String, Object> getApp(String packageName, boolean includeAppIcon, int iconSize) {
        try {
            PackageManager packageManager = context.getPackageManager();
            PackageInfo packageInfo = PackageManagerCompat.getPackageInfo(packageManager, packageName, 0);
            if (packageInfo.applicationInfo == null) {
                return null;
            }

            boolean launchable = packageManager.getLaunchIntentForPackage(packageName) != null;
            return getAppData(packageManager, packageInfo, launchable, includeAppIcon, iconSize);
        } catch (PackageManager.NameNotFoundException ignored) {
            return null;
        }
    }

    @Nullable
    private byte[] getAppIcon(String packageName, int iconSize) {
        try {
            return IconUtils.toPng(context.getPackageManager().getApplicationIcon(packageName), iconSize);
        } catch (PackageManager.NameNotFoundException ignored) {
            return null;
        }
    }

    private static Map<String, Object> getAppData(PackageManager packageManager,
                                                  PackageInfo packageInfo,
                                                  boolean launchable,
                                                  boolean includeAppIcon,
                                                  int iconSize) {
        ApplicationInfo applicationInfo = packageInfo.applicationInfo;

        Map<String, Object> map = new HashMap<>(20);
        map.put(AppDataConstants.APP_NAME, applicationInfo.loadLabel(packageManager).toString());
        map.put(AppDataConstants.APK_FILE_PATH, applicationInfo.sourceDir);
        map.put(AppDataConstants.PACKAGE_NAME, packageInfo.packageName);
        map.put(AppDataConstants.VERSION_CODE, PackageManagerCompat.getVersionCode(packageInfo));
        map.put(AppDataConstants.VERSION_NAME, packageInfo.versionName);
        map.put(AppDataConstants.DATA_DIR, applicationInfo.dataDir);
        map.put(AppDataConstants.SYSTEM_APP, isSystemApp(applicationInfo));
        map.put(AppDataConstants.INSTALL_TIME, packageInfo.firstInstallTime);
        map.put(AppDataConstants.UPDATE_TIME, packageInfo.lastUpdateTime);
        map.put(AppDataConstants.IS_ENABLED, applicationInfo.enabled);
        map.put(AppDataConstants.TARGET_SDK, applicationInfo.targetSdkVersion);
        map.put(AppDataConstants.APK_SIZE, getApkSize(applicationInfo));
        map.put(AppDataConstants.LAUNCHABLE, launchable);

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            map.put(AppDataConstants.MIN_SDK, applicationInfo.minSdkVersion);
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            map.put(AppDataConstants.CATEGORY, applicationInfo.category);
        }

        if (includeAppIcon) {
            map.put(AppDataConstants.APP_ICON, IconUtils.toPng(applicationInfo.loadIcon(packageManager), iconSize));
        }

        return map;
    }

    /**
     * Base APK + split APKs (App Bundles are installed as several APKs)
     */
    private static long getApkSize(ApplicationInfo applicationInfo) {
        long size = applicationInfo.sourceDir != null ? new File(applicationInfo.sourceDir).length() : 0;
        if (applicationInfo.splitSourceDirs != null) {
            for (String split : applicationInfo.splitSourceDirs) {
                size += new File(split).length();
            }
        }
        return size;
    }

    private static boolean isSystemApp(ApplicationInfo applicationInfo) {
        return (applicationInfo.flags & SYSTEM_APP_MASK) != 0;
    }

    // endregion

    // region Details

    @Nullable
    private Map<String, Object> getAppDetails(String packageName) {
        PackageManager packageManager = context.getPackageManager();
        PackageInfo packageInfo;
        try {
            packageInfo = PackageManagerCompat.getPackageInfo(packageManager, packageName,
                    PackageManager.GET_PERMISSIONS | PackageManagerCompat.signingFlag());
        } catch (PackageManager.NameNotFoundException ignored) {
            return null;
        }

        ApplicationInfo applicationInfo = packageInfo.applicationInfo;
        if (applicationInfo == null) {
            return null;
        }

        boolean launchable = packageManager.getLaunchIntentForPackage(packageName) != null;
        Map<String, Object> map = getAppData(packageManager, packageInfo, launchable, false, 0);

        String[] installSource = PackageManagerCompat.getInstallSource(packageManager, packageName);
        map.put(AppDataConstants.INSTALLER_PACKAGE_NAME, installSource[0]);
        map.put(AppDataConstants.INITIATING_PACKAGE_NAME, installSource[1]);

        List<Map<String, Object>> permissions = new ArrayList<>();
        if (packageInfo.requestedPermissions != null) {
            for (int i = 0; i < packageInfo.requestedPermissions.length; i++) {
                Map<String, Object> permission = new HashMap<>(2);
                permission.put(AppDataConstants.PERMISSION_NAME, packageInfo.requestedPermissions[i]);
                permission.put(AppDataConstants.PERMISSION_GRANTED, packageInfo.requestedPermissionsFlags != null
                        && (packageInfo.requestedPermissionsFlags[i] & PackageInfo.REQUESTED_PERMISSION_GRANTED) != 0);
                permissions.add(permission);
            }
        }
        map.put(AppDataConstants.PERMISSIONS, permissions);

        // Queried one by one: huge apps (eg: Play Services) can exceed the Binder transaction
        // limit when every component type is requested at once
        map.put(AppDataConstants.ACTIVITIES_COUNT, countComponents(packageManager, packageName, PackageManager.GET_ACTIVITIES));
        map.put(AppDataConstants.SERVICES_COUNT, countComponents(packageManager, packageName, PackageManager.GET_SERVICES));
        map.put(AppDataConstants.RECEIVERS_COUNT, countComponents(packageManager, packageName, PackageManager.GET_RECEIVERS));
        map.put(AppDataConstants.PROVIDERS_COUNT, countComponents(packageManager, packageName, PackageManager.GET_PROVIDERS));

        map.put(AppDataConstants.SPLIT_NAMES, Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && applicationInfo.splitNames != null
                ? Arrays.asList(applicationInfo.splitNames)
                : new ArrayList<String>(0));
        map.put(AppDataConstants.UID, applicationInfo.uid);
        map.put(AppDataConstants.DEBUGGABLE, (applicationInfo.flags & ApplicationInfo.FLAG_DEBUGGABLE) != 0);
        map.put(AppDataConstants.PROCESS_NAME, applicationInfo.processName);
        map.put(AppDataConstants.NATIVE_LIBRARY_DIR, applicationInfo.nativeLibraryDir);
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            map.put(AppDataConstants.USES_CLEARTEXT_TRAFFIC, (applicationInfo.flags & ApplicationInfo.FLAG_USES_CLEARTEXT_TRAFFIC) != 0);
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            map.put(AppDataConstants.SUSPENDED, (applicationInfo.flags & ApplicationInfo.FLAG_SUSPENDED) != 0);
        }
        map.put(AppDataConstants.SIGNING_CERTIFICATES_SHA256, getSigningCertificatesSha256(packageInfo));

        return map;
    }

    @Nullable
    private static Integer countComponents(PackageManager packageManager, String packageName, int flag) {
        try {
            PackageInfo info = PackageManagerCompat.getPackageInfo(packageManager, packageName, flag);
            Object[] components;
            switch (flag) {
                case PackageManager.GET_ACTIVITIES:
                    components = info.activities;
                    break;
                case PackageManager.GET_SERVICES:
                    components = info.services;
                    break;
                case PackageManager.GET_RECEIVERS:
                    components = info.receivers;
                    break;
                case PackageManager.GET_PROVIDERS:
                    components = info.providers;
                    break;
                default:
                    return null;
            }
            return components != null ? components.length : 0;
        } catch (PackageManager.NameNotFoundException | RuntimeException e) {
            return null;
        }
    }

    private static List<String> getSigningCertificatesSha256(PackageInfo packageInfo) {
        Signature[] signatures = PackageManagerCompat.getSigningSignatures(packageInfo);
        List<String> fingerprints = new ArrayList<>();
        if (signatures == null) {
            return fingerprints;
        }

        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            for (Signature signature : signatures) {
                byte[] hash = digest.digest(signature.toByteArray());
                StringBuilder builder = new StringBuilder(hash.length * 3);
                for (int i = 0; i < hash.length; i++) {
                    if (i > 0) {
                        builder.append(':');
                    }
                    builder.append(HEX_DIGITS[(hash[i] >> 4) & 0xF]).append(HEX_DIGITS[hash[i] & 0xF]);
                }
                fingerprints.add(builder.toString());
            }
        } catch (NoSuchAlgorithmException ignored) {
            // SHA-256 is always available on Android
        }
        return fingerprints;
    }

    // endregion

    // region Actions

    private boolean openApp(@NonNull String packageName) {
        if (!isAppInstalled(packageName)) {
            Log.w(LOG_TAG, "Application with package name \"" + packageName + "\" is not installed on this device");
            return false;
        }

        return IntentUtils.startActivity(context, context.getPackageManager().getLaunchIntentForPackage(packageName));
    }

    private boolean openPackageIntent(@NonNull String packageName, @NonNull Intent intent) {
        if (!isAppInstalled(packageName)) {
            Log.w(LOG_TAG, "Application with package name \"" + packageName + "\" is not installed on this device");
            return false;
        }

        return IntentUtils.startActivity(context, intent);
    }

    /**
     * Opens the app's page in a store app (Play Store…), or on the Play Store website otherwise.
     * Works whether or not the app is installed.
     */
    private boolean openAppInStore(@NonNull String packageName) {
        return IntentUtils.startActivity(context, new Intent(Intent.ACTION_VIEW, Uri.parse("market://details?id=" + packageName)))
                || IntentUtils.startActivity(context, new Intent(Intent.ACTION_VIEW, Uri.parse("https://play.google.com/store/apps/details?id=" + packageName)));
    }

    private boolean isAppInstalled(@NonNull String packageName) {
        try {
            PackageManagerCompat.getPackageInfo(context.getPackageManager(), packageName, 0);
            return true;
        } catch (PackageManager.NameNotFoundException ignored) {
            return false;
        }
    }

    // endregion

    // region Events

    @Override
    public void onListen(Object arguments, final EventChannel.EventSink events) {
        if (context != null) {
            if (appsListener == null) {
                appsListener = new DeviceAppsChangedListener(this);
            }

            appsListener.register(context, events);
        }
    }

    @Override
    public void onPackageInstalled(String packageName, EventChannel.EventSink events) {
        events.success(getListenerData(packageName, AppDataEventConstants.EVENT_TYPE_INSTALLED));
    }

    @Override
    public void onPackageUpdated(String packageName, EventChannel.EventSink events) {
        events.success(getListenerData(packageName, AppDataEventConstants.EVENT_TYPE_UPDATED));
    }

    @Override
    public void onPackageUninstalled(String packageName, EventChannel.EventSink events) {
        events.success(getListenerData(packageName, AppDataEventConstants.EVENT_TYPE_UNINSTALLED));
    }

    @Override
    public void onPackageChanged(String packageName, EventChannel.EventSink events) {
        Map<String, Object> listenerData = getListenerData(packageName, null);

        if (Boolean.TRUE.equals(listenerData.get(AppDataConstants.IS_ENABLED))) {
            listenerData.put(AppDataEventConstants.EVENT_TYPE, AppDataEventConstants.EVENT_TYPE_ENABLED);
        } else {
            listenerData.put(AppDataEventConstants.EVENT_TYPE, AppDataEventConstants.EVENT_TYPE_DISABLED);
        }

        events.success(listenerData);
    }

    Map<String, Object> getListenerData(String packageName, String event) {
        Map<String, Object> data = context != null ? getApp(packageName, false, 0) : null;

        // The app is not installed
        if (data == null) {
            data = new HashMap<>(2);
            data.put(AppDataEventConstants.PACKAGE_NAME, packageName);
        }

        if (event != null) {
            data.put(AppDataEventConstants.EVENT_TYPE, event);
        }

        return data;
    }

    @Override
    public void onCancel(Object arguments) {
        if (context != null && appsListener != null) {
            appsListener.unregister(context);
        }
    }

    // endregion

    @Override
    public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
        if (requestExecutor != null) {
            requestExecutor.shutdownNow();
            requestExecutor = null;
        }
        if (workers != null) {
            workers.shutdownNow();
            workers = null;
        }

        if (methodChannel != null) {
            methodChannel.setMethodCallHandler(null);
            methodChannel = null;
        }

        if (eventChannel != null) {
            eventChannel.setStreamHandler(null);
            eventChannel = null;
        }

        if (appsListener != null) {
            appsListener.unregister(context);
            appsListener = null;
        }

        context = null;
    }
}
