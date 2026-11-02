import 'package:flutter/material.dart';

Future<void> showServiceUnavailable(BuildContext context) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (dialogContext) => AlertDialog(
    title: const Text('Dịch vụ không còn nữa'),
    content: const Text('Vui lòng tìm dịch vụ khác.'),
    actions: [
      FilledButton(
        onPressed: () => Navigator.of(dialogContext).pop(),
        child: const Text('Tìm dịch vụ khác'),
      ),
    ],
  ),
);
