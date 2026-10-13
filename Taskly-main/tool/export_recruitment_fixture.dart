import 'dart:io';

import 'package:taskly_mobile/data/recruitment/recruitment_seed.dart';

void main() {
  final output = File('../frondend/tests/fixtures/partner-recruitment-v1.json');
  output.parent.createSync(recursive: true);
  output.writeAsStringSync(recruitmentDemoSeed(DateTime.utc(2026, 10, 9)));
}
