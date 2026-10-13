import 'package:flutter_test/flutter_test.dart';
import 'package:taskly_mobile/shared/vietnam_locations.dart';

void main() {
  test('shows only Admin published recruiting areas with their real IDs', () {
    final areas = VietnamLocations.getAllAreas(backendAreas: [
      {'id': 'real-open', 'city': 'TP. Hồ Chí Minh', 'name': 'Quận 1', 'recruiting': true, 'capacity': 5},
      {'id': 'real-closed', 'city': 'Hà Nội', 'name': 'Ba Đình', 'recruiting': false},
    ]);
    expect(areas, hasLength(1));
    expect(areas.single['id'], 'real-open');
    expect(areas.single['region'], 'Miền Nam');
    expect(areas.single['capacity'], 5);
    expect(VietnamLocations.getAllAreas(), isEmpty);
  });
}
