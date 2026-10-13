import 'dart:convert';
import 'dart:math';

import 'package:file_picker/file_picker.dart';

String supportRequestId() {
  final r = Random.secure();
  final b = List.generate(16, (_) => r.nextInt(256));
  b[6] = (b[6] & 15) | 64;
  b[8] = (b[8] & 63) | 128;
  final s = b.map((v) => v.toRadixString(16).padLeft(2, '0')).join();
  return '${s.substring(0, 8)}-${s.substring(8, 12)}-${s.substring(12, 16)}-${s.substring(16, 20)}-${s.substring(20)}';
}

Future<String?> pickSupportImage() async {
  final result = await FilePicker.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['jpg', 'jpeg', 'png'],
  );
  if (result.isEmpty) return null;
  final bytes = await result.single.readAsBytes();
  if (bytes.length > 2000000)
    throw Exception('Chọn ảnh PNG hoặc JPEG tối đa 2 MB.');
  final png =
      bytes.length > 8 && bytes[0] == 137 && bytes[1] == 80 && bytes[2] == 78;
  final jpeg = bytes.length > 3 && bytes[0] == 255 && bytes[1] == 216;
  if (!png && !jpeg) throw Exception('Ảnh phải là PNG hoặc JPEG.');
  return 'data:image/${png ? 'png' : 'jpeg'};base64,${base64Encode(bytes)}';
}
