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
  // At least one of both is always selected, both = every app
  bool _systemApps = false;
  bool _userApps = true;
  bool _onlyLaunchable = false;
  bool _onlyDisabled = false;
  final Set<ApplicationCategory> _categories = <ApplicationCategory>{};
  _SortOrder _sortOrder = _SortOrder.name;
  String _query = '';

  List<Application>? _apps;
  bool _appsIncludeSystem = false;
  Duration? _fetchDuration;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  /// Fetched without icons: the list is displayed as soon as the metadata is
  /// available, icons are then loaded row by row by [AppIcon].
  ///
  /// Every filter except "System" is applied in Dart on the fetched list, so
  /// toggling a chip doesn't hit the platform channel again.
  Future<void> _fetch() async {
    final bool includeSystem = _systemApps;
    setState(() => _apps = null);

    final Stopwatch stopwatch = Stopwatch()..start();
    final List<Application> apps = await DeviceApps.getInstalledApplications(
      includeSystemApps: includeSystem,
    );
    stopwatch.stop();

    if (mounted) {
      setState(() {
        _apps = apps;
        _appsIncludeSystem = includeSystem;
        _fetchDuration = stopwatch.elapsed;
      });
    }
  }

  void _setSystemApps(bool selected) {
    if (!selected && !_userApps) {
      return;
    }
    setState(() => _systemApps = selected);
    // System apps are only fetched when needed; deselecting just filters
    if (selected && !_appsIncludeSystem) {
      _fetch();
    }
  }

  void _setUserApps(bool selected) {
    if (!selected && !_systemApps) {
      return;
    }
    setState(() => _userApps = selected);
  }

  /// Apps matching the type chips (system / user / launchable / disabled),
  /// used to compute the category chips counts
  Iterable<Application> get _typeFilteredApps => _apps!.where(
        (Application app) =>
            (app.systemApp ? _systemApps : _userApps) &&
            (!_onlyLaunchable || app.launchable) &&
            (!_onlyDisabled || !app.enabled),
      );

  Map<ApplicationCategory, int> get _categoryCounts {
    final Map<ApplicationCategory, int> counts = <ApplicationCategory, int>{};
    for (final Application app in _typeFilteredApps) {
      counts.update(app.category, (int count) => count + 1, ifAbsent: () => 1);
    }
    return counts;
  }

  List<Application> get _visibleApps {
    final String query = _query.trim().toLowerCase();
    final List<Application> apps = _typeFilteredApps
        .where((Application app) =>
            (_categories.isEmpty || _categories.contains(app.category)) &&
            (query.isEmpty ||
                app.appName.toLowerCase().contains(query) ||
                app.packageName.toLowerCase().contains(query)))
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
          preferredSize: const Size.fromHeight(_Filters.height),
          child: _Filters(
            systemApps: _systemApps,
            userApps: _userApps,
            onlyLaunchable: _onlyLaunchable,
            onlyDisabled: _onlyDisabled,
            categories: _categories,
            categoryCounts: _apps == null ? null : _categoryCounts,
            onQueryChanged: (String query) => setState(() => _query = query),
            onSystemAppsChanged: _setSystemApps,
            onUserAppsChanged: _setUserApps,
            onLaunchableChanged: (bool value) =>
                setState(() => _onlyLaunchable = value),
            onDisabledChanged: (bool value) =>
                setState(() => _onlyDisabled = value),
            onCategoryChanged: (ApplicationCategory category, bool value) =>
                setState(() => value
                    ? _categories.add(category)
                    : _categories.remove(category)),
            onClearCategories: () => setState(_categories.clear),
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

extension on ApplicationCategory {
  String get label {
    switch (this) {
      case ApplicationCategory.undefined:
        return 'Other';
      default:
        return name[0].toUpperCase() + name.substring(1);
    }
  }
}

class _Filters extends StatelessWidget {
  static const double height = 172.0;

  final bool systemApps;
  final bool userApps;
  final bool onlyLaunchable;
  final bool onlyDisabled;
  final Set<ApplicationCategory> categories;

  /// Null while loading
  final Map<ApplicationCategory, int>? categoryCounts;

  final ValueChanged<String> onQueryChanged;
  final ValueChanged<bool> onSystemAppsChanged;
  final ValueChanged<bool> onUserAppsChanged;
  final ValueChanged<bool> onLaunchableChanged;
  final ValueChanged<bool> onDisabledChanged;
  final void Function(ApplicationCategory category, bool selected)
      onCategoryChanged;
  final VoidCallback onClearCategories;

  const _Filters({
    required this.systemApps,
    required this.userApps,
    required this.onlyLaunchable,
    required this.onlyDisabled,
    required this.categories,
    required this.categoryCounts,
    required this.onQueryChanged,
    required this.onSystemAppsChanged,
    required this.onUserAppsChanged,
    required this.onLaunchableChanged,
    required this.onDisabledChanged,
    required this.onCategoryChanged,
    required this.onClearCategories,
  });

  @override
  Widget build(BuildContext context) {
    final Map<ApplicationCategory, int> counts =
        categoryCounts ?? <ApplicationCategory, int>{};
    // Categories without any app are hidden, "Other" is always last
    final List<ApplicationCategory> visibleCategories = ApplicationCategory
        .values
        .where((ApplicationCategory category) =>
            counts.containsKey(category) || categories.contains(category))
        .toList()
      ..sort((ApplicationCategory a, ApplicationCategory b) {
        if (a == ApplicationCategory.undefined) {
          return 1;
        }
        if (b == ApplicationCategory.undefined) {
          return -1;
        }
        return (counts[b] ?? 0).compareTo(counts[a] ?? 0);
      });

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: SearchBar(
              hintText: 'Search by name or package',
              leading: const Icon(Icons.search),
              elevation: const WidgetStatePropertyAll<double>(0.0),
              onChanged: onQueryChanged,
            ),
          ),
          const SizedBox(height: 8.0),
          _ChipsRow(
            children: <Widget>[
              FilterChip(
                avatar: const Icon(Icons.shield_outlined),
                label: const Text('System'),
                selected: systemApps,
                onSelected: onSystemAppsChanged,
              ),
              FilterChip(
                avatar: const Icon(Icons.person_outline),
                label: const Text('User'),
                selected: userApps,
                onSelected: onUserAppsChanged,
              ),
              FilterChip(
                label: const Text('Launchable'),
                selected: onlyLaunchable,
                onSelected: onLaunchableChanged,
              ),
              FilterChip(
                label: const Text('Disabled'),
                selected: onlyDisabled,
                onSelected: onDisabledChanged,
              ),
            ],
          ),
          const SizedBox(height: 4.0),
          _ChipsRow(
            children: <Widget>[
              ChoiceChip(
                label: const Text('All categories'),
                selected: categories.isEmpty,
                onSelected: (bool selected) => onClearCategories(),
              ),
              for (final ApplicationCategory category in visibleCategories)
                FilterChip(
                  label: Text('${category.label} (${counts[category] ?? 0})'),
                  selected: categories.contains(category),
                  onSelected: (bool selected) =>
                      onCategoryChanged(category, selected),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChipsRow extends StatelessWidget {
  final List<Widget> children;

  const _ChipsRow({required this.children});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48.0,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12.0),
        itemCount: children.length,
        separatorBuilder: (BuildContext context, int index) =>
            const SizedBox(width: 8.0),
        itemBuilder: (BuildContext context, int index) => children[index],
      ),
    );
  }
}
