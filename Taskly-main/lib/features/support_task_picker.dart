import 'package:flutter/material.dart';

import '../auth/api.dart';

class SupportTaskPicker extends StatelessWidget {
  const SupportTaskPicker({
    super.key,
    required this.session,
    required this.partner,
    required this.enabled,
    required this.selected,
    required this.onChanged,
  });
  final Session session;
  final bool partner, enabled;
  final Map<String, dynamic>? selected;
  final ValueChanged<Map<String, dynamic>?> onChanged;

  Future<void> _choose(BuildContext context) async {
    final tasks = session.request(
      partner ? '/support/tasks' : '/customer/support/tasks',
    );
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheet) => SizedBox(
        height: MediaQuery.sizeOf(sheet).height * .65,
        child: Column(
          children: [
            const ListTile(
              title: Text(
                'Chọn đơn dịch vụ cần hỗ trợ',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.support_agent),
              title: const Text('Hỗ trợ chung / tài khoản'),
              onTap: () {
                onChanged(null);
                Navigator.pop(sheet);
              },
            ),
            Expanded(
              child: FutureBuilder<dynamic>(
                future: tasks,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Center(
                      child: Text(
                        'Không tải được đơn dịch vụ. Vui lòng mở lại để thử.',
                      ),
                    );
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final items = (snapshot.data as List)
                      .where(
                        (task) => const {
                          'POSTED',
                          'MATCHING',
                          'ACCEPTED',
                          'TASKER_ON_THE_WAY',
                          'ARRIVED',
                          'IN_PROGRESS',
                          'DISPUTED',
                        }.contains(task['status']),
                      )
                      .toList();
                  if (items.isEmpty) {
                    return const Center(
                      child: Text('Bạn chưa có đơn dịch vụ đang hoạt động.'),
                    );
                  }
                  return ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (_, index) {
                      final task = Map<String, dynamic>.from(items[index]);
                      final scheduled = DateTime.tryParse(
                        task['scheduledAt']?.toString() ?? '',
                      )?.toLocal();
                      final date = scheduled == null
                          ? ''
                          : '${scheduled.day}/${scheduled.month}/${scheduled.year} ${scheduled.hour.toString().padLeft(2, '0')}:${scheduled.minute.toString().padLeft(2, '0')}';
                      return ListTile(
                        leading: const Icon(Icons.receipt_long_outlined),
                        title: Text(
                          task['serviceName']?.toString() ?? 'Đơn dịch vụ',
                        ),
                        subtitle: Text(
                          '#${task['id']}\n$date • ${task['address'] ?? ''}',
                        ),
                        isThreeLine: true,
                        selected: selected?['id'] == task['id'],
                        onTap: () {
                          onChanged(task);
                          Navigator.pop(sheet);
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListTile(
    leading: const Icon(Icons.receipt_long_outlined),
    title: Text(
      selected == null
          ? 'Chọn đơn dịch vụ cần hỗ trợ'
          : selected!['serviceName']?.toString() ?? 'Đơn dịch vụ',
    ),
    subtitle: Text(
      selected == null
          ? 'Hoặc gửi yêu cầu hỗ trợ chung'
          : '#${selected!['id']}',
    ),
    trailing: const Icon(Icons.expand_more),
    onTap: enabled ? () => _choose(context) : null,
  );
}
