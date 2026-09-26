import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'model/application_category.dart';
import 'model/application_event.dart';

/// Plugin to list applications installed on an Android device
/// iOS is not supported
class DeviceApps {
  static const MethodChannel _methodChannel =
      MethodChannel('g123k/device_apps');
  static const EventChannel _eventChannel =
      EventChannel('g123k/device_apps_events');

  /// List installed applications on the device
  /// [includeSystemApps] will also include system apps (or pre-installed) like
  /// Phone, Settings...
  /// [includeAppIcons] will also include the icon for each app (be aware that
  /// this feature is memory-heaving, since it will load all icons).
  /// To get the icon you have to cast the object to [ApplicationWithIcon]
  /// [iconSize] is the size in pixels of the icons (their intrinsic size, often
  /// 300px+, if omitted). Pass the size you display them at: it is much faster.
  /// For long lists, prefer to fetch without icons and use [getAppIcon] lazily.
  /// [onlyAppsWithLaunchIntent] will only list applications when an entrypoint.
  /// It is similar to what a launcher will display
  static Future<List<Application>> getInstalledApplications({
    bool includeSystemApps = false,
    bool includeAppIcons = false,
    bool onlyAppsWithLaunchIntent = false,
    int? iconSize,
  }) async {
    try {
      final Object? apps = await _methodChannel
          .invokeMethod<Object>('getInstalledApps', <String, Object?>{
        'system_apps': includeSystemApps,
        'include_app_icons': includeAppIcons,
        'only_apps_with_launch_intent': onlyAppsWithLaunchIntent,
        'icon_size': iconSize,
      });

      if (apps is Iterable) {
        final List<Application> list = <Application>[];
        for (final Object? app in apps) {
          if (app is Map) {
            try {
              list.add(Application._(app));
            } catch (e, trace) {
              if (e is AssertionError) {
                debugPrint('[DeviceApps] Unable to add the following app: $app');
              } else {
                debugPrint('[DeviceApps] $e $trace');
              }
            }
          }
        }
        return list;
      } else {
        return List<Application>.empty();
      }
    } catch (err) {
      debugPrint('[DeviceApps] $err');
      return List<Application>.empty();
    }
  }

  /// Provide all information for a given app by its [packageName]
  /// [includeAppIcon] will also include the icon for the app.
  /// To get it, you have to cast the object to [ApplicationWithIcon].
  /// [iconSize] is the size of the icon in pixels (intrinsic size if omitted)
  static Future<Application?> getApp(
    String packageName, [
    bool includeAppIcon = false,
    int? iconSize,
  ]) async {
    if (packageName.isEmpty) {
      throw Exception('The package name can not be empty');
    }
    try {
      final Object? app = await _methodChannel
          .invokeMethod<Object>('getApp', <String, Object?>{
        'package_name': packageName,
        'include_app_icon': includeAppIcon,
        'icon_size': iconSize,
      });

      if (app != null && app is Map<dynamic, dynamic>) {
        return Application._(app);
      } else {
        return null;
      }
    } catch (err) {
      debugPrint('[DeviceApps] $err');
      return null;
    }
  }

  /// Returns the icon (PNG) of a given [packageName], or null if the app is not
  /// installed. Use with [Image.memory].
  /// [iconSize] is the size of the icon in pixels (intrinsic size if omitted)
  ///
  /// Combined with [getInstalledApplications] without icons, this allows to
  /// display a list immediately and to only load the icons which are visible.
  static Future<Uint8List?> getAppIcon(String packageName, {int? iconSize}) {
    if (packageName.isEmpty) {
      throw Exception('The package name can not be empty');
    }

    return _methodChannel
        .invokeMethod<Uint8List>('getAppIcon', <String, Object?>{
          'package_name': packageName,
          'icon_size': iconSize,
        })
        .catchError((Object err) => null);
  }

  /// Provide advanced information for a given app by its [packageName]:
  /// installer (Play Store, sideloaded…), permissions, signing certificates,
  /// components… Returns null if the app is not installed.
  static Future<ApplicationDetails?> getAppDetails(String packageName) async {
    if (packageName.isEmpty) {
      throw Exception('The package name can not be empty');
    }
    try {
      final Object? details = await _methodChannel.invokeMethod<Object>(
          'getAppDetails', <String, Object>{'package_name': packageName});

      if (details is Map<dynamic, dynamic>) {
        return ApplicationDetails._fromMap(details);
      }
      return null;
    } catch (err) {
      debugPrint('[DeviceApps] $err');
      return null;
    }
  }

  /// Returns whether a given [packageName] is installed on the device
  /// You will then receive in return a boolean
  static Future<bool> isAppInstalled(String packageName) {
    return _invokePackageAction('isAppInstalled', packageName);
  }

  /// Launch an app based on its [packageName]
  /// You will then receive in return if the app was opened
  /// (will be false if the app is not installed, or if no "launcher" intent is
  /// provided by this app)
  static Future<bool> openApp(String packageName) {
    return _invokePackageAction('openApp', packageName);
  }

  /// Launch the Settings screen of the app based on its [packageName]
  /// You will then receive in return if the app was opened
  /// (will be false if the app is not installed)
  static Future<bool> openAppSettings(String packageName) {
    return _invokePackageAction('openAppSettings', packageName);
  }

  /// Uninstall an application by giving its [packageName]
  /// Note: It will only open the Android's screen
  /// Requires the `REQUEST_DELETE_PACKAGES` permission in your manifest
  static Future<bool> uninstallApp(String packageName) {
    return _invokePackageAction('uninstallApp', packageName);
  }

  /// Open the page of the app in the store (Play Store…), or on the Play Store
  /// website if no store is available. The app doesn't need to be installed.
  static Future<bool> openAppInStore(String packageName) {
    return _invokePackageAction('openAppInStore', packageName);
  }

  static Future<bool> _invokePackageAction(String method, String packageName) {
    if (packageName.isEmpty) {
      throw Exception('The package name can not be empty');
    }

    return _methodChannel
        .invokeMethod<bool>(method, <String, String>{
          'package_name': packageName,
        })
        .then((bool? value) => value ?? false)
        .catchError((Object err) => false);
  }

  /// Listen to app changes: installations, uninstallations, updates, enabled or
  /// disabled. As it is a [Stream], don't hesite to filter data if the content
  /// is too verbose for you
  static Stream<ApplicationEvent> listenToAppsChanges() {
    return _eventChannel
        .receiveBroadcastStream()
        .map(((dynamic event) =>
            ApplicationEvent._(event as Map<dynamic, dynamic>)))
        .handleError((Object err) => null);
  }
}

/// The Base class to reprend an application (= a package name)
class _BaseApplication {
  /// Name of the package
  final String packageName;

  _BaseApplication.fromMap(Map<dynamic, dynamic> map)
      : packageName = map['package_name'] as String;
}

/// An application installed on the device
/// Depending on the Android version, some attributes may not be available
class Application extends _BaseApplication {
  /// Displayable name of the application
  final String appName;

  /// Full path to the base APK for this application
  final String apkFilePath;

  /// Public name of the application (eg: 1.0.0)
  /// The version name of this package, as specified by the <manifest> tag's
  /// `versionName` attribute
  final String? versionName;

  /// Unique version id for the application
  final int versionCode;

  /// Full path to the default directory assigned to the package for its
  /// persistent data
  final String? dataDir;

  /// Whether the application is installed in the device's system image
  /// An application downloaded by the user won't be a system app
  final bool systemApp;

  /// The time at which the app was first installed
  final int installTimeMillis;

  /// The time at which the app was last updated
  final int updateTimeMillis;

  /// The category of this application
  /// The information may come from the application itself or the system
  final ApplicationCategory category;

  /// Whether the app is enabled (installed and visible)
  /// or disabled (installed, but not visible)
  final bool enabled;

  /// The Android API level the app targets
  final int targetSdkVersion;

  /// The minimum Android API level required by the app (null on Android < 24)
  final int? minSdkVersion;

  /// Size in bytes of the APK(s): the base APK plus all split APKs
  final int apkSize;

  /// Whether the app has an entrypoint (= visible in a launcher)
  final bool launchable;

  factory Application._(Map<dynamic, dynamic> map) {
    if (map.isEmpty) {
      throw Exception('The map can not be null!');
    }
    if (map.containsKey('app_icon')) {
      return ApplicationWithIcon._fromMap(map);
    } else {
      return Application.fromMap(map);
    }
  }

  Application.fromMap(Map<dynamic, dynamic> map)
      : appName = map['app_name'] as String,
        apkFilePath = map['apk_file_path'] as String,
        versionName = map['version_name'] as String?,
        versionCode = map['version_code'] as int,
        dataDir = map['data_dir'] as String?,
        systemApp = map['system_app'] as bool,
        installTimeMillis = map['install_time'] as int,
        updateTimeMillis = map['update_time'] as int,
        enabled = map['is_enabled'] as bool,
        category = _parseCategory(map['category']),
        targetSdkVersion = map['target_sdk'] as int? ?? 0,
        minSdkVersion = map['min_sdk'] as int?,
        apkSize = map['apk_size'] as int? ?? 0,
        launchable = map['launchable'] as bool? ?? false,
        super.fromMap(map);

  /// Mapping of Android categories
  /// [https://developer.android.com/reference/kotlin/android/content/pm/ApplicationInfo]
  /// [category] is null on Android < 26
  static ApplicationCategory _parseCategory(Object? category) {
    switch (category) {
      case 0:
        return ApplicationCategory.game;
      case 1:
        return ApplicationCategory.audio;
      case 2:
        return ApplicationCategory.video;
      case 3:
        return ApplicationCategory.image;
      case 4:
        return ApplicationCategory.social;
      case 5:
        return ApplicationCategory.news;
      case 6:
        return ApplicationCategory.maps;
      case 7:
        return ApplicationCategory.productivity;
      case 8:
        return ApplicationCategory.accessibility;
      default:
        return ApplicationCategory.undefined;
    }
  }

  /// Time at which the app was first installed
  DateTime get installTime =>
      DateTime.fromMillisecondsSinceEpoch(installTimeMillis);

  /// Time at which the app was last updated
  DateTime get updateTime =>
      DateTime.fromMillisecondsSinceEpoch(updateTimeMillis);

  // Open the app default screen
  // Will return [true] is the app is installed and the screen visible
  // Will return [false] otherwise
  Future<bool> openApp() {
    return DeviceApps.openApp(packageName);
  }

  // Open the app settings screen
  // Will return [true] is the app is installed and the screen visible
  // Will return [false] otherwise
  Future<bool> openSettingsScreen() {
    return DeviceApps.openAppSettings(packageName);
  }

  // Uninstall app
  // Will return [true] is the screen to uninstall the app is visible
  // Will return [false] otherwise
  Future<bool> uninstallApp() {
    return DeviceApps.uninstallApp(packageName);
  }

  // Open the app page in the store
  Future<bool> openInStore() {
    return DeviceApps.openAppInStore(packageName);
  }

  // Load the icon of this app (see [DeviceApps.getAppIcon])
  Future<Uint8List?> loadIcon({int? iconSize}) {
    return DeviceApps.getAppIcon(packageName, iconSize: iconSize);
  }

  // Load advanced information (see [DeviceApps.getAppDetails])
  Future<ApplicationDetails?> loadDetails() {
    return DeviceApps.getAppDetails(packageName);
  }

  @override
  String toString() {
    return 'Application{'
        'appName: $appName, '
        'apkFilePath: $apkFilePath, '
        'packageName: $packageName, '
        'versionName: $versionName, '
        'versionCode: $versionCode, '
        'dataDir: $dataDir, '
        'systemApp: $systemApp, '
        'installTimeMillis: $installTimeMillis, '
        'updateTimeMillis: $updateTimeMillis, '
        'category: $category, '
        'enabled: $enabled, '
        'targetSdkVersion: $targetSdkVersion, '
        'minSdkVersion: $minSdkVersion, '
        'apkSize: $apkSize, '
        'launchable: $launchable'
        '}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Application &&
          runtimeType == other.runtimeType &&
          appName == other.appName &&
          apkFilePath == other.apkFilePath &&
          packageName == other.packageName &&
          versionName == other.versionName &&
          versionCode == other.versionCode &&
          dataDir == other.dataDir &&
          systemApp == other.systemApp &&
          installTimeMillis == other.installTimeMillis &&
          updateTimeMillis == other.updateTimeMillis &&
          category == other.category &&
          enabled == other.enabled &&
          targetSdkVersion == other.targetSdkVersion &&
          minSdkVersion == other.minSdkVersion &&
          apkSize == other.apkSize &&
          launchable == other.launchable;

  @override
  int get hashCode => Object.hash(
        appName,
        apkFilePath,
        packageName,
        versionName,
        versionCode,
        dataDir,
        systemApp,
        installTimeMillis,
        updateTimeMillis,
        category,
        enabled,
        targetSdkVersion,
        minSdkVersion,
        apkSize,
        launchable,
      );
}

/// If the [includeAppIcons] attribute is provided, this class will be used.
/// To display an image simply use the [Image.memory] widget.
/// Example:
///
/// ```
/// Image.memory(app.icon)
/// ```
class ApplicationWithIcon extends Application {
  /// Icon of the application (PNG) to use in conjunction with [Image.memory]
  final Uint8List icon;

  ApplicationWithIcon._fromMap(Map<dynamic, dynamic> map)
      : icon = _parseIcon(map['app_icon']),
        super.fromMap(map);

  /// Icons are sent as raw bytes (older versions of the plugin used Base64)
  static Uint8List _parseIcon(Object? icon) {
    if (icon is Uint8List) {
      return icon;
    } else if (icon is String) {
      return base64.decode(icon);
    }
    throw Exception('Invalid icon $icon');
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      super == other &&
          other is ApplicationWithIcon &&
          listEquals(icon, other.icon);

  @override
  int get hashCode => Object.hash(super.hashCode, icon.length);
}

/// A permission requested by an application
class ApplicationPermission {
  /// eg: android.permission.CAMERA
  final String name;

  /// Whether the permission is currently granted
  final bool granted;

  const ApplicationPermission({required this.name, required this.granted});

  @override
  String toString() => 'ApplicationPermission{name: $name, granted: $granted}';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ApplicationPermission &&
          name == other.name &&
          granted == other.granted;

  @override
  int get hashCode => Object.hash(name, granted);
}

/// Advanced information about an application, see [DeviceApps.getAppDetails]
class ApplicationDetails {
  final Application application;

  /// Package name of the app which installed this one (eg: com.android.vending
  /// for the Play Store). Null for pre-installed or adb-installed apps.
  final String? installerPackageName;

  /// Package name of the app which requested the installation (Android 30+).
  /// It may differ from [installerPackageName], eg: a browser which downloaded
  /// an APK installed by the system package installer.
  final String? initiatingPackageName;

  /// Permissions declared in the manifest, and whether they are granted
  final List<ApplicationPermission> permissions;

  /// Number of components declared in the manifest (null if unavailable)
  final int? activitiesCount;
  final int? servicesCount;
  final int? receiversCount;
  final int? providersCount;

  /// Names of the split APKs (App Bundles), empty for a monolithic APK
  final List<String> splitNames;

  /// Linux user id of the app
  final int uid;

  /// Whether the app is a debug build
  final bool debuggable;

  /// Whether the app is suspended (eg: by Digital Wellbeing) (Android 24+)
  final bool? suspended;

  /// Whether the app allows cleartext (HTTP) network traffic (Android 23+)
  final bool? usesCleartextTraffic;

  final String? processName;
  final String? nativeLibraryDir;

  /// SHA-256 fingerprints (AA:BB:… format, same as `keytool`) of the signing
  /// certificates. Useful to check that an app is the genuine one.
  final List<String> signingCertificatesSha256;

  ApplicationDetails._fromMap(Map<dynamic, dynamic> map)
      : application = Application._(map),
        installerPackageName = map['installer_package_name'] as String?,
        initiatingPackageName = map['initiating_package_name'] as String?,
        permissions = (map['permissions'] as List<dynamic>? ?? <dynamic>[])
            .cast<Map<dynamic, dynamic>>()
            .map((Map<dynamic, dynamic> permission) => ApplicationPermission(
                  name: permission['name'] as String,
                  granted: permission['granted'] as bool,
                ))
            .toList(growable: false),
        activitiesCount = map['activities_count'] as int?,
        servicesCount = map['services_count'] as int?,
        receiversCount = map['receivers_count'] as int?,
        providersCount = map['providers_count'] as int?,
        splitNames = (map['split_names'] as List<dynamic>? ?? <dynamic>[])
            .cast<String>(),
        uid = map['uid'] as int,
        debuggable = map['debuggable'] as bool,
        suspended = map['suspended'] as bool?,
        usesCleartextTraffic = map['uses_cleartext_traffic'] as bool?,
        processName = map['process_name'] as String?,
        nativeLibraryDir = map['native_library_dir'] as String?,
        signingCertificatesSha256 =
            (map['signing_certificates_sha256'] as List<dynamic>? ??
                    <dynamic>[])
                .cast<String>();

  String get packageName => application.packageName;

  /// Whether the app was installed from the Google Play Store
  bool get installedFromPlayStore =>
      installerPackageName == 'com.android.vending';

  /// Whether the app was installed by something else than a known store
  /// (eg: an APK file or adb). Pre-installed apps are not considered sideloaded.
  bool get sideloaded =>
      !application.systemApp &&
      !_knownStores.contains(installerPackageName);

  static const Set<String?> _knownStores = <String?>{
    'com.android.vending',
    'com.amazon.venezia',
    'com.sec.android.app.samsungapps',
    'com.huawei.appmarket',
    'com.xiaomi.market',
    'com.xiaomi.mipicks',
    'com.oppo.market',
    'com.heytap.market',
    'com.bbk.appstore',
    'org.fdroid.fdroid',
    'com.aurora.store',
  };

  @override
  String toString() {
    return 'ApplicationDetails{'
        'packageName: $packageName, '
        'installerPackageName: $installerPackageName, '
        'permissions: ${permissions.length}, '
        'splitNames: $splitNames, '
        'signingCertificatesSha256: $signingCertificatesSha256'
        '}';
  }
}

/// Represent an event relative to an application, which can be:
/// - installation
/// - update (from V1 to V2)
/// - uninstallation
/// - (re)enabled by the user
/// - disabled by the user (not visible, but still installed)
///
/// Note: an [Application] is not available directly in this object, as it would
/// be null in the case of an uninstallation
abstract class ApplicationEvent {
  final DateTime time;

  factory ApplicationEvent._(Map<dynamic, dynamic> map) {
    Object? eventType = map['event_type'];

    if (eventType is! String) {
      throw Exception('Event type "$eventType" can not be empty!');
    }

    switch (eventType) {
      case 'installed':
        return ApplicationEventInstalled._fromMap(map);
      case 'updated':
        return ApplicationEventUpdated._fromMap(map);
      case 'uninstalled':
        return ApplicationEventUninstalled._fromMap(map);
      case 'enabled':
        return ApplicationEventEnabled._fromMap(map);
      case 'disabled':
        return ApplicationEventDisabled._fromMap(map);
    }

    throw Exception('Unknown event type $eventType!');
  }

  // ignore: empty_constructor_bodies, avoid_unused_constructor_parameters
  ApplicationEvent._fromMap(Map<dynamic, dynamic> map) : time = DateTime.now();

  /// The package name of the application related to this event
  String get packageName;

  /// The event type will help check if the app is installed or not
  ApplicationEventType get event;

  @override
  String toString() {
    return 'event: $event, time: $time';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ApplicationEvent &&
          runtimeType == other.runtimeType &&
          event == other.event;

  @override
  int get hashCode => event.hashCode;
}

class ApplicationEventInstalled extends ApplicationEvent {
  final Application application;

  ApplicationEventInstalled._fromMap(Map<dynamic, dynamic> map)
      : application = Application._(map),
        super._fromMap(map);

  @override
  ApplicationEventType get event => ApplicationEventType.installed;

  @override
  String get packageName => application.packageName;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      super == other &&
          other is ApplicationEventInstalled &&
          runtimeType == other.runtimeType &&
          application == other.application;

  @override
  int get hashCode => super.hashCode ^ application.hashCode;

  @override
  String toString() {
    return 'ApplicationEventInstalled{application: $application, ${super.toString()}';
  }
}

class ApplicationEventUpdated extends ApplicationEvent {
  final Application application;

  ApplicationEventUpdated._fromMap(Map<dynamic, dynamic> map)
      : application = Application._(map),
        super._fromMap(map);

  @override
  ApplicationEventType get event => ApplicationEventType.updated;

  @override
  String get packageName => application.packageName;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      super == other &&
          other is ApplicationEventUpdated &&
          runtimeType == other.runtimeType &&
          application == other.application;

  @override
  int get hashCode => super.hashCode ^ application.hashCode;

  @override
  String toString() {
    return 'ApplicationEventUpdated{application: $application, ${super.toString()}';
  }
}

class ApplicationEventUninstalled extends ApplicationEvent {
  final _BaseApplication _application;

  ApplicationEventUninstalled._fromMap(Map<dynamic, dynamic> map)
      : _application = _BaseApplication.fromMap(map),
        super._fromMap(map);

  @override
  String get packageName => _application.packageName;

  @override
  ApplicationEventType get event => ApplicationEventType.uninstalled;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      super == other &&
          other is ApplicationEventUninstalled &&
          runtimeType == other.runtimeType &&
          packageName == other.packageName;

  @override
  int get hashCode => Object.hash(super.hashCode, packageName);

  @override
  String toString() {
    return 'ApplicationEventUninstalled{packageName: $packageName, ${super.toString()}';
  }
}

class ApplicationEventEnabled extends ApplicationEvent {
  final Application application;

  ApplicationEventEnabled._fromMap(Map<dynamic, dynamic> map)
      : application = Application._(map),
        super._fromMap(map);

  @override
  ApplicationEventType get event => ApplicationEventType.enabled;

  @override
  String get packageName => application.packageName;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      super == other &&
          other is ApplicationEventEnabled &&
          runtimeType == other.runtimeType &&
          application == other.application;

  @override
  int get hashCode => super.hashCode ^ application.hashCode;

  @override
  String toString() {
    return 'ApplicationEventEnabled{application: $application, ${super.toString()}';
  }
}

class ApplicationEventDisabled extends ApplicationEvent {
  final Application application;

  ApplicationEventDisabled._fromMap(Map<dynamic, dynamic> map)
      : application = Application._(map),
        super._fromMap(map);

  @override
  ApplicationEventType get event => ApplicationEventType.disabled;

  @override
  String get packageName => application.packageName;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      super == other &&
          other is ApplicationEventDisabled &&
          runtimeType == other.runtimeType &&
          application == other.application;

  @override
  int get hashCode => super.hashCode ^ application.hashCode;

  @override
  String toString() {
    return 'ApplicationEventDisabled{application: $application, ${super.toString()}';
  }
}
