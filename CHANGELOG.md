# Changelog

## [3.0.1] - 26th September 2026

* Example: chip filters on the applications list — System and User (combinable, both = every app), Launchable,
  Disabled, and per-category chips with counts. Only enabling "System" refetches, other chips filter instantly

## [3.0.0] - 26th September 2026

* [BREAKING CHANGE] Requires Dart 3 / Flutter 3.10+ (the previous `<3.0.0` SDK constraint no longer resolved)
* [BREAKING CHANGE] New `ApplicationCategory.accessibility` value (Android 31+)
* Android: no more deprecated API calls (`PackageInfoFlags`/`ResolveInfoFlags` on Android 13+, `getLongVersionCode`,
  `InstallSourceInfo`, `SigningInfo`, receiver export flag on Android 13+), `package` attribute removed from the manifest
* Faster `getInstalledApplications`:
  * apps are read on several threads in parallel
  * launchable apps are resolved with 2 queries instead of 2 queries per installed app
  * icons are sent as raw bytes instead of Base64
  * new `iconSize` parameter to render icons at display size
* New `getAppIcon()` to lazily load icons, `getAppDetails()` (installer, permissions, signing certificates, splits,
  components…) and `openAppInStore()`
* New `Application` attributes: `targetSdkVersion`, `minSdkVersion`, `apkSize`, `launchable`, `installTime`,
  `updateTime`
* Launchable apps are visible on Android 11+ without the `QUERY_ALL_PACKAGES` permission (`<queries>` declared by the plugin)
* Fix enabled/disabled events being inverted
* Fix crashes: icons without an intrinsic size, package broadcasts without extras, detaching/reattaching the engine
* `getApp`, icons and details now run off the main thread (previously only the listing did)
* Example rewritten: lazy icons, search, sort, details screen, benchmark screen

## [2.2.0] - 1st April 2022

* Uninstall an application
* Fix issue #81

## [2.1.1] - 23th April 2021

* AndroidX annotations are now required as a dependency 

## [2.1.0] - 12th April 2021

* [BREAKING CHANGE] [Following Google Play change with the `QUERY_ALL_PACKAGES`](https://support.google.com/googleplay/android-developer/answer/10158779), by default this plugin won't request anymore this permission.
If you want to keep the current behavior, you have to add the permission again to the Android Manifest (cf `README`).

## [2.0.2] - 01th April 2021

* Fix bug #69

## [2.0.1] - 23th March 2021

* Fix many regressions introduced in 2.0.0

## [2.0.0] - 06th March 2021

* Null safety support

## [1.3.0] - 06th March 2021

* New feature: listen to app changes (installation, uninstallation, updates…)
* New field on the `Application` class: whether the app is enabled or not

## [1.2.1] - 06th March 2021

* Ability to open the settings screen of an app : `DeviceApps.openAppSettings(packageName)`
* New methods on the `Application` class : `openApp()` and `openAppSettings()`
* Fix for issue #61 (crash on some Android 10 devices)

## [1.2.0] - 09th August 2020

* Support for Android 11. 

Please read the README file.

## [1.1.2] - 09th August 2020

* Fix issue #49

## [1.1.1+1] - 05th August 2020

* Remove pub warning

## [1.1.1] - 05th August 2020

* Fix wrong category (productivity was recognized as a game)

## [1.1.0] - 18th July 2020

* Migration to the Plugin V2 embedding system
* Fix a crash on devices with an API level lower than 26
* Fix a NPE crash when the plugin was called in the background

## [1.0.10] - 25th June 2020

* Fix typo installTimeMilis -> installTimeMillis
* Fix typo updateTimeMilis -> updateTimeMillis
* Support for the app category (PR #37)

## [1.0.9] - 13th December 2019

* Add path to APK file (PR #16)
* Add install and update time fields (PR #18)
* Add a missing break statement when opening the app
* Fix warnings in the code

## [1.0.8] - 29th May 2019

* Fix issue #11 (>= Flutter 1.6)

## [1.0.7] - 3rd April 2019

* The version code is now available in the Dart code

## [1.0.6] - 21th February 2019

* For each application, you have now access to the "data directory" path (thanks to Ryan Gonzalez)

## [1.0.5] - 21th January 2019

* Some tests apps does not have a _version_name_. From now on, the plugin will just ignore them

## [1.0.4] - 27th December 2018

* Ability to filter only launchable apps (thanks to Damodar Lohani)

## [1.0.3] - 17th December 2018

* Some asserts added + a different class is used when an icon is passed

## [1.0.2] - 15th December 2018

* Support for the application icon (thanks to Damodar Lohani)
* Fetching the applications list is now processed in a background thread in the Android code

## [1.0.1] - 30th October 2018

* New attribute to detect whether the app is user or system

## [1.0.0] - 6th June 2018

* Initial release (support for Android only)
