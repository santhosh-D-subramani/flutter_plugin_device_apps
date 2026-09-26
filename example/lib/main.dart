import 'package:device_apps_example/apps_events.dart';
import 'package:device_apps_example/apps_list.dart';
import 'package:device_apps_example/benchmark.dart';
import 'package:flutter/material.dart';

void main() => runApp(
      MaterialApp(
        title: 'Device apps demo',
        theme: ThemeData(colorSchemeSeed: Colors.teal),
        darkTheme: ThemeData(
          colorSchemeSeed: Colors.teal,
          brightness: Brightness.dark,
        ),
        home: const ExampleApp(),
      ),
    );

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Device apps demo')),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: <Widget>[
          _MenuCard(
            icon: Icons.apps,
            title: 'Applications list',
            subtitle: 'Instant list, lazily loaded icons, search, sort, '
                'filters. Tap an app for its details.',
            builder: (BuildContext context) => const AppsListScreen(),
          ),
          _MenuCard(
            icon: Icons.speed,
            title: 'Fetch benchmark',
            subtitle: 'Compare listing without icons, with full size icons, '
                'and with icons at display size.',
            builder: (BuildContext context) => const BenchmarkScreen(),
          ),
          _MenuCard(
            icon: Icons.notifications_active_outlined,
            title: 'Applications events',
            subtitle: 'Live installs, updates, uninstalls, enable/disable.',
            builder: (BuildContext context) => const AppsEventsScreen(),
          ),
        ],
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final WidgetBuilder builder;

  const _MenuCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16.0,
          vertical: 8.0,
        ),
        leading: Icon(icon, size: 32.0),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute<void>(builder: builder),
        ),
      ),
    );
  }
}
