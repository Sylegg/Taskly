import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../domain/models.dart';
import 'service_icon_presets.dart';

/// Stable image bounds keep service cards still while an icon loads or fails.
class ServiceSymbol extends StatelessWidget {
  const ServiceSymbol({
    super.key,
    this.iconKey = '',
    this.iconUrl = '',
    this.size = 24,
    this.iconSize,
    this.color = AppColors.primary,
    this.fallbackIcon,
  });

  ServiceSymbol.forService(
    Service service, {
    super.key,
    this.size = 24,
    this.iconSize,
    this.color = AppColors.primary,
  }) : iconKey = service.displayIconKey,
       iconUrl = service.iconUrl,
       fallbackIcon = null;

  final String iconKey, iconUrl;
  final double size;
  final double? iconSize;
  final Color color;
  final IconData? fallbackIcon;

  @override
  Widget build(BuildContext context) {
    Widget fallback() => Center(
      child: fallbackIcon != null
          ? Icon(fallbackIcon, size: iconSize ?? size, color: color)
          : Image.asset(
              'assets/service-icons/${servicePresetKey(iconKey)}.png',
              width: iconSize ?? size,
              height: iconSize ?? size,
              fit: BoxFit.contain,
            ),
    );

    return SizedBox(
      width: size,
      height: size,
      child: iconUrl.trim().isEmpty
          ? fallback()
          : Image.network(
              iconUrl,
              width: size,
              height: size,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => fallback(),
              frameBuilder: (_, child, frame, synchronouslyLoaded) =>
                  synchronouslyLoaded || frame != null ? child : fallback(),
            ),
    );
  }
}
