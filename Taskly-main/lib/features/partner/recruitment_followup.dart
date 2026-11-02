import 'package:flutter/material.dart';

import '../../auth/api.dart';
import '../task_activity.dart';

class RecruitmentFollowup extends StatefulWidget {
  const RecruitmentFollowup({super.key, required this.session});
  final Session session;
  @override
  State<RecruitmentFollowup> createState() => _RecruitmentFollowupState();
}

class _RecruitmentFollowupState extends State<RecruitmentFollowup> {
  Map<String, dynamic>? application;
  Map<String, dynamic>? sla;
  List<dynamic> packages = [],
      orders = [],
      slots = [],
      appointments = [],
      receipts = [],
      jobs = [];
  String? packageId, size, slotId, error;
  String payment = 'AT_OFFICE';
  bool busy = false;
  final appeal = TextEditingController();
  DateTime? starts, ends;
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    appeal.dispose();
    super.dispose();
  }


  static final _defaultSlots = [
    {
      'id': 'slot_office_morning',
      'name': 'TaskLy Partner Hub - Ca Sáng',
      'remaining': 12,
      'address': 'Văn phòng tiếp nhận đối tác TaskLy (08:30 - 11:30)',
      'starts_at': DateTime.now()
          .add(const Duration(days: 1, hours: 9))
          .toIso8601String(),
    },
    {
      'id': 'slot_office_afternoon',
      'name': 'TaskLy Partner Hub - Ca Chiều',
      'remaining': 10,
      'address': 'Văn phòng tiếp nhận đối tác TaskLy (14:00 - 17:00)',
      'starts_at': DateTime.now()
          .add(const Duration(days: 1, hours: 14))
          .toIso8601String(),
    },
  ];

  Future<void> load() async {
    setState(() => busy = true);
    try {
      final appRes = await widget.session
          .request('/partner/onboarding')
          .catchError((_) => <String, dynamic>{'status': 'REGISTERED'});
      final uniformsRes = await widget.session
          .request('/partner/uniforms')
          .catchError((_) => <dynamic>[]);
      final ordersRes = await widget.session
          .request('/partner/uniform-orders')
          .catchError((_) => <dynamic>[]);
      final slotsRes = await widget.session
          .request('/partner/appointment-slots')
          .catchError((_) => <dynamic>[]);
      final apptsRes = await widget.session
          .request('/partner/appointments')
          .catchError((_) => <dynamic>[]);
      final receiptsRes = await widget.session
          .request('/partner/document-receipts')
          .catchError((_) => <dynamic>[]);
      final slaRes = await widget.session
          .request('/partner/onboarding/sla')
          .catchError((_) => <String, dynamic>{});

      if (!mounted) return;
      setState(() {
        application = Map<String, dynamic>.from(
          appRes is Map ? appRes : {'status': 'REGISTERED'},
        );
        packages = uniformsRes is List ? uniformsRes : [];
        orders = ordersRes is List ? ordersRes : [];
        slots = (slotsRes is List && slotsRes.isNotEmpty)
            ? slotsRes
            : _defaultSlots;
        appointments = apptsRes is List ? apptsRes : [];
        receipts = receiptsRes is List ? receiptsRes : [];
        sla = slaRes is Map ? Map<String, dynamic>.from(slaRes) : {};
        if (packageId == null && packages.isNotEmpty) {
          packageId = packages.first['id']?.toString();
        }
      });
      if (application!['status'] == 'ACTIVE') {
        final result = await widget.session
            .request('/partner/jobs')
            .catchError((_) => []);
        if (mounted && result is List) setState(() => jobs = result);
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> action(String path, {Map<String, dynamic>? body}) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.session.request(path, method: 'POST', body: body);
      await load();
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> date(bool start) async {
    final day = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      initialDate: DateTime.now(),
    );
    if (day == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time == null || !mounted) return;
    setState(() {
      final value = DateTime(
        day.year,
        day.month,
        day.day,
        time.hour,
        time.minute,
      );
      if (start) {
        starts = value;
      } else {
        ends = value;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final status = application?['status'];
    String localTime(dynamic value) {
      final date = DateTime.tryParse('$value')?.toLocal();
      if (date == null) return 'Chưa có';
      final locale = MaterialLocalizations.of(context);
      return '${locale.formatMediumDate(date)} ${locale.formatTimeOfDay(TimeOfDay.fromDateTime(date))}';
    }

    Map<String, dynamic>? selected;
    for (final p in packages) {
      if (p['id'] == packageId) selected = Map<String, dynamic>.from(p);
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Hồ sơ & kích hoạt')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          ...receipts.map(
            (r) => Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Biên nhận hồ sơ',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text('Mã: ${r['id']}'),
                    Text(
                      r['complete'] == true
                          ? 'Đã nhận đủ hồ sơ hợp lệ'
                          : 'Cần bổ sung hồ sơ',
                    ),
                    Text(
                      r['originals_returned'] == true
                          ? 'Đã trả lại bản chính'
                          : 'Chưa xác nhận trả bản chính',
                    ),
                    Text('${r['notes'] ?? ''}'),
                    Text('${r['received_at'] ?? ''}'),
                  ],
                ),
              ),
            ),
          ),
          if (busy) const LinearProgressIndicator(),
          if (error != null)
            Text(error!, style: const TextStyle(color: Colors.red)),
          // THẺ TỔNG QUAN TIẾN ĐỘ & TRẠNG THÁI
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            color: const Color(0xFFF8FAFC),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDBEAFE),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Chặng 3: Xác minh & Nhận đồng phục',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1D4ED8),
                          ),
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFBFDBFE)),
                        ),
                        child: Text(
                          '$status',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF2563EB),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Quy trình xác minh & chuẩn bị nhận việc',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Bạn có thể xem trước và chọn gói đồng phục tiêu chuẩn, cũng như đặt lịch hẹn đối chiếu CCCD gốc tại văn phòng TaskLy Partner Hub.',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: Color(0xFF64748B),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (sla?['expectedUntil'] != null &&
              [
                'DOCUMENTS_RECEIVED',
                'FINAL_REVIEW',
                'ESCALATED',
              ].contains(status))
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Đang xét duyệt cuối',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      'Dự kiến ${sla!['sla_min_hours']}–${sla!['sla_max_hours']} giờ làm việc từ khi nhận đủ hồ sơ.',
                    ),
                    Text(
                      'Từ ${localTime(sla!['expectedFrom'])} đến ${localTime(sla!['expectedUntil'])}',
                    ),
                    const Text(
                      'Không tính cuối tuần và ngày nghỉ của văn phòng. Thời gian hiển thị theo thiết bị.',
                    ),
                  ],
                ),
              ),
            ),
          if (true) ...[
            const SizedBox(height: 16),
            const Text(
              'Đồng phục',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const Text(
              'Giá và chính sách do Admin cấu hình. Gói đắt hơn không được ưu tiên việc.',
            ),
            DropdownButtonFormField<String>(
              initialValue: packageId,
              decoration: const InputDecoration(labelText: 'Chọn gói'),
              items: packages
                  .map(
                    (p) => DropdownMenuItem<String>(
                      value: p['id'],
                      child: Text('${p['name']} • ${p['price']} đ'),
                    ),
                  )
                  .toList(),
              onChanged: busy
                  ? null
                  : (v) => setState(() {
                      packageId = v;
                      size = null;
                    }),
            ),
            if (selected != null) ...[
              Text(selected['description']),
              Text(selected['policy']),
              DropdownButtonFormField<String>(
                key: ValueKey(packageId),
                initialValue: size,
                decoration: const InputDecoration(labelText: 'Kích thước'),
                items: (selected['sizes'] as Map).entries
                    .map(
                      (e) => DropdownMenuItem<String>(
                        value: e.key,
                        child: Text('${e.key} • còn ${e.value}'),
                      ),
                    )
                    .toList(),
                onChanged: busy ? null : (v) => setState(() => size = v),
              ),
            ],
            DropdownButtonFormField<String>(
              initialValue: payment,
              items: const [
                DropdownMenuItem(
                  value: 'AT_OFFICE',
                  child: Text('Thanh toán tại văn phòng'),
                ),
                DropdownMenuItem(
                  value: 'ONLINE',
                  child: Text('Online SANDBOX'),
                ),
              ],
              onChanged: busy ? null : (v) => setState(() => payment = v!),
            ),
            FilledButton(
              onPressed: busy || packageId == null || size == null
                  ? null
                  : () => action(
                      '/partner/uniform-orders',
                      body: {
                        'packageId': packageId,
                        'size': size,
                        'paymentMethod': payment,
                        'requestId':
                            'uniform-${application!['id']}-${DateTime.now().microsecondsSinceEpoch}',
                      },
                    ),
              child: const Text('Xác nhận đặt đồng phục'),
            ),
            ...orders.map(
              (o) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Đơn ${o['id']}'),
                      Text(
                        '${o['size']} • ${o['price']} đ • ${o['payment_status']}',
                      ),
                      if (o['receipt_id'] != null)
                        Text('Biên nhận: ${o['receipt_id']}'),
                      if (o['payment_method'] == 'ONLINE' &&
                          [
                            'PENDING',
                            'FAILED',
                          ].contains(o['payment_status'])) ...[
                        const Text(
                          'Mô phỏng development/test, không thu tiền thật',
                        ),
                        TextButton(
                          onPressed: busy
                              ? null
                              : () => action(
                                  '/partner/uniform-orders/${o['id']}/payment',
                                  body: {'result': 'SUCCESS'},
                                ),
                          child: const Text('Giả lập thành công'),
                        ),
                        TextButton(
                          onPressed: busy
                              ? null
                              : () => action(
                                  '/partner/uniform-orders/${o['id']}/payment',
                                  body: {'result': 'FAILURE'},
                                ),
                          child: const Text('Giả lập thất bại'),
                        ),
                      ],
                      if (o['status'] == 'RESERVED' &&
                          !['PAID', 'WAIVED'].contains(o['payment_status']))
                        TextButton(
                          onPressed: busy
                              ? null
                              : () => action(
                                  '/partner/uniform-orders/${o['id']}/cancel',
                                ),
                          child: const Text('Hủy đơn chưa thanh toán'),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Lịch hẹn nộp hồ sơ',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            DropdownButtonFormField<String>(
              initialValue: slotId,
              decoration: const InputDecoration(
                labelText: 'Văn phòng & khung giờ',
              ),
              items: slots
                  .map(
                    (s) => DropdownMenuItem<String>(
                      value: s['id'],
                      child: Text(
                        '${s['name']} • còn ${s['remaining']} chỗ',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: busy ? null : (v) => setState(() => slotId = v),
            ),
            if (slotId != null)
              ...slots
                  .where((s) => s['id'] == slotId)
                  .map(
                    (s) => Text(
                      '${s['address']}\n${DateTime.parse(s['starts_at']).toLocal()}',
                    ),
                  ),
            FilledButton(
              onPressed: busy || slotId == null
                  ? null
                  : () => action(
                      '/partner/appointments',
                      body: {
                        'slotId': slotId,
                        'requestId':
                            'appointment-${application!['id']}-${DateTime.now().microsecondsSinceEpoch}',
                      },
                    ),
              child: const Text('Đặt lịch'),
            ),
            ...appointments.map(
              (a) => Card(
                child: ListTile(
                  title: Text('${a['name']} • ${a['status']}'),
                  subtitle: Text(
                    '${a['address']}\n${DateTime.parse(a['starts_at']).toLocal()}\nMã check-in: ${a['checkin_code']}',
                  ),
                  trailing: a['status'] == 'BOOKED'
                      ? IconButton(
                          tooltip: 'Hủy lịch để đổi khung giờ',
                          onPressed: busy
                              ? null
                              : () => action(
                                  '/partner/appointments/${a['id']}/cancel',
                                ),
                          icon: const Icon(Icons.cancel_outlined),
                        )
                      : null,
                ),
              ),
            ),
          ],
          if (status == 'APPROVED') ...[
            const Text(
              'Chọn lịch rảnh để kích hoạt. Kỹ năng và khu vực dùng thông tin đăng ký đã duyệt.',
            ),
            TextButton(
              onPressed: () => date(true),
              child: Text(
                starts == null
                    ? 'Chọn thời gian bắt đầu'
                    : 'Từ: ${starts!.toLocal()}',
              ),
            ),
            TextButton(
              onPressed: () => date(false),
              child: Text(
                ends == null
                    ? 'Chọn thời gian kết thúc'
                    : 'Đến: ${ends!.toLocal()}',
              ),
            ),
            FilledButton(
              onPressed: busy || starts == null || ends == null
                  ? null
                  : () => action(
                      '/partner/activation',
                      body: {
                        'version': application!['version'],
                        'startsAt': starts!.toUtc().toIso8601String(),
                        'endsAt': ends!.toUtc().toIso8601String(),
                      },
                    ),
              child: const Text('Kích hoạt nhận việc'),
            ),
          ],
          if (['REJECTED', 'SUSPENDED'].contains(status)) ...[
            Text(application!['reason'] ?? ''),
            TextField(
              controller: appeal,
              onChanged: (_) => setState(() {}),
              maxLength: 1000,
              decoration: const InputDecoration(
                labelText: 'Lý do đề nghị xem xét lại',
              ),
            ),
            FilledButton(
              onPressed: busy || appeal.text.trim().isEmpty
                  ? null
                  : () => action(
                      '/partner/appeals',
                      body: {'reason': appeal.text},
                    ),
              child: const Text('Gửi đề nghị'),
            ),
          ],
          if (status == 'ACTIVE') ...[
            TaskActivityList(session: widget.session, partner: true),
            const Text('Công việc phù hợp'),
            if (jobs.isEmpty)
              const Text(
                'Chưa có công việc phù hợp khu vực, dịch vụ và lịch rảnh.',
              ),
            ...jobs.map(
              (j) => Card(
                child: ListTile(
                  title: Text(j['title']),
                  subtitle: Text(
                    '${j['city_snapshot']} • Thực nhận: ${j['partner_net_amount']} đ',
                  ),
                  trailing: FilledButton(
                    onPressed: busy
                        ? null
                        : () => action('/partner/jobs/${j['id']}/accept'),
                    child: const Text('Nhận việc'),
                  ),
                ),
              ),
            ),
          ],
          TextButton(
            onPressed: busy ? null : load,
            child: const Text('Tải lại từ máy chủ'),
          ),
        ],
      ),
    );
  }
}
