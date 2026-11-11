import 'package:flutter/material.dart';

/// Raster artwork stays independent from labels, data and platform actions.
class DesignAssetIcon extends StatelessWidget {
  final String asset;
  final double size;
  const DesignAssetIcon(this.asset, {super.key, this.size = 32});

  @override
  Widget build(BuildContext context) => Image.asset(
    asset,
    width: size,
    height: size,
    fit: BoxFit.contain,
    filterQuality: FilterQuality.medium,
    excludeFromSemantics: true,
  );
}

String weatherAssetPath(int? code, {required bool night}) {
  const base = 'assets/weather/weather_';
  if (code == null) return '${base}cloudy.png';
  if (code >= 95) return '${base}thunder.png';
  if ((code >= 71 && code <= 77) || code == 85 || code == 86)
    return '${base}snow.png';
  if ((code >= 51 && code <= 67) || (code >= 80 && code <= 82))
    return '${base}rain.png';
  if (night) return code == 0 ? '${base}night.png' : '${base}night_cloudy.png';
  if (code == 0) return '${base}sunny.png';
  return code <= 2 ? '${base}partly_cloudy.png' : '${base}cloudy.png';
}
