import 'package:device_apps/device_apps.dart';
import 'package:device_apps_example/app_details.dart';
import 'package:device_apps_example/app_icon.dart';
import 'package:device_apps_example/format.dart';
import 'package:flutter/material.dart';

enum _SortOrder { name, recentlyUpdated, recentlyInstalled, size }

extension on _SortOrder {
  String get label {
    switch (this) {
      case _SortOrder.name:
        return 'Name';
      case _SortOrder.recentlyUpdated:
        return 'Recently updated';
      case _SortOrder.recentlyInstalled:
        return 'Recently installed';
      case _SortOrder.size:
        return 'Size';
    }
  }

  int compare(Application a, Application b) {
    switch (this) {
      case _SortOrder.name:
        return a.appName.toLowerCase().compareTo(b.appName.toLowerCase());
      case _SortOrder.recentlyUpdated:
        return b.updateTimeMillis.compareTo(a.updateTimeMillis);
      case _SortOrder.recentlyInstalled:
        return b.installTimeMillis.compareTo(a.installTimeMillis);
      case _SortOrder.size:
        return b.apkSize.compareTo(a.apkSize);
    }
  }
}

class AppsListScreen extends StatefulWidget {
  const AppsListScreen({super.key});

  @override
  State<AppsListScreen> createState() => _AppsListScreenState();
}

class _AppsListScreenState extends State<AppsListScreen> {
  bool _showSystemApps = false;
  bool _onlyLaunchableApps = false;
  _SortOrder _sortOrder = _SortOrder.name;
  String _query = '';

  List<Application>? _apps;
  Duration? _fetchDuration;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  /// Fetched without icons: the list is displayed as soon as the metadata is
  /// available, icons are then loaded row by row by [AppIcon].
  Future<void> _fetch() async {
    setState(() => _apps = null);

    final Stopwatch stopwatch = Stopwatch()..start();
    final List<Application> apps = await DeviceApps.getInstalledApplications(
      includeSystemApps: _showSystemApps,
      onlyAppsWithLaunchIntent: _onlyLaunchableApps,
    );
    stopwatch.stop();

    if (mounted) {
      setState(() {
        _apps = apps;
        _fetchDuration = stopwatch.elapsed;
      });
    }
  }

  List<Application> get _visibleApps {
    final String query = _query.trim().toLowerCase();
    final List<Application> apps = _apps!
        .where((Application app) =>
            query.isEmpty ||
            app.appName.toLowerCase().contains(query) ||
            app.packageName.toLowerCase().contains(query))
        .toList();
    apps.sort(_sortOrder.compare);
    return apps;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Installed applications'),
        actions: <Widget>[
          PopupMenuButton<_SortOrder>(
            icon: const Icon(Icons.sort),
            tooltip: 'Sort',
            initialValue: _sortOrder,
            onSelected: (_SortOrder order) =>
                setState(() => _sortOrder = order),
            itemBuilder: (BuildContext context) => _SortOrder.values
                .map((_SortOrder order) => PopupMenuItem<_SortOrder>(
                      value: order,
                      child: Text(order.label),
                    ))
                .toList(),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(112.0),
          child: _Filters(
            showSystemApps: _showSystemApps,
            onlyLaunchableApps: _onlyLaunchableApps,
            onQueryChanged: (String query) => setState(() => _query = query),
            onSystemAppsChanged: (bool value) {
              _showSystemApps = value;
              _fetch();
            },
            onLaunchableChanged: (bool value) {
              _onlyLaunchableApps = value;
              _fetch();
            },
          ),
        ),
      ),
      body: _apps == null
          ? const Center(child: CircularProgressIndicator())
          : _buildList(context),
    );
  }

  Widget _buildList(BuildContext context) {
    final List<Application> apps = _visibleApps;

    return RefreshIndicator(
      onRefresh: _fetch,
      child: Scrollbar(
        child: ListView.builder(
          itemCount: apps.length + 1,
          itemBuilder: (BuildContext context, int position) {
            if (position == 0) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 4.0),
                child: Text(
                  '${apps.length} of ${_apps!.length} apps · fetched in '
                  '${_fetchDuration!.inMilliseconds} ms (no icons)',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              );
            }

            final Application app = apps[position - 1];
            return ListTile(
              key: ValueKey<String>(app.packageName),
              leading: AppIcon(packageName: app.packageName),
              title: Text(app.appName),
              subtitle: Text(
                '${app.packageName}\n'
                '${app.versionName ?? '?'} · ${formatBytes(app.apkSize)} · '
                'target SDK ${app.targetSdkVersion}',
              ),
              isThreeLine: true,
              trailing: app.systemApp
                  ? const Tooltip(
                      message: 'System app',
                      child: Icon(Icons.shield_outlined, size: 18.0),
                    )
                  : null,
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (BuildContext context) =>
                        AppDetailsScreen(application: app),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _Filters extends StatelessWidget {
  final bool showSystemApps;
  final bool onlyLaunchableApps;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<bool> onSystemAppsChanged;
  final ValueChanged<bool> onLaunchableChanged;

  const _Filters({
    required this.showSystemApps,
    required this.onlyLaunchableApps,
    required this.onQueryChanged,
    required this.onSystemAppsChanged,
    required this.onLaunchableChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12.0, 0.0, 12.0, 8.0),
      child: Column(
        children: <Widget>[
          SearchBar(
            hintText: 'Search by name or package',
            leading: const Icon(Icons.search),
            elevation: const WidgetStatePropertyAll<double>(0.0),
            onChanged: onQueryChanged,
          ),
          const SizedBox(height: 8.0),
          Row(
            children: <Widget>[
              FilterChip(
                label: const Text('System apps'),
                selected: showSystemApps,
                onSelected: onSystemAppsChanged,
              ),
              const SizedBox(width: 8.0),
              FilterChip(
                label: const Text('Launchable only'),
                selected: onlyLaunchableApps,
                onSelected: onLaunchableChanged,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
