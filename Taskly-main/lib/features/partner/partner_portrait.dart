import 'dart:convert';
import 'package:flutter/material.dart';
import '../../auth/api.dart';

/// The submitted recruitment portrait is the partner's read-only avatar.
class PartnerPortrait extends StatefulWidget {
  const PartnerPortrait({super.key, required this.session, required this.fallback, this.size = 40});
  final Session session;
  final Widget fallback;
  final double size;

  @override
  State<PartnerPortrait> createState() => _PartnerPortraitState();
}

class _PartnerPortraitState extends State<PartnerPortrait> {
  ImageProvider? portrait;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final rows = await widget.session.request('/partner/final-documents');
      if (rows is! List || rows.isEmpty) return;
      final value = rows.first['portrait'] as String?;
      if (value == null || !value.startsWith('data:image/')) return;
      final image = MemoryImage(base64Decode(value.substring(value.indexOf(',') + 1)));
      if (mounted) setState(() => portrait = image);
    } catch (_) {
      // Profiles without submitted final documents retain their initials.
    }
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    width: widget.size,
    height: widget.size,
    child: portrait == null ? widget.fallback : ClipOval(
      child: Image(image: portrait!, fit: BoxFit.cover,
        errorBuilder: (_, error, stackTrace) => widget.fallback),
    ),
  );
}
