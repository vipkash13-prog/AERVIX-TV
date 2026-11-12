import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/app.dart';
import '../providers/apps_service.dart';

class InstalledAppIcon extends StatefulWidget {
  final App app;
  final double size;
  const InstalledAppIcon({super.key, required this.app, this.size = 72});
  @override
  State<InstalledAppIcon> createState() => _InstalledAppIconState();
}

class _InstalledAppIconState extends State<InstalledAppIcon> {
  late Future<Uint8List> _icon;
  AppsService? _service;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final service = context.read<AppsService>();
    if (!identical(_service, service)) {
      _service = service;
      _icon = service.getAppIcon(widget.app.packageName);
    }
  }

  @override
  void didUpdateWidget(covariant InstalledAppIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.app != widget.app)
      _icon = context.read<AppsService>().getAppIcon(widget.app.packageName);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List>(
    future: _icon,
    builder: (_, snapshot) {
      final bytes = snapshot.data;
      if (bytes == null || bytes.isEmpty)
        return const Icon(Icons.apps, size: 52);
      // The platform returns the actual installed package icon, cached by AppsService.
      return SizedBox.square(
        dimension: widget.size,
        child: Image.memory(
          bytes,
          width: widget.size,
          height: widget.size,
          fit: BoxFit.contain,
          cacheWidth: 256,
          excludeFromSemantics: true,
          errorBuilder: (_, error, stack) => const Icon(Icons.apps, size: 52),
        ),
      );
    },
  );
}
