import 'package:flutter/material.dart';

Future<void> openTaskLyAssistant(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => const TaskLyAssistantChat(),
    );

class TaskLyAssistantChat extends StatefulWidget {
  const TaskLyAssistantChat({super.key});
  @override
  State<TaskLyAssistantChat> createState() => _TaskLyAssistantChatState();
}

class _TaskLyAssistantChatState extends State<TaskLyAssistantChat> {
  final input = TextEditingController();
  final scroll = ScrollController();
  final messages = <({bool user, String text})>[
    (
      user: false,
      text: 'Xin chào! Mình là trợ lý TaskLy. Bạn cần tìm dịch vụ hay hướng dẫn sử dụng ứng dụng?',
    ),
  ];

  // Local guidance until a conversational AI provider is configured.
  String reply(String question) {
    final q = question.toLowerCase();
    if (q.contains('giá') || q.contains('phí')) {
      return 'Bạn có thể xem giá từng dịch vụ trong mục Dịch vụ phổ biến. Chi phí sẽ được hiển thị trong luồng đặt dịch vụ trước khi xác nhận.';
    }
    if (q.contains('máy lạnh')) {
      return 'Bạn có thể chọn Vệ sinh máy lạnh trong Dịch vụ phổ biến, sau đó chọn địa chỉ và thời gian phù hợp.';
    }
    if (q.contains('dọn') || q.contains('vệ sinh')) {
      return 'Dọn nhà phù hợp với công việc thường ngày. Tổng vệ sinh phù hợp khi bạn cần làm sạch kỹ hơn. Bạn có thể xem thông tin từng dịch vụ ở Trang chủ.';
    }
    if (q.contains('đặt')) {
      return 'Để đặt dịch vụ, nhấn “Đặt dịch vụ ngay” ở Trang chủ hoặc chọn một dịch vụ. Sau đó chọn địa chỉ, thời gian và kiểm tra thông tin trước khi xác nhận.';
    }
    if (q.contains('lịch') || q.contains('công việc')) {
      return 'Mở mục Hoạt động để xem lịch và trạng thái công việc. Trong chi tiết công việc, bạn có thể xem thông tin Partner và các thao tác hỗ trợ.';
    }
    return 'Hiện mình hỗ trợ hướng dẫn dịch vụ TaskLy bằng câu trả lời tự động. Bạn có thể hỏi về dọn nhà, vệ sinh máy lạnh, giá dịch vụ, cách đặt hoặc xem lịch công việc.';
  }

  void send([String? suggestion]) {
    final text = (suggestion ?? input.text).trim();
    if (text.isEmpty) return;
    setState(() {
      messages.add((user: true, text: text));
      messages.add((user: false, text: reply(text)));
      input.clear();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && scroll.hasClients) {
        scroll.animateTo(
          scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    input.dispose();
    scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: SizedBox(
      height: MediaQuery.sizeOf(context).height * .78,
      child: Column(
        children: [
          ListTile(
            leading: const Icon(
              Icons.smart_toy_outlined,
              color: Color(0xFF087A60),
            ),
            title: const Text(
              'TaskLy AI',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: const Text('Trợ lý dịch vụ • trả lời tự động'),
            trailing: IconButton(
              tooltip: 'Đóng',
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close),
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: scroll,
              padding: const EdgeInsets.all(16),
              itemCount: messages.length,
              itemBuilder: (_, i) => Align(
                alignment: messages[i].user
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 310),
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: messages[i].user
                        ? const Color(0xFF087A60)
                        : const Color(0xFFDDF5EE),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Text(
                    messages[i].text,
                    style: TextStyle(
                      color: messages[i].user
                          ? Colors.white
                          : const Color(0xFF0F172A),
                      height: 1.5,
                    ),
                  ),
                ),
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: ['Cách đặt dịch vụ', 'Dọn nhà', 'Giá dịch vụ']
                  .map(
                    (q) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ActionChip(
                        label: Text(q),
                        onPressed: () => send(q),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: input,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => send(),
                      decoration: const InputDecoration(
                        hintText: 'Bạn cần hỗ trợ gì?',
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Gửi',
                    onPressed: send,
                    icon: const Icon(
                      Icons.send_rounded,
                      color: Color(0xFF087A60),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
