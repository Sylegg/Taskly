import 'dart:async';

import 'package:flutter/material.dart';

import '../../auth/api.dart';
import '../../shared/vietnam_locations.dart';

class PartnerWorkAreas extends StatefulWidget {
  const PartnerWorkAreas({super.key, required this.session});
  final Session session;
  @override
  State<PartnerWorkAreas> createState() => _PartnerWorkAreasState();
}

class _PartnerWorkAreasState extends State<PartnerWorkAreas> {
  List<Map<String, dynamic>> areas = [];
  Set<String> selected = {};
  Set<String> savedAreaIds = {};
  int version = 0;
  bool loading = true, saving = false;
  String query = '';
  String? region;
  String? error;

  StreamSubscription<void>? _liveSubscription;
  @override
  void dispose() {
    _liveSubscription?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _liveSubscription = widget.session.liveChanges.listen((_) {
      if (mounted) load(background: true);
    });
    load();
  }

  bool _fetching = false;
  Future<void> load({bool background = false}) async {
    if (_fetching || saving) return;
    _fetching = true;
    final previousCities = areas
        .where((a) => savedAreaIds.contains(a['id'].toString()))
        .map((a) => a['city'].toString())
        .toSet();
    final dirty =
        selected.length != previousCities.length ||
        !selected.containsAll(previousCities);
    if (!background) {
      setState(() {
        loading = true;
        error = null;
      });
    }
    try {
      final result = await widget.session.request('/partner/work-areas');
      if (!mounted) return;
      setState(() {
        areas = (result['areas'] as List)
            .map((a) => Map<String, dynamic>.from(a))
            .toList();
        savedAreaIds = Set<String>.from(result['areaIds']);
        if (!background || !dirty) {
          selected = areas
              .where((area) => savedAreaIds.contains(area['id'].toString()))
              .map((area) => area['city'].toString())
              .toSet();
        }
        version = (result['version'] as num).toInt();
      });
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      _fetching = false;
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> save() async {
    if (selected.isEmpty || saving) return;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await widget.session.request(
        '/partner/work-areas',
        method: 'PUT',
        // Job matching uses the city of each linked area. Keep one existing
        // area link per city, so district counts do not limit city selection.
        body: {
          'version': version,
          'areaIds': selected.map((city) {
            final matches = areas
                .where((area) => area['city'] == city)
                .toList();
            return (matches
                    .where(
                      (area) => savedAreaIds.contains(area['id'].toString()),
                    )
                    .firstOrNull ??
                matches.first)['id'];
          }).toList(),
        },
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đã lưu khu vực làm việc.')));
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cities = areas.map((area) => area['city'].toString()).toSet().toList()
      ..sort();
    final filtered = cities
        .where(
          (city) =>
              VietnamLocations.provinces.any(
                (p) => p.name == city && p.region == region,
              ) &&
              city.toLowerCase().contains(query.toLowerCase()),
        )
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Khu vực làm việc'),
        actions: [
          IconButton(
            onPressed: saving || loading ? null : load,
            tooltip: 'Tải lại khu vực',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Chọn miền trước, sau đó chọn tỉnh/thành phố bạn có thể đến làm việc.',
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: region,
                        decoration: const InputDecoration(
                          labelText: 'Vùng / Miền',
                        ),
                        items: const ['Miền Bắc', 'Miền Trung', 'Miền Nam']
                            .map(
                              (name) => DropdownMenuItem(
                                value: name,
                                child: Text(name),
                              ),
                            )
                            .toList(),
                        onChanged: saving
                            ? null
                            : (value) => setState(() {
                                region = value;
                                query = '';
                              }),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        key: ValueKey(region),
                        enabled: region != null && !saving,
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search),
                          hintText: 'Tìm tỉnh/thành phố',
                        ),
                        onChanged: (value) => setState(() => query = value),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Đã chọn ${selected.length}/10 tỉnh/thành phố',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      if (selected.any(
                        (city) => !areas.any(
                          (a) => a['city'] == city && a['recruiting'] == true,
                        ),
                      ))
                        const Text(
                          'Khu vực đã đóng. Bỏ chọn khu vực bảo trì và chọn khu vực đang mở để tiếp tục nhận việc.',
                          style: TextStyle(color: Colors.red),
                        ),
                      if (selected.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(selected.join(', ')),
                        ),
                      if (error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Text(
                            error!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: filtered.isEmpty
                      ? Center(
                          child: Text(
                            region == null
                                ? 'Vui lòng chọn miền để xem tỉnh/thành phố.'
                                : 'Chưa có tỉnh/thành phố phù hợp.',
                          ),
                        )
                      : ListView.builder(
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final id = filtered[index];
                            final checked = selected.contains(id);
                            final open = areas.any(
                              (a) => a['city'] == id && a['recruiting'] == true,
                            );
                            return CheckboxListTile(
                              value: checked,
                              title: Text(id),
                              subtitle: open
                                  ? null
                                  : const Text(
                                      'Khu vực đang bảo trì — vui lòng đổi khu vực',
                                      style: TextStyle(color: Colors.red),
                                    ),
                              onChanged: saving || (!open && !checked)
                                  ? null
                                  : (value) {
                                      if (value == true &&
                                          selected.length >= 10) {
                                        setState(
                                          () => error = 'Chỉ chọn tối đa 10 tỉnh/thành phố.',
                                        );
                                        return;
                                      }
                                      setState(() {
                                        error = null;
                                        value == true
                                            ? selected.add(id)
                                            : selected.remove(id);
                                      });
                                    },
                            );
                          },
                        ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: saving || selected.isEmpty ? null : save,
                        child: Text(
                          saving ? 'Đang lưu…' : 'Lưu khu vực làm việc',
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
