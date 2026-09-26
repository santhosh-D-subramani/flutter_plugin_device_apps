import 'dart:async';

import 'package:device_apps/device_apps.dart';
import 'package:device_apps_example/app_icon.dart';
import 'package:device_apps_example/format.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppDetailsScreen extends StatefulWidget {
  final Application application;

  const AppDetailsScreen({required this.application, super.key});

  @override
  State<AppDetailsScreen> createState() => _AppDetailsScreenState();
}

class _AppDetailsScreenState extends State<AppDetailsScreen> {
  late final Future<ApplicationDetails?> _details;
  late final StreamSubscription<ApplicationEvent> _events;
  Application? _installer;

  Application get _app => widget.application;

  @override
  void initState() {
    super.initState();
    _details = _app.loadDetails().then((ApplicationDetails? details) async {
      final String? installer = details?.installerPackageName;
      if (installer != null) {
        final Application? installerApp = await DeviceApps.getApp(installer);
        if (mounted) {
          setState(() => _installer = installerApp);
        }
      }
      return details;
    });

    // Close the screen once the app is uninstalled from the dialog
    _events = DeviceApps.listenToAppsChanges()
        .where((ApplicationEvent event) =>
            event.packageName == _app.packageName &&
            event.event == ApplicationEventType.uninstalled)
        .listen((ApplicationEvent event) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${_app.appName} was uninstalled')),
        );
        Navigator.of(context).maybePop();
      }
    });
  }

  @override
  void dispose() {
    _events.cancel();
    super.dispose();
  }

  Future<void> _run(Future<bool> action, String failure) async {
    if (!await action && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(failure)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_app.appName)),
      body: FutureBuilder<ApplicationDetails?>(
        future: _details,
        builder: (BuildContext context,
            AsyncSnapshot<ApplicationDetails?> snapshot) {
          final ApplicationDetails? details = snapshot.data;
          return ListView(
            padding: const EdgeInsets.only(bottom: 32.0),
            children: <Widget>[
              _Header(app: _app, details: details),
              _Actions(
                app: _app,
                onOpen: () => _run(_app.openApp(), 'No launcher activity'),
                onSettings: () => _run(
                    _app.openSettingsScreen(), 'Unable to open settings'),
                onStore: () =>
                    _run(_app.openInStore(), 'No store or browser available'),
                onUninstall: () => _run(_app.uninstallApp(),
                    'Unable to uninstall (REQUEST_DELETE_PACKAGES missing?)'),
              ),
              const _SectionTitle('Application'),
              _Info('Package', _app.packageName, copyable: true),
              _Info('Version',
                  '${_app.versionName ?? '?'} (${_app.versionCode})'),
              _Info('Target / min SDK',
                  '${_app.targetSdkVersion} / ${_app.minSdkVersion ?? '?'}'),
              _Info('Category', _app.category.name),
              _Info('APK size', formatBytes(_app.apkSize)),
              _Info('Installed', formatDate(_app.installTime)),
              _Info('Updated', formatDate(_app.updateTime)),
              _Info('APK path', _app.apkFilePath, copyable: true),
              _Info('Data dir', _app.dataDir ?? '-'),
              if (snapshot.connectionState != ConnectionState.done)
                const Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (details == null)
                const _Info('Details', 'Unavailable')
              else
                ..._buildDetails(details),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _buildDetails(ApplicationDetails details) {
    final List<ApplicationPermission> granted = details.permissions
        .where((ApplicationPermission p) => p.granted)
        .toList();

    return <Widget>[
      const _SectionTitle('Install source'),
      _Info(
        'Installer',
        details.installerPackageName == null
            ? 'Unknown (pre-installed or adb)'
            : '${_installer?.appName ?? details.installerPackageName}',
      ),
      if (details.initiatingPackageName != null &&
          details.initiatingPackageName != details.installerPackageName)
        _Info('Requested by', details.initiatingPackageName!),
      _Info(
          'Play Store', details.installedFromPlayStore ? 'Yes' : 'No'),
      _Info('Sideloaded', details.sideloaded ? 'Yes' : 'No'),
      const _SectionTitle('Build'),
      _Info('Split APKs', details.splitNames.isEmpty
          ? 'None (monolithic APK)'
          : details.splitNames.join(', ')),
      _Info('Debuggable', details.debuggable ? 'Yes' : 'No'),
      _Info('Cleartext traffic',
          _yesNo(details.usesCleartextTraffic)),
      _Info('Suspended', _yesNo(details.suspended)),
      _Info('UID', '${details.uid}'),
      _Info('Process', details.processName ?? '-'),
      _Info(
        'Components',
        '${details.activitiesCount ?? '?'} activities · '
            '${details.servicesCount ?? '?'} services · '
            '${details.receiversCount ?? '?'} receivers · '
            '${details.providersCount ?? '?'} providers',
      ),
      const _SectionTitle('Signing certificates (SHA-256)'),
      if (details.signingCertificatesSha256.isEmpty)
        const _Info('Certificates', 'Unavailable'),
      for (final String sha in details.signingCertificatesSha256)
        _Info('Certificate', sha, copyable: true, monospace: true),
      _SectionTitle('Permissions (${granted.length} granted / '
          '${details.permissions.length} requested)'),
      for (final ApplicationPermission permission in details.permissions)
        ListTile(
          dense: true,
          leading: Icon(
            permission.granted ? Icons.check_circle : Icons.cancel_outlined,
            color: permission.granted
                ? Colors.green
                : Theme.of(context).disabledColor,
          ),
          title: Text(permission.name.replaceFirst('android.permission.', '')),
          subtitle: permission.name.startsWith('android.permission.')
              ? null
              : Text(permission.name),
        ),
    ];
  }

  static String _yesNo(bool? value) =>
      value == null ? 'Unknown' : (value ? 'Yes' : 'No');
}

class _Header extends StatelessWidget {
  final Application app;
  final ApplicationDetails? details;

  const _Header({required this.app, required this.details});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: <Widget>[
          AppIcon(packageName: app.packageName, size: 72.0),
          const SizedBox(width: 16.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(app.appName,
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 6.0),
                Wrap(
                  spacing: 6.0,
                  runSpacing: 6.0,
                  children: <Widget>[
                    if (app.systemApp) const _Badge('System'),
                    if (!app.enabled) const _Badge('Disabled'),
                    if (app.launchable) const _Badge('Launchable'),
                    if (details?.installedFromPlayStore ?? false)
                      const _Badge('Play Store'),
                    if (details?.sideloaded ?? false) const _Badge('Sideloaded'),
                    if (details?.debuggable ?? false) const _Badge('Debug'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Actions extends StatelessWidget {
  final Application app;
  final VoidCallback onOpen;
  final VoidCallback onSettings;
  final VoidCallback onStore;
  final VoidCallback onUninstall;

  const _Actions({
    required this.app,
    required this.onOpen,
    required this.onSettings,
    required this.onStore,
    required this.onUninstall,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Wrap(
        spacing: 8.0,
        runSpacing: 8.0,
        children: <Widget>[
          FilledButton.icon(
            onPressed: app.launchable ? onOpen : null,
            icon: const Icon(Icons.open_in_new),
            label: const Text('Open'),
          ),
          OutlinedButton.icon(
            onPressed: onSettings,
            icon: const Icon(Icons.settings_outlined),
            label: const Text('Settings'),
          ),
          OutlinedButton.icon(
            onPressed: onStore,
            icon: const Icon(Icons.storefront_outlined),
            label: const Text('Store'),
          ),
          OutlinedButton.icon(
            onPressed: app.systemApp ? null : onUninstall,
            icon: const Icon(Icons.delete_outline),
            label: const Text('Uninstall'),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;

  const _Badge(this.label);

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
      decoration: BoxDecoration(
        color: colors.secondaryContainer,
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Text(
        label,
        style: TextStyle(color: colors.onSecondaryContainer, fontSize: 12.0),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 24.0, 16.0, 4.0),
      child: Text(
        title,
        style: Theme.of(context)
            .textTheme
            .titleSmall
            ?.copyWith(color: Theme.of(context).colorScheme.primary),
      ),
    );
  }
}

class _Info extends StatelessWidget {
  final String label;
  final String value;
  final bool copyable;
  final bool monospace;

  const _Info(this.label, this.value,
      {this.copyable = false, this.monospace = false});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      title: Text(label),
      subtitle: SelectableText(
        value,
        style: monospace ? const TextStyle(fontFamily: 'monospace') : null,
      ),
      trailing: copyable
          ? IconButton(
              icon: const Icon(Icons.copy, size: 18.0),
              tooltip: 'Copy',
              onPressed: () {
                Clipboard.setData(ClipboardData(text: value));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('$label copied')),
                );
              },
            )
          : null,
    );
  }
}
