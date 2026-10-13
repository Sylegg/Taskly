import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'support_images.dart';
import '../support_task_picker.dart';

import 'dart:math';

import 'package:flutter/material.dart';

import '../../auth/api.dart';
import '../task_activity.dart';

const _endedJobStatuses = {'COMPLETED', 'PAID', 'CANCELLED', 'REFUNDED', 'EXPIRED'};

Future<void> openPartnerJobHistory(BuildContext context, Session session) =>
    Navigator.of(context).push<void>(MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(title: const Text('Lịch sử nhận việc')),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: TaskActivityList(
            session: session, partner: true, showHeading: false,
            filter: (task) => _endedJobStatuses.contains(task['status']),
            emptyWidget: const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: Text('Chưa có lịch sử nhận việc.')),
            ),
          ),
        ),
      ),
    ));

class PartnerInbox extends StatefulWidget {
  const PartnerInbox({super.key, required this.session});
  final Session session;
  @override
  State<PartnerInbox> createState() => _PartnerInboxState();
}

class _PartnerInboxState extends State<PartnerInbox> {
  int selected = 0;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SegmentedButton<int>(
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(
            value: 0,
            icon: Icon(Icons.work_outline),
            label: Text('Công việc'),
          ),
          ButtonSegment(
            value: 1,
            icon: Icon(Icons.support_agent),
            label: Text('Hỗ trợ'),
          ),
        ],
        selected: {selected},
        onSelectionChanged: (value) => setState(() => selected = value.first),
      ),
      const SizedBox(height: 20),
      if (selected == 0) ...[
        const Text(
          'Nhắn tin & tiến trình công việc',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        const Text(
          'Chọn công việc để nhắn tin với khách hàng và báo cáo tiến trình.',
        ),
        const SizedBox(height: 12),
        TaskActivityList(
          session: widget.session,
          partner: true,
          showHeading: false,
          filter: (task) => !_endedJobStatuses.contains(task['status']),
          emptyWidget: const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: Text('Bạn chưa có công việc đang xử lý.')),
          ),
        ),
      ] else ...[
        const Text(
          'Bạn cần hỗ trợ gì?',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: const Icon(Icons.auto_awesome),
            title: const Text('Trợ lý AI'),
            subtitle: const Text('Chưa kết nối dịch vụ AI'),
            onTap: () => showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Trợ lý AI'),
                content: const Text(
                  'Dịch vụ AI đang chờ cấu hình. Bạn có thể nhắn tin với chăm sóc khách hàng.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Đóng'),
                  ),
                ],
              ),
            ),
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.support_agent),
            title: const Text('Chăm sóc khách hàng'),
            subtitle: const Text('Gửi tin nhắn và theo dõi phản hồi'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SupportConversation(session: widget.session),
              ),
            ),
          ),
        ),
      ],
    ],
  );
}

class SupportConversation extends StatefulWidget {
  const SupportConversation({super.key, required this.session});
  final Session session;
  @override
  State<SupportConversation> createState() => _SupportConversationState();
}

class _SupportConversationState extends State<SupportConversation> {
  final input = TextEditingController();
  final messageScroll = ScrollController();
  List<dynamic> messages = [];
  final messageImages = <String, Uint8List>{};
  bool refreshing = false;
  bool loading = true, sending = false;
  String? error;
  Timer? timer;
  String? requestId;
  String? imageData;
  Map<String, dynamic>? selectedTask;
  Future<void> pickImage() async {
    try {
      final image = await pickSupportImage();
      if (mounted && image != null) setState(() => imageData = image);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    }
  }

  String uuid() {
    final r = Random.secure();
    final b = List.generate(16, (_) => r.nextInt(256));
    b[6] = (b[6] & 15) | 64;
    b[8] = (b[8] & 63) | 128;
    final s = b.map((v) => v.toRadixString(16).padLeft(2, '0')).join();
    return '${s.substring(0, 8)}-${s.substring(8, 12)}-${s.substring(12, 16)}-${s.substring(16, 20)}-${s.substring(20)}';
  }

  StreamSubscription<void>? _liveSubscription;
  @override
  void initState() {
    super.initState();
    _liveSubscription = widget.session.liveChanges.listen((_) {
      if (mounted) load();
    });
    load();
  }

  @override
  void dispose() {
    _liveSubscription?.cancel();
    timer?.cancel();
    input.dispose();
    messageScroll.dispose();
    super.dispose();
  }

  Future<void> load() async {
    if (refreshing) return;
    refreshing = true;
    try {
      final result = await widget.session.request('/support/messages');
      if (mounted)
        setState(() {
          final next = result as List;
          for (final message in next) {
            final data = message['image_data']?.toString();
            if (data != null && data.isNotEmpty) {
              messageImages.putIfAbsent(
                message['id'].toString(),
                () => base64Decode(data.split(',').last),
              );
            }
          }
          messages = next;
          error = null;
        });
    } catch (_) {
      if (mounted)
        setState(() => error = 'Không thể tải tin nhắn. Vui lòng thử lại.');
    } finally {
      refreshing = false;
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> reloadLatest() async {
    await load();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && messageScroll.hasClients) messageScroll.jumpTo(0);
    });
  }

  Future<void> send() async {
    final text = input.text.trim();
    if ((text.isEmpty && imageData == null) || sending) return;
    setState(() => sending = true);
    requestId ??= uuid();
    try {
      await widget.session.request(
        '/support/messages',
        method: 'POST',
        body: {
          'requestId': requestId,
          'text': text.isEmpty ? 'Ảnh đính kèm' : text,
          if (imageData != null) 'imageData': imageData,
          if (selectedTask != null) 'taskId': selectedTask!['id'],
        },
      );
      input.clear();
      requestId = null;
      imageData = null;
      await reloadLatest();
    } catch (_) {
      if (mounted)
        setState(
          () =>
              error = 'Gửi chưa thành công. Nội dung được giữ lại để thử lại.',
        );
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Chăm sóc khách hàng'),
      actions: [
        IconButton(
          onPressed: reloadLatest,
          tooltip: 'Tải lại và xem tin nhắn mới nhất',
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(12),
          child: Text(
            'Tin nhắn được lưu để chăm sóc khách hàng tiếp nhận và phản hồi.',
          ),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(error!, style: const TextStyle(color: Colors.red)),
          ),
        Expanded(
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : messages.isEmpty
              ? const Center(child: Text('Bạn chưa có tin nhắn hỗ trợ.'))
              : ListView.builder(
                  controller: messageScroll,
                  reverse: true,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  findChildIndexCallback: (key) {
                    if (key is! ValueKey) return null;
                    final index = messages.indexWhere(
                      (m) => m['id'] == key.value,
                    );
                    return index < 0 ? null : messages.length - 1 - index;
                  },
                  itemBuilder: (context, index) {
                    final m = messages[messages.length - 1 - index];
                    final mine = m['sender'] == 'USER';
                    final imageBytes = messageImages[m['id'].toString()];
                    return Align(
                      key: ValueKey(m['id']),
                      alignment: mine
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        constraints: const BoxConstraints(maxWidth: 300),
                        decoration: BoxDecoration(
                          color: mine
                              ? const Color(0xFFDDF7EF)
                              : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              mine ? 'Bạn' : 'Chăm sóc khách hàng',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (m['task_id'] != null)
                              Text(
                                'Đơn dịch vụ: ${m['task_id']}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            Text(m['content'] ?? ''),
                            if (imageBytes != null)
                              GestureDetector(
                                onTap: () => showDialog(
                                  context: context,
                                  builder: (_) => Dialog(
                                    child: InteractiveViewer(
                                      child: Image.memory(imageBytes),
                                    ),
                                  ),
                                ),
                                child: Image.memory(
                                  imageBytes,
                                  width: 250,
                                  height: 180,
                                  gaplessPlayback: true,
                                  fit: BoxFit.contain,
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        if (imageData != null)
          Row(
            children: [
              Image.memory(
                base64Decode(imageData!.split(',').last),
                height: 70,
                width: 70,
              ),
              IconButton(
                onPressed: sending
                    ? null
                    : () => setState(() => imageData = null),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        SupportTaskPicker(
          session: widget.session,
          partner: true,
          enabled: !sending,
          selected: selectedTask,
          onChanged: (task) => setState(() {
            selectedTask = task;
            requestId = null;
          }),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                IconButton(
                  onPressed: sending ? null : pickImage,
                  icon: const Icon(Icons.image_outlined),
                  tooltip: 'Gửi ảnh',
                ),
                Expanded(
                  child: TextField(
                    controller: input,
                    enabled: !sending,
                    maxLength: 4000,
                    minLines: 1,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      hintText: 'Nhập nội dung cần hỗ trợ',
                      counterText: '',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: sending ? null : send,
                  icon: sending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(),
                        )
                      : const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
