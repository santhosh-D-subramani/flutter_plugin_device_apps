import 'dart:typed_data';

import 'package:device_apps_ng/device_apps_ng.dart';
import 'package:flutter/material.dart';

/// Loads the icon of an app only when the widget is built (= visible in a
/// list), at the size it is displayed at.
class AppIcon extends StatefulWidget {
  final String packageName;
  final double size;

  const AppIcon({required this.packageName, this.size = 40.0, super.key});

  /// Icons already requested, so scrolling back doesn't reload them.
  /// A real app would bound this cache (eg: LRU).
  static final Map<String, Future<Uint8List?>> _cache =
      <String, Future<Uint8List?>>{};

  static Future<Uint8List?> load(String packageName, int sizePx) {
    return _cache.putIfAbsent(
      '$packageName@$sizePx',
      () => DeviceApps.getAppIcon(packageName, iconSize: sizePx),
    );
  }

  @override
  State<AppIcon> createState() => _AppIconState();
}

class _AppIconState extends State<AppIcon> {
  Future<Uint8List?>? _icon;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolve();
  }

  @override
  void didUpdateWidget(AppIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.packageName != widget.packageName ||
        oldWidget.size != widget.size) {
      _resolve();
    }
  }

  void _resolve() {
    final double ratio = MediaQuery.devicePixelRatioOf(context);
    _icon = AppIcon.load(widget.packageName, (widget.size * ratio).round());
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: widget.size,
      child: FutureBuilder<Uint8List?>(
        future: _icon,
        builder: (BuildContext context, AsyncSnapshot<Uint8List?> snapshot) {
          final Uint8List? bytes = snapshot.data;
          if (bytes == null) {
            return Icon(
              snapshot.connectionState == ConnectionState.done
                  ? Icons.android
                  : Icons.hourglass_empty,
              size: widget.size * 0.6,
              color: Theme.of(context).disabledColor,
            );
          }
          return Image.memory(bytes, gaplessPlayback: true);
        },
      ),
    );
  }
}
