import 'package:flutter/material.dart';

import '../domain/models.dart';
import 'service_icon_presets.dart';

class CategorySymbol extends StatelessWidget {
  const CategorySymbol({super.key, required this.category, this.size = 30});
  final ServiceCategory category;
  final double size;
  @override
  Widget build(BuildContext context) {
    final fallback = Image.asset(
      'assets/category-icons/${servicePresetKey(category.iconKey.isEmpty ? category.slug : category.iconKey)}.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
    );
    return SizedBox(
      width: size,
      height: size,
      child: category.iconUrl.isEmpty
          ? fallback
          : Image.network(
              category.iconUrl,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stack) => fallback,
              loadingBuilder: (context, child, progress) =>
                  progress == null ? child : fallback,
            ),
    );
  }
}
