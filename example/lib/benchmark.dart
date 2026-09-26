import 'package:device_apps/device_apps.dart';
import 'package:device_apps_example/format.dart';
import 'package:flutter/material.dart';

/// Measures how the fetch options impact [DeviceApps.getInstalledApplications]
class BenchmarkScreen extends StatefulWidget {
  const BenchmarkScreen({super.key});

  @override
  State<BenchmarkScreen> createState() => _BenchmarkScreenState();
}

class _Scenario {
  final String title;
  final String description;
  final Future<List<Application>> Function(int iconSizePx) run;

  const _Scenario(this.title, this.description, this.run);
}

class _Result {
  final Duration duration;
  final int apps;
  final int iconBytes;

  const _Result(this.duration, this.apps, this.iconBytes);
}

class _BenchmarkScreenState extends State<BenchmarkScreen> {
  bool _includeSystemApps = true;
  bool _running = false;
  final Map<int, _Result> _results = <int, _Result>{};

  late final List<_Scenario> _scenarios = <_Scenario>[
    _Scenario(
      'No icons',
      'What the list screen does: metadata only, icons loaded lazily',
      (int size) => DeviceApps.getInstalledApplications(
        includeSystemApps: _includeSystemApps,
      ),
    ),
    _Scenario(
      'Icons at intrinsic size',
      'includeAppIcons: true (previous default behavior)',
      (int size) => DeviceApps.getInstalledApplications(
        includeSystemApps: _includeSystemApps,
        includeAppIcons: true,
      ),
    ),
    _Scenario(
      'Icons at display size',
      'includeAppIcons: true, iconSize: 40dp in pixels',
      (int size) => DeviceApps.getInstalledApplications(
        includeSystemApps: _includeSystemApps,
        includeAppIcons: true,
        iconSize: size,
      ),
    ),
  ];

  Future<void> _runAll() async {
    final int iconSize = (40.0 * MediaQuery.devicePixelRatioOf(context)).round();
    setState(() {
      _running = true;
      _results.clear();
    });

    for (int i = 0; i < _scenarios.length; i++) {
      final Stopwatch stopwatch = Stopwatch()..start();
      final List<Application> apps = await _scenarios[i].run(iconSize);
      stopwatch.stop();

      final int iconBytes = apps.fold(
        0,
        (int sum, Application app) =>
            sum + (app is ApplicationWithIcon ? app.icon.length : 0),
      );
      if (!mounted) {
        return;
      }
      setState(() =>
          _results[i] = _Result(stopwatch.elapsed, apps.length, iconBytes));
    }

    setState(() => _running = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Fetch benchmark')),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: <Widget>[
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Include system apps'),
            subtitle: const Text('More apps = bigger difference'),
            value: _includeSystemApps,
            onChanged: _running
                ? null
                : (bool value) => setState(() => _includeSystemApps = value),
          ),
          const SizedBox(height: 8.0),
          FilledButton.icon(
            onPressed: _running ? null : _runAll,
            icon: _running
                ? const SizedBox.square(
                    dimension: 18.0,
                    child: CircularProgressIndicator(strokeWidth: 2.0),
                  )
                : const Icon(Icons.play_arrow),
            label: Text(_running ? 'Running…' : 'Run benchmark'),
          ),
          const SizedBox(height: 16.0),
          for (int i = 0; i < _scenarios.length; i++)
            Card(
              child: ListTile(
                title: Text(_scenarios[i].title),
                subtitle: Text(_scenarios[i].description),
                trailing: _buildResult(_results[i]),
              ),
            ),
          const SizedBox(height: 16.0),
          Text(
            'Timings include the platform channel transfer and Dart parsing. '
            'The first run warms caches: run it twice for stable numbers.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget? _buildResult(_Result? result) {
    if (result == null) {
      return null;
    }
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        Text(
          '${result.duration.inMilliseconds} ms',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        Text(
          '${result.apps} apps'
          '${result.iconBytes > 0 ? ' · ${formatBytes(result.iconBytes)}' : ''}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
