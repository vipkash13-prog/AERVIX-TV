import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/app.dart';
import '../providers/apps_service.dart';

class InstalledAppIcon extends StatefulWidget {
  final App app;
  final double size;
  final bool preferTvBanner;
  const InstalledAppIcon({
    super.key,
    required this.app,
    this.size = 72,
    this.preferTvBanner = false,
  });
  @override
  State<InstalledAppIcon> createState() => _InstalledAppIconState();
}

class _InstalledArtwork {
  final Uint8List bytes;
  final bool banner;
  const _InstalledArtwork(this.bytes, this.banner);
}

class _InstalledAppIconState extends State<InstalledAppIcon> {
  late Future<_InstalledArtwork> _artwork;
  AppsService? _service;
  Future<_InstalledArtwork> _load(AppsService service) async {
    final packageName = widget.app.packageName;
    final preferBanner = widget.preferTvBanner;
    if (preferBanner) {
      try {
        final banner = await service.getAppBanner(packageName);
        if (banner.isNotEmpty) return _InstalledArtwork(banner, true);
      } catch (_) {
        /* Native icon remains available when the TV banner is absent. */
      }
    }
    return _InstalledArtwork(await service.getAppIcon(packageName), false);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final service = context.read<AppsService>();
    if (!identical(_service, service)) {
      _service = service;
      _artwork = _load(service);
    }
  }

  @override
  void didUpdateWidget(covariant InstalledAppIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.app != widget.app ||
        oldWidget.preferTvBanner != widget.preferTvBanner)
      _artwork = _load(context.read<AppsService>());
  }

  Widget _fallback() => const Center(child: Icon(Icons.apps, size: 52));
  @override
  Widget build(BuildContext context) => FutureBuilder<_InstalledArtwork>(
    future: _artwork,
    builder: (_, snapshot) {
      final artwork = snapshot.data;
      final image = artwork == null || artwork.bytes.isEmpty
          ? _fallback()
          : Image.memory(
              artwork.bytes,
              fit: BoxFit.contain,
              cacheWidth: widget.preferTvBanner ? 512 : 256,
              filterQuality: FilterQuality.medium,
              excludeFromSemantics: true,
              errorBuilder: (_, error, stack) => artwork.banner
                  ? InstalledAppIcon(
                      app: widget.app,
                      size: widget.size,
                      preferTvBanner: false,
                    )
                  : _fallback(),
            );
      return widget.preferTvBanner
          ? SizedBox.expand(
              child: Padding(padding: const EdgeInsets.all(2), child: image),
            )
          : SizedBox.square(dimension: widget.size, child: image);
    },
  );
}
