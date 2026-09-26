# Device Apps plugin for Flutter (UNMAINTAINED)

[![Pub](https://img.shields.io/pub/v/device_apps.svg)](https://pub.dartlang.org/packages/device_apps)

A plugin to list installed applications on an Android device (⚠️ iOS is not supported). You can also listen to app changes (eg: installations, updates…)

## BREAKING CHANGE - 05th May 2021

[May 5 2021](https://support.google.com/googleplay/android-developer/answer/10158779) will mark a breaking change on how applications requesting [`QUERY_ALL_PACKAGES`](https://developer.android.com/reference/kotlin/android/Manifest.permission#query_all_packages) are accepted in the Google Play (and only this app store !). [Quoting from the doc](https://support.google.com/googleplay/android-developer/answer/10158779):


> Permitted use involves apps that must discover any and all installed apps on the device, for awareness or interoperability purposes may have eligibility for the permission. Permitted use includes; device search, antivirus apps, file managers, and browsers.
> 
> Apps granted access to this permission must comply with the User Data policies, including the Prominent Disclosure and Consent requirements, and may not extend its use to undisclosed or invalid purposes.


More info here: https://support.google.com/googleplay/android-developer/answer/10158779

**Starting with version 2.1.0 of this plugin, the [`QUERY_ALL_PACKAGES`](https://developer.android.com/reference/kotlin/android/Manifest.permission#query_all_packages) permission won't be requested by default!**

## Change with Android 11

Starting with Android 11, Android applications targeting API level 30, willing to list "external" applications have to declare a new "normal" permission in their `AndroidManifest.xml` file called [`QUERY_ALL_PACKAGES`](https://developer.android.com/reference/kotlin/android/Manifest.permission#query_all_packages). A few notes about this:

- A normal permission doesn't require the user consent
- Before version 2.1 of this plugin, the permission was requested automatically. This is not the case anymore

**Since version 3.0.0, the plugin declares a `<queries>` entry for launcher activities**: every app visible in a launcher
(= `onlyAppsWithLaunchIntent: true`) is listed without any permission. `QUERY_ALL_PACKAGES` is only needed to also see
packages without a launcher icon (background services, most system components…).

If you need it, simply add the following to your AndroidManifest.xml:

```xml
<manifest...>

    <uses-permission android:name="android.permission.QUERY_ALL_PACKAGES" />

</manifest>
```



However, publishing applications on the Google Play with this kind of feature **may change** in the future. [Quoting from the documentation](https://developer.android.com/reference/kotlin/android/Manifest.permission#query_all_packages):

> In an upcoming policy update, look for Google Play to provide guidelines for apps that need the QUERY_ALL_PACKAGES permission.

**👍 Right now, there is no limitation, but be aware that this may change in the future.**

## Getting Started

First, you have to import the package in your dart file with:

```dart
import 'package:device_apps/device_apps.dart';
```

## List of installed applications

To list applications installed on the device:

```dart
List<Application> apps = await DeviceApps.getInstalledApplications();
```

You can filter system apps if necessary.

**Note**: The list of apps is not ordered! You have to do it yourself.

### Get apps with a launch Intent

A launch Intent means you can launch the application.

To list only the apps with launch intents, simply use the `onlyAppsWithLaunchIntent: true` attribute.

```dart
// Returns a list of only those apps that have launch intent
List<Application> apps = await DeviceApps.getInstalledApplications(onlyAppsWithLaunchIntent: true, includeSystemApps: true)
```

## Get an application

To get a specific application info, please provide its package name:

```dart
Application app = await DeviceApps.getApp('com.frandroid.app');
```

## Check if an application is installed

To check if an app is installed (via its package name):

```dart
bool isInstalled = await DeviceApps.isAppInstalled('com.frandroid.app');
```

## Open an application

To open an application (with a launch Intent)

```dart
DeviceApps.openApp('com.frandroid.app');
```

## Open an application settings screen

To open an application settings screen

```dart
DeviceApps.openAppSettings('com.frandroid.app');
```

## Uninstall an application

To open the screen to uninstall an application:

1. Add this permission to the `AndroidManifest.xml` file:

```xml
<manifest...>

    <uses-permission android:name="android.permission.REQUEST_DELETE_PACKAGES" />

</manifest>
```

2. Call this method:

```dart
DeviceApps.uninstallApp('com.frandroid.app');
```



## Include application icon

When calling `getInstalledApplications()` or `getApp()` methods, you can also ask for the icon.
To display the image, just call:

```dart
Image.memory(app.icon);
```

Icons are rendered at their intrinsic size by default (often 300px+). Pass the size you display them at, in pixels,
to make the call much faster and lighter:

```dart
final int iconSize = (40 * MediaQuery.devicePixelRatioOf(context)).round();
List<Application> apps = await DeviceApps.getInstalledApplications(includeAppIcons: true, iconSize: iconSize);
```

### Lazy icons (recommended for lists)

The fastest way to display a list is to fetch it **without** icons, and to load each icon when its row is built:

```dart
List<Application> apps = await DeviceApps.getInstalledApplications();

// In your list item
FutureBuilder<Uint8List?>(
  future: DeviceApps.getAppIcon(app.packageName, iconSize: iconSize), // or app.loadIcon()
  builder: (context, snapshot) => snapshot.hasData ? Image.memory(snapshot.data!) : const SizedBox(),
);
```

See `example/lib/app_icon.dart` for a version with a cache, and the "Fetch benchmark" screen of the example to compare
the three strategies on your device.

## Application attributes

Besides the name, package name, version, paths and install/update times, each `Application` exposes:

- `targetSdkVersion` / `minSdkVersion` (Android 24+)
- `apkSize`: size in bytes of the base APK + split APKs
- `launchable`: whether the app has a launcher entrypoint
- `category` (Android 26+)

## Application details

`getAppDetails()` returns advanced information, fetched on demand (it is slower than a listing):

```dart
ApplicationDetails? details = await DeviceApps.getAppDetails('com.frandroid.app');

details.installerPackageName;      // eg: com.android.vending
details.installedFromPlayStore;    // true / false
details.sideloaded;                // installed from an APK file or adb
details.permissions;               // requested permissions, and whether they are granted
details.signingCertificatesSha256; // AA:BB:… fingerprints, eg: to check the app is genuine
details.splitNames;                // App Bundle split APKs
details.activitiesCount;           // also services, receivers & providers
details.debuggable;
```

## Open an application in the store

Opens the app page in a store app (eg: Play Store), or the Play Store website otherwise. The app doesn't need to be
installed:

```dart
DeviceApps.openAppInStore('com.frandroid.app');
```

## Listen to app changes

To listen to applications events on the device (installation, uninstallation, update, enabled or disabled):

```dart
Stream<ApplicationEvent> apps = await DeviceApps.listenToAppsChanges();
```

If you only need events for a single app, just use the `Stream` API, like so:

```dart
DeviceApps.listenToAppsChanges().where((ApplicationEvent event) => event.packageName == 'com.frandroid.app')
```
