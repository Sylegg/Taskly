import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../auth/api.dart';

class RecruitmentIdentity extends StatefulWidget {
  const RecruitmentIdentity({super.key, required this.session});
  final Session session;
  @override
  State<RecruitmentIdentity> createState() => _RecruitmentIdentityState();
}

class _RecruitmentIdentityState extends State<RecruitmentIdentity> {
  Map<String, dynamic>? verification;
  Map<String, dynamic>? application;
  final name = TextEditingController(), number = TextEditingController();
  final form = GlobalKey<FormState>();
  final previews = <String, Uint8List>{};
  String type = 'NATIONAL_ID';
  String? error;
  bool busy = false, consent = false;
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    name.dispose();
    number.dispose();
    previews.clear();
    super.dispose();
  }

  Future<void> load() async {
    setState(() => busy = true);
    try {
      await widget.session.request('/users/me/modes/tasker', method: 'POST');
      var result = await widget.session.request('/verifications/me');
      final profile = await widget.session.request('/partner/onboarding');
      if (result == null ||
          ['REJECTED', 'EXPIRED'].contains(result['status'])) {
        result = await widget.session.request('/verifications', method: 'POST');
      }
      if (!mounted) return;
      setState(() {
        verification = Map<String, dynamic>.from(result);
        application = Map<String, dynamic>.from(profile);
        name.text = verification!['legalName'] ?? '';
        if ([
          'NATIONAL_ID',
          'PASSPORT',
        ].contains(verification!['documentType'])) {
          type = verification!['documentType'];
        }
        error = null;
      });
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> pick(String side) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['png', 'jpg', 'jpeg'],
      );
      if (file == null) return;
      final length = await file.length();
      if (length == null || length <= 0 || length > 10 * 1024 * 1024) {
        throw ApiFailure('IMAGE_SIZE', 'Ảnh tối đa 10 MB.', 0);
      }
      final bytes = await file.readAsBytes();
      final result = await widget.session.uploadVerificationImage(
        verification!['id'],
        side,
        bytes,
      );
      if (mounted) {
        setState(() {
          verification = Map<String, dynamic>.from(result);
          previews[side] = bytes;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> submit({bool draftOnly = false}) async {
    if (!draftOnly && !form.currentState!.validate()) return;
    if (!draftOnly && verification?['status'] == 'DRAFT' && !consent) {
      setState(() => error = 'Cần chấp thuận xử lý dữ liệu xác minh.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final saved = await widget.session.request(
        '/verifications/${verification!['id']}/draft',
        method: 'PATCH',
        body: {
          'legalName': name.text.trim(),
          'documentType': type,
          'documentNumber': number.text.trim(),
        },
      );
      if (mounted) {
        setState(() => verification = Map<String, dynamic>.from(saved));
      }
      if (draftOnly || verification?['status'] == 'SUBMITTED') {
        if (mounted) Navigator.pop(context, true);
        return;
      }
      final result = await widget.session.request(
        '/verifications/${verification!['id']}/submit',
        method: 'POST',
        body: {'consent': consent},
      );
      if (mounted) {
        setState(() => verification = Map<String, dynamic>.from(result));
      }
      await widget.session.request('/partner/kyc/submit', method: 'POST');
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = verification?['status'] == 'DRAFT';
    final amendment =
        verification?['status'] == 'SUBMITTED' &&
        application?['status'] == 'PRELIMINARY_REVIEW' &&
        application?['editable'] == true;
    final documents = verification?['documents'] as List? ?? [];
    return Scaffold(
      appBar: AppBar(title: const Text('Hồ sơ định danh')),
      body: SafeArea(
        child: Form(
          key: form,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text(
                'Ảnh được tải vào kho riêng tư. Ảnh chờ kiểm tra an toàn chưa có liên kết xem công khai. Dùng giấy tờ hư cấu trong môi trường thử nghiệm.',
              ),
              if (error != null)
                Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              if (busy) const LinearProgressIndicator(),
              if (verification == null)
                OutlinedButton(
                  onPressed: busy ? null : load,
                  child: const Text('Tải lại hồ sơ'),
                ),
              if (verification != null)
                Text('Trạng thái: ${verification!['status']}'),
              if (application?['status'] == 'ESCALATED' && application?['editableUntil'] != null)
                Text(() {
                  final dt = DateTime.tryParse(application!['editableUntil'].toString())?.toLocal();
                  final timeStr = dt != null
                      ? '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}, ngày ${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}'
                      : application!['editableUntil'].toString();
                  return 'Dự kiến phản hồi: $timeStr';
                }()),
              if (draft || amendment) ...[
                TextFormField(
                  controller: name,
                  maxLength: 160,
                  decoration: const InputDecoration(
                    labelText: 'Họ tên trên giấy tờ',
                  ),
                  validator: (s) => s == null || s.trim().length < 2
                      ? 'Nhập họ tên hợp lệ'
                      : null,
                ),
                DropdownButtonFormField<String>(
                  initialValue: type,
                  items: const [
                    DropdownMenuItem(
                      value: 'NATIONAL_ID',
                      child: Text('Giấy tờ định danh'),
                    ),
                    DropdownMenuItem(
                      value: 'PASSPORT',
                      child: Text('Hộ chiếu'),
                    ),
                  ],
                  onChanged: busy ? null : (v) => setState(() => type = v!),
                  decoration: const InputDecoration(labelText: 'Loại giấy tờ'),
                ),
                TextFormField(
                  controller: number,
                  maxLength: 30,
                  decoration: InputDecoration(
                    labelText: 'Số giấy tờ',
                    hintText: verification?['documentNumberMasked'],
                    helperText: verification?['documentNumberMasked'] != null
                        ? 'Để trống nếu giữ nguyên số giấy tờ'
                        : null,
                  ),
                  validator: (s) {
                    if ((s == null || s.trim().isEmpty) &&
                        verification?['documentNumberMasked'] != null) {
                      return null;
                    }
                    return s == null || s.trim().length < 6
                        ? 'Nhập thông tin hợp lệ (6–30 ký tự)'
                        : null;
                  },
                ),
                for (final side in ['FRONT', 'BACK'])
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        children: [
                          Text(side == 'FRONT' ? 'Mặt trước' : 'Mặt sau'),
                          AspectRatio(
                            aspectRatio: 1.6,
                            child: previews.containsKey(side)
                                ? Image.memory(
                                    previews[side]!,
                                    fit: BoxFit.contain,
                                    semanticLabel: side == 'FRONT'
                                        ? 'Xem trước mặt trước'
                                        : 'Xem trước mặt sau',
                                  )
                                : const Icon(Icons.image_outlined, size: 48),
                          ),
                          Text(
                            documents.any((d) => d['side'] == side)
                                ? 'Đã tải ảnh lên • ${documents.firstWhere((d) => d['side'] == side)['scanStatus']}'
                                : 'Chưa tải ảnh',
                          ),
                          OutlinedButton.icon(
                            onPressed: busy ? null : () => pick(side),
                            icon: const Icon(Icons.upload),
                            label: const Text('Chọn ảnh PNG / JPEG'),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (draft)
                  CheckboxListTile(
                    value: consent,
                    onChanged: busy
                        ? null
                        : (v) => setState(() => consent = v ?? false),
                    title: const Text(
                      'Tôi đồng ý xử lý dữ liệu cho mục đích xác minh hồ sơ',
                    ),
                  ),
                FilledButton(
                  onPressed: busy ? null : () => submit(),
                  child: Text(
                    amendment ? 'Lưu bổ sung hồ sơ' : 'Gửi hồ sơ xét duyệt',
                  ),
                ),
                if (draft)
                  OutlinedButton.icon(
                    onPressed: busy ? null : () => submit(draftOnly: true),
                    icon: const Icon(Icons.bookmark_outline),
                    label: const Text('Lưu nháp và thoát'),
                  ),
              ] else if (verification != null) ...[
                Text(verification!['decisionReason'] ?? ''),
                OutlinedButton(
                  onPressed: busy
                      ? null
                      : () async {
                          setState(() => busy = true);
                          try {
                            await widget.session.request(
                              '/partner/kyc/submit',
                              method: 'POST',
                            );
                            if (context.mounted) Navigator.pop(context, true);
                          } catch (e) {
                            if (mounted) setState(() => error = e.toString());
                          } finally {
                            if (mounted) setState(() => busy = false);
                          }
                        },
                  child: const Text('Đồng bộ hồ sơ tuyển dụng'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
