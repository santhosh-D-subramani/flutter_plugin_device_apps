package fr.g123k.deviceapps.utils;

import android.annotation.SuppressLint;
import android.content.Intent;
import android.content.pm.InstallSourceInfo;
import android.content.pm.PackageInfo;
import android.content.pm.PackageManager;
import android.content.pm.ResolveInfo;
import android.content.pm.Signature;
import android.content.pm.SigningInfo;
import android.os.Build;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import java.util.List;

/**
 * Wraps the {@link PackageManager} APIs whose signature changed across Android versions,
 * so that the rest of the plugin never calls a deprecated overload.
 * <p>
 * On Android 13+ (API 33) the {@code int flags} overloads are replaced by
 * {@link PackageManager.PackageInfoFlags} / {@link PackageManager.ResolveInfoFlags}.
 * <p>
 * QueryPermissionsNeeded: since Android 11 results are filtered by package visibility. That is
 * expected: the plugin declares launcher {@code <queries>}, and apps needing every package add
 * QUERY_ALL_PACKAGES themselves (see README).
 */
@SuppressLint("QueryPermissionsNeeded")
public final class PackageManagerCompat {

    private PackageManagerCompat() {
    }

    @NonNull
    public static List<PackageInfo> getInstalledPackages(@NonNull PackageManager pm, long flags) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            return pm.getInstalledPackages(PackageManager.PackageInfoFlags.of(flags));
        }
        return getInstalledPackagesLegacy(pm, (int) flags);
    }

    @NonNull
    public static PackageInfo getPackageInfo(@NonNull PackageManager pm,
                                             @NonNull String packageName,
                                             long flags) throws PackageManager.NameNotFoundException {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            return pm.getPackageInfo(packageName, PackageManager.PackageInfoFlags.of(flags));
        }
        return getPackageInfoLegacy(pm, packageName, (int) flags);
    }

    @NonNull
    public static List<ResolveInfo> queryIntentActivities(@NonNull PackageManager pm,
                                                          @NonNull Intent intent,
                                                          long flags) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            return pm.queryIntentActivities(intent, PackageManager.ResolveInfoFlags.of(flags));
        }
        return queryIntentActivitiesLegacy(pm, intent, (int) flags);
    }

    public static long getVersionCode(@NonNull PackageInfo packageInfo) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            return packageInfo.getLongVersionCode();
        }
        return getVersionCodeLegacy(packageInfo);
    }

    /**
     * Flag to pass to {@link #getPackageInfo} so that {@link #getSigningSignatures} has data.
     */
    public static long signingFlag() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            return PackageManager.GET_SIGNING_CERTIFICATES;
        }
        return getSignaturesFlagLegacy();
    }

    @Nullable
    public static Signature[] getSigningSignatures(@NonNull PackageInfo packageInfo) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            SigningInfo signingInfo = packageInfo.signingInfo;
            if (signingInfo == null) {
                return null;
            }
            return signingInfo.hasMultipleSigners()
                    ? signingInfo.getApkContentsSigners()
                    : signingInfo.getSigningCertificateHistory();
        }
        return getSignaturesLegacy(packageInfo);
    }

    /**
     * @return {installingPackageName, initiatingPackageName}, each may be null
     */
    @NonNull
    public static String[] getInstallSource(@NonNull PackageManager pm, @NonNull String packageName) {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                InstallSourceInfo info = pm.getInstallSourceInfo(packageName);
                return new String[]{info.getInstallingPackageName(), info.getInitiatingPackageName()};
            }
            return new String[]{getInstallerPackageNameLegacy(pm, packageName), null};
        } catch (PackageManager.NameNotFoundException | IllegalArgumentException | SecurityException ignored) {
            return new String[]{null, null};
        }
    }

    // region Pre-API 33 / pre-API 28 / pre-API 30 overloads, only reached on older devices

    @SuppressWarnings("deprecation")
    private static List<PackageInfo> getInstalledPackagesLegacy(PackageManager pm, int flags) {
        return pm.getInstalledPackages(flags);
    }

    @SuppressWarnings("deprecation")
    private static PackageInfo getPackageInfoLegacy(PackageManager pm, String packageName, int flags)
            throws PackageManager.NameNotFoundException {
        return pm.getPackageInfo(packageName, flags);
    }

    @SuppressWarnings("deprecation")
    private static List<ResolveInfo> queryIntentActivitiesLegacy(PackageManager pm, Intent intent, int flags) {
        return pm.queryIntentActivities(intent, flags);
    }

    @SuppressWarnings("deprecation")
    private static long getVersionCodeLegacy(PackageInfo packageInfo) {
        return packageInfo.versionCode;
    }

    @SuppressWarnings("deprecation")
    private static long getSignaturesFlagLegacy() {
        return PackageManager.GET_SIGNATURES;
    }

    @SuppressWarnings("deprecation")
    private static Signature[] getSignaturesLegacy(PackageInfo packageInfo) {
        return packageInfo.signatures;
    }

    @SuppressWarnings("deprecation")
    private static String getInstallerPackageNameLegacy(PackageManager pm, String packageName) {
        return pm.getInstallerPackageName(packageName);
    }

    // endregion
}
