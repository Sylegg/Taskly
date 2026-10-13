import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../auth/api.dart';

/// Reusable helper to pick an image for chat (PNG/JPEG <= 2MB)
Future<String?> pickChatImage() async {
  final result = await FilePicker.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['jpg', 'jpeg', 'png'],
  );
  if (result.isEmpty) return null;
  final bytes = await result.single.readAsBytes();
  if (bytes.length > 2000000) {
    throw Exception('Vui lòng chọn ảnh PNG hoặc JPEG có dung lượng tối đa 2 MB.');
  }
  final png =
      bytes.length > 8 && bytes[0] == 137 && bytes[1] == 80 && bytes[2] == 78;
  final jpeg = bytes.length > 3 && bytes[0] == 255 && bytes[1] == 216;
  if (!png && !jpeg) {
    throw Exception('Ảnh phải có định dạng PNG hoặc JPEG.');
  }
  return 'data:image/${png ? 'png' : 'jpeg'};base64,${base64Encode(bytes)}';
}

/// Trang chat riêng giữa Khách hàng (Customer) và Đối tác (Partner / Tasker)
class TaskChatScreen extends StatefulWidget {
  const TaskChatScreen({
    super.key,
    required this.session,
    required this.taskId,
    this.partner = false,
    this.checkInMode = false,
    this.completionMode = false,
    this.initialTaskerName,
    this.initialCustomerName,
    this.initialServiceName,
  });

  final Session session;
  final String taskId;
  final bool partner;
  final bool checkInMode;
  final bool completionMode;
  final String? initialTaskerName;
  final String? initialCustomerName;
  final String? initialServiceName;

  @override
  State<TaskChatScreen> createState() => _TaskChatScreenState();
}

class _TaskChatScreenState extends State<TaskChatScreen> {
  final TextEditingController _input = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  Map<String, dynamic>? _detail;
  bool _loading = true;
  bool _sending = false;
  String? _error;
  String? _pickedImageData;
  String? _requestId;
  String? _sentCheckInPhoto;
  bool _arrived = false;
  final List<String> _completionPhotos = [];
  bool _confirmedAllAreas = false;
  bool _restoringPhotos = false;
  Future<void> _photoWrites = Future.value();

  Future<File> _photoDraftFile() async {
    final root = await getApplicationDocumentsDirectory();
    final owner = widget.session.user?['id']?.toString() ?? 'partner';
    return File('${root.path}/completion_${owner}_${widget.taskId}.json');
  }

  Future<void> _savePhotoDraft() {
    final payload = jsonEncode(_completionPhotos);
    _photoWrites = _photoWrites.catchError((_) {}).then((_) async {
      final file = await _photoDraftFile();
      final temporary = File('${file.path}.tmp');
      await temporary.writeAsString(payload, flush: true);
      await temporary.rename(file.path);
    });
    return _photoWrites;
  }

  Future<void> _restorePhotoDraft() async {
    try {
      final file = await _photoDraftFile();
      if (await file.exists()) {
        final photos = List<String>.from(jsonDecode(await file.readAsString()));
        if (mounted) setState(() => _completionPhotos.addAll(photos.take(10)));
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Không thể khôi phục ảnh đã lưu.')));
    } finally {
      if (mounted) setState(() => _restoringPhotos = false);
    }
  }

  Timer? _pollingTimer;
  StreamSubscription<void>? _liveSubscription;
  final Map<String, Uint8List> _imageCache = {};

  @override
  void initState() {
    super.initState();
    if (widget.completionMode) _restoringPhotos = true;
    if (widget.checkInMode || widget.completionMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (widget.completionMode) await _restorePhotoDraft();
        if (!mounted) return;
        if (widget.completionMode && _completionPhotos.length >= 2) return;
        final capture = await showDialog<bool>(context: context, barrierDismissible: !widget.completionMode, builder: (ctx) => AlertDialog(
          title: Text(widget.completionMode ? 'Ảnh hoàn thành công việc' : 'Chụp ảnh check-in'),
          content: Text(widget.completionMode ? 'Chụp ít nhất 2 ảnh, bao gồm toàn bộ khu vực đã làm và các vị trí khách yêu cầu. Gửi ảnh để xác nhận hoàn thành.' : 'Bạn phải chụp ảnh tại địa điểm dịch vụ. Bấm gửi ảnh để đồng thời xác nhận check-in và gửi thông báo cho khách hàng.'),
          actions: [
            if (!widget.completionMode) TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Để sau')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Chụp ảnh')),
          ],
        ));
        if (capture == true && mounted) await _pickImage();
      });
    }
    _load();
    _liveSubscription = widget.session.liveChanges.listen((_) {
      if (mounted) _load(silent: true);
    });
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted && !_sending) _load(silent: true);
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _liveSubscription?.cancel();
    _input.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String _uuid() {
    final r = Random.secure();
    final bytes = List.generate(16, (_) => r.nextInt(256));
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final h = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final res = await widget.session.request('/task-activity/${widget.taskId}?partner=${widget.partner}');
      if (mounted) {
        final previousMessages = _detail?['messages'] as List? ?? [];
        final nextMessages = (res as Map<String, dynamic>)['messages'] as List? ?? [];
        final followLatest = !_scrollController.hasClients ||
            _scrollController.position.pixels <= 80;
        final hasNewMessage = nextMessages.isNotEmpty &&
            (previousMessages.isEmpty ||
                previousMessages.last['id'] != nextMessages.last['id']);
        setState(() {
          _detail = res;
          _error = null;
          _loading = false;
        });
        _cacheImages();
        if (hasNewMessage && followLatest) _scrollToBottom();
      }
    } catch (e) {
      if (mounted && !silent) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  void _cacheImages() {
    final messages = _detail?['messages'] as List? ?? [];
    for (final m in messages) {
      final raw = (m['imageData'] ?? m['image_data'])?.toString();
      if (raw != null && raw.isNotEmpty && raw.contains(',')) {
        final id = m['id']?.toString() ?? raw.hashCode.toString();
        _imageCache.putIfAbsent(id, () {
          try {
            return base64Decode(raw.split(',').last);
          } catch (_) {
            return Uint8List(0);
          }
        });
      }
    }
  }

  Future<void> _pickImage() async {
    try {
      String? image;
      if ((widget.checkInMode || widget.completionMode) && !_arrived) {
        final photo = await ImagePicker().pickImage(source: ImageSource.camera,
            maxWidth: 1600, maxHeight: 1600, imageQuality: 80);
        if (photo == null) return;
        final bytes = await photo.readAsBytes();
        if (bytes.length > 2000000) throw Exception('Ảnh tối đa 2 MB. Vui lòng chụp lại.');
        image = 'data:image/jpeg;base64,${base64Encode(bytes)}';
        if (widget.completionMode) {
          if (mounted) setState(() { if (_completionPhotos.length < 10) _completionPhotos.add(image!); });
          await _savePhotoDraft();
          return;
        }
      } else {
        image = await pickChatImage();
      }
      if (mounted && image != null) {
        setState(() {
          _pickedImageData = image;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (_sending) return;
    if (widget.completionMode && !_arrived) {
      if (_completionPhotos.length < 2 || !_confirmedAllAreas) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Chụp ít nhất 2 ảnh và xác nhận đã chụp đủ các khu vực.')));
        return;
      }
      setState(() => _sending = true);
      _requestId ??= _uuid();
      try {
        await _photoWrites;
        await widget.session.request('/partner/jobs/${widget.taskId}/complete', method: 'POST',
          body: {'images': _completionPhotos, 'confirmedAllAreas': true, 'requestId': _requestId});
        if (mounted) setState(() => _arrived = true);
        final draft = await _photoDraftFile();
        if (await draft.exists()) await draft.delete();
        await _load(silent: true);
        _scrollToBottom();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      } finally { if (mounted) setState(() => _sending = false); }
      return;
    }
    if (widget.checkInMode && !_arrived) {
      if (_pickedImageData == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Bạn phải chụp ảnh trước khi gửi xác nhận check-in.'),
        ));
        await _pickImage();
        return;
      }
      _sentCheckInPhoto = _pickedImageData;
      await _confirmArrival();
      return;
    }
    if (text.isEmpty && _pickedImageData == null) return;

    setState(() => _sending = true);
    _requestId ??= _uuid();

    final payload = <String, dynamic>{
      'requestId': _requestId,
      'text': text.isNotEmpty ? text : 'Ảnh đính kèm',
      if (_pickedImageData != null) 'imageData': _pickedImageData,
    };

    try {
      await widget.session.request(
        '/task-activity/${widget.taskId}/messages?partner=${widget.partner}',
        method: 'POST',
        body: payload,
      );
      if (widget.checkInMode && !_arrived && _pickedImageData != null) {
        _sentCheckInPhoto = _pickedImageData;
      }
      _input.clear();
      _pickedImageData = null;
      _requestId = null;
      await _load(silent: true);
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Chưa gửi được tin nhắn: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _confirmArrival() async {
    if (_sending || _sentCheckInPhoto == null) return;
    setState(() => _sending = true);
    try {
      await widget.session.request('/partner/jobs/${widget.taskId}/check-in',
          method: 'POST', body: {'imageData': _sentCheckInPhoto, 'method': 'PHOTO_CHAT'});
      if (mounted) {
        setState(() {
          _arrived = true;
          _pickedImageData = null;
          _input.clear();
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Đã check-in thành công. Ảnh và thông báo đã gửi cho khách hàng.'),
        ));
      }
      await _load(silent: true);
      _scrollToBottom();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _openImageZoom(Uint8List bytes) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              minScale: 0.8,
              maxScale: 4.0,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(bytes, fit: BoxFit.contain),
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: CircleAvatar(
                backgroundColor: Colors.black54,
                radius: 18,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showTaskInfoSheet() {
    final task = _detail?['task'] as Map<String, dynamic>? ?? {};
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: widget.partner ? const Color(0xFFEFF6FF) : const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.receipt_long_rounded,
                      color: widget.partner ? const Color(0xFF1E5BF8) : const Color(0xFF059669),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task['serviceName'] ?? widget.initialServiceName ?? 'Chi tiết công việc',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                        ),
                        Text(
                          'Mã đơn: #${widget.taskId.substring(0, min(8, widget.taskId.length)).toUpperCase()}',
                          style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              _sheetRow(Icons.place_outlined, 'Địa chỉ', task['address'] ?? 'Chưa cập nhật'),
              const SizedBox(height: 10),
              _sheetRow(Icons.schedule_rounded, 'Thời gian hẹn', _formatDateTime(task['scheduledAt'])),
              const SizedBox(height: 10),
              _sheetRow(
                Icons.payments_outlined,
                'Chi phí',
                _formatCurrency(task['budgetAmount'] ?? 0),
                valueColor: widget.partner ? const Color(0xFF1E5BF8) : const Color(0xFF059669),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Đóng'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sheetRow(IconData icon, String label, String value, {Color? valueColor}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: const Color(0xFF94A3B8)),
        const SizedBox(width: 8),
        Text('$label: ', style: const TextStyle(color: Color(0xFF64748B), fontSize: 13)),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: valueColor ?? const Color(0xFF0F172A),
            ),
          ),
        ),
      ],
    );
  }

  String _formatDateTime(dynamic raw) {
    if (raw == null) return 'Chưa xếp lịch';
    try {
      final dt = DateTime.parse(raw.toString()).toLocal();
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      final d = dt.day.toString().padLeft(2, '0');
      final mo = dt.month.toString().padLeft(2, '0');
      return '$h:$m • $d/$mo/${dt.year}';
    } catch (_) {
      return raw.toString();
    }
  }

  String _formatTime(dynamic raw) {
    if (raw == null) return '';
    try {
      final dt = DateTime.parse(raw.toString()).toLocal();
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      return '$h:$m';
    } catch (_) {
      return '';
    }
  }

  String _formatCurrency(dynamic amount) {
    final val = (amount is num) ? amount.toInt() : (int.tryParse(amount?.toString() ?? '0') ?? 0);
    final str = val.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buffer.write('.');
      buffer.write(str[i]);
    }
    return '${buffer.toString()} đ';
  }

  @override
  Widget build(BuildContext context) {
    final task = _detail?['task'] as Map<String, dynamic>? ?? {};
    final status = task['status']?.toString() ?? '';
    final closed = {'CANCELLED', 'REFUNDED', 'EXPIRED'}.contains(status);

    final primaryColor = widget.partner ? const Color(0xFF1E5BF8) : const Color(0xFF059669);
    final tintBg = widget.partner ? const Color(0xFFEFF6FF) : const Color(0xFFECFDF5);
    final tintBorder = widget.partner ? const Color(0xFFBFDBFE) : const Color(0xFFA7F3D0);
    final onlineColor = widget.partner ? const Color(0xFF2563EB) : const Color(0xFF10B981);

    final titleName = widget.partner
        ? (task['customerName'] ?? widget.initialCustomerName ?? 'Khách hàng')
        : (task['taskerName'] ?? widget.initialTaskerName ?? 'Tasker Đối tác');
    final participantRole = widget.partner ? 'Khách hàng' : 'Tasker';
    final chatTitle = titleName == 'Khách hàng' || titleName == 'Tasker Đối tác'
        ? participantRole
        : '$participantRole • $titleName';

    final serviceName = task['serviceName'] ?? widget.initialServiceName ?? 'Công việc';

    final messages = (_detail?['messages'] as List? ?? []);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.8,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        titleSpacing: 0,
        title: InkWell(
          onTap: _showTaskInfoSheet,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
            child: Row(
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: tintBg,
                      child: Text(
                        (titleName.isNotEmpty ? titleName[0] : (widget.partner ? 'K' : 'T')).toUpperCase(),
                        style: TextStyle(
                          color: primaryColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 11,
                        height: 11,
                        decoration: BoxDecoration(
                          color: onlineColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              chatTitle,
                              style: const TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0F172A),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.verified_rounded, size: 15, color: primaryColor),
                        ],
                      ),
                      Text(
                        '$serviceName • #${widget.taskId.substring(0, min(8, widget.taskId.length)).toUpperCase()}',
                        style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Thông tin công việc',
            icon: const Icon(Icons.info_outline_rounded, color: Color(0xFF475569)),
            onPressed: _showTaskInfoSheet,
          ),
          IconButton(
            tooltip: 'Tải lại',
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF475569)),
            onPressed: () => _load(),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Banner bảo mật hoặc trạng thái kết thúc
            if (widget.completionMode && !_arrived)
              Padding(padding: const EdgeInsets.all(12), child: Column(children: [
                const Text('Chụp toàn bộ khu vực đã làm và các vị trí khách yêu cầu (2–10 ảnh).'),
                Wrap(spacing: 8, children: _completionPhotos.asMap().entries.map((entry) => InkWell(
                  onTap: null,
                  child: Image.memory(base64Decode(entry.value.split(',').last), width: 64, height: 64, fit: BoxFit.cover),
                )).toList()),
                CheckboxListTile(value: _confirmedAllAreas, onChanged: _sending ? null : (v) => setState(() => _confirmedAllAreas = v == true),
                  title: const Text('Đã chụp đủ các khu vực đã làm và khách yêu cầu')),
                Row(children: [
                  Expanded(child: OutlinedButton(onPressed: _sending || _restoringPhotos || _completionPhotos.length >= 10 ? null : _pickImage, child: Text('Chụp ảnh (${_completionPhotos.length}/10)'))),
                  Expanded(child: FilledButton(onPressed: _sending || _completionPhotos.length < 2 || !_confirmedAllAreas ? null : _send, child: const Text('Gửi & hoàn thành'))),
                ]),
              ])),
            if (widget.checkInMode && !_arrived)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                color: const Color(0xFFEFF6FF),
                child: Column(children: [
                  const Text('Bắt buộc chụp ảnh tại địa điểm. Bấm gửi ảnh hoặc “Gửi ảnh & check-in” để xác nhận đã đến và thông báo cho khách hàng.'),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: OutlinedButton.icon(
                      onPressed: _sending ? null : _pickImage,
                      icon: const Icon(Icons.camera_alt_outlined), label: const Text('Chụp ảnh'),
                    )),
                    const SizedBox(width: 8),
                    Expanded(child: FilledButton(
                      onPressed: _sending || _pickedImageData == null ? null : _send,
                      child: const Text('Gửi ảnh & check-in'),
                    )),
                  ]),
                ]),
              ),
            if (closed)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: const Color(0xFFF1F5F9),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.history_rounded, size: 15, color: Color(0xFF64748B)),
                    SizedBox(width: 6),
                    Text(
                      'Công việc đã kết thúc. Bạn có thể xem lại lịch sử tin nhắn.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                color: const Color(0xFFF8FAFC),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.lock_outline_rounded, size: 12, color: Color(0xFF94A3B8)),
                    SizedBox(width: 6),
                    Text(
                      'Tin nhắn được bảo mật phục vụ công việc trên TaskLy',
                      style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                    ),
                  ],
                ),
              ),

            // Khu vực tin nhắn
            Expanded(
              child: _loading
                  ? Center(child: CircularProgressIndicator(color: primaryColor))
                  : _error != null
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(_error!, style: const TextStyle(color: Color(0xFFDC2626))),
                              const SizedBox(height: 10),
                              FilledButton(
                                onPressed: () => _load(),
                                style: FilledButton.styleFrom(backgroundColor: primaryColor),
                                child: const Text('Thử lại'),
                              ),
                            ],
                          ),
                        )
                      : messages.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 64,
                                      height: 64,
                                      decoration: BoxDecoration(
                                        color: tintBg,
                                        shape: BoxShape.circle,
                                        border: Border.all(color: tintBorder),
                                      ),
                                      child: Icon(
                                        Icons.chat_bubble_outline_rounded,
                                        color: primaryColor,
                                        size: 28,
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    Text(
                                      widget.partner
                                          ? 'Bắt đầu trò chuyện với khách hàng'
                                          : 'Bắt đầu trò chuyện với Tasker',
                                      style: const TextStyle(
                                        fontSize: 15.5,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      widget.partner
                                          ? 'Gửi lời chào, xác nhận thời gian đến hoặc gửi ảnh hiện trường công việc.'
                                          : 'Gửi ghi chú địa chỉ, dặn dò công việc hoặc ảnh mẫu cho Tasker.',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : ListView.builder(
                              controller: _scrollController,
                              reverse: true,
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                              itemCount: messages.length,
                              findChildIndexCallback: (key) {
                                if (key is! ValueKey) return null;
                                final index = messages.indexWhere((message) => message['id'] == key.value);
                                return index < 0 ? null : messages.length - 1 - index;
                              },
                              itemBuilder: (context, index) {
                                final m = messages[messages.length - 1 - index];
                                final mine = m['mine'] == true;
                                final rawImg = (m['imageData'] ?? m['image_data'])?.toString();
                                final hasImg = rawImg != null && rawImg.isNotEmpty;
                                final imgBytes = hasImg
                                    ? (_imageCache[m['id']?.toString() ?? rawImg.hashCode.toString()] ??
                                        (rawImg.contains(',') ? base64Decode(rawImg.split(',').last) : null))
                                    : null;
                                final text = (m['text'] ?? '').toString();
                                final isPlaceholderOnly = hasImg && text == 'Ảnh đính kèm';

                                return Align(
                                  key: ValueKey(m['id']),
                                  alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                                  child: Container(
                                    constraints: BoxConstraints(
                                      maxWidth: MediaQuery.of(context).size.width * 0.76,
                                    ),
                                    margin: const EdgeInsets.only(bottom: 12),
                                    padding: EdgeInsets.fromLTRB(
                                      hasImg ? 8 : 14,
                                      hasImg ? 8 : 10,
                                      hasImg ? 8 : 14,
                                      hasImg ? 8 : 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: mine ? Colors.white : const Color(0xFF059669),
                                      borderRadius: BorderRadius.only(
                                        topLeft: const Radius.circular(18),
                                        topRight: const Radius.circular(18),
                                        bottomLeft: Radius.circular(mine ? 18 : 4),
                                        bottomRight: Radius.circular(mine ? 4 : 18),
                                      ),
                                      border: Border.all(
                                        color: mine ? const Color(0xFFE2E8F0) : const Color(0xFF047857),
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.03),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                      children: [
                                        // Hiển thị ảnh nếu có
                                        if (hasImg && imgBytes != null && imgBytes.isNotEmpty) ...[
                                          GestureDetector(
                                            onTap: () => _openImageZoom(imgBytes),
                                            child: ClipRRect(
                                              borderRadius: BorderRadius.circular(12),
                                              child: Stack(
                                                alignment: Alignment.bottomRight,
                                                children: [
                                                  Image.memory(
                                                    imgBytes,
                                                    width: 240,
                                                    height: 180,
                                                    fit: BoxFit.cover,
                                                    gaplessPlayback: true,
                                                  ),
                                                  Container(
                                                    margin: const EdgeInsets.all(6),
                                                    padding: const EdgeInsets.all(4),
                                                    decoration: BoxDecoration(
                                                      color: Colors.black54,
                                                      borderRadius: BorderRadius.circular(6),
                                                    ),
                                                    child: const Icon(
                                                      Icons.zoom_in_rounded,
                                                      color: Colors.white,
                                                      size: 16,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          if (!isPlaceholderOnly && text.isNotEmpty)
                                            const SizedBox(height: 8),
                                        ],

                                        // Hiển thị văn bản
                                        if (!isPlaceholderOnly && text.isNotEmpty)
                                          Padding(
                                            padding: hasImg
                                                ? const EdgeInsets.symmetric(horizontal: 4)
                                                : EdgeInsets.zero,
                                            child: Text(
                                              text,
                                              style: TextStyle(
                                                fontSize: 14,
                                                height: 1.35,
                                                color: mine ? const Color(0xFF0F172A) : Colors.white,
                                              ),
                                            ),
                                          ),

                                        const SizedBox(height: 4),

                                        // Timestamp
                                        Padding(
                                          padding: hasImg
                                              ? const EdgeInsets.symmetric(horizontal: 4)
                                              : EdgeInsets.zero,
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                _formatTime(m['at']),
                                                style: TextStyle(
                                                  fontSize: 10.5,
                                                  color: mine
                                                      ? const Color(0xFF94A3B8)
                                                      : Colors.white.withOpacity(0.85),
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                              if (mine) ...[
                                                const SizedBox(width: 4),
                                                Icon(
                                                  Icons.done_all_rounded,
                                                  size: 13,
                                                  color: const Color(0xFF94A3B8),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
            ),

            // Gợi ý tin nhắn nhanh (Quick chips)
            if (!closed)
              Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    if (widget.partner) ...[
                      _quickChip('🛵 Đang trên đường đến', () {
                        _input.text = 'Tôi đang trên đường di chuyển đến địa chỉ công việc.';
                      }),
                      _quickChip('📍 Đã tới nơi', () {
                        _input.text = 'Tôi đã có mặt tại địa chỉ công việc.';
                      }),
                      _quickChip('📷 Gửi ảnh hiện trường', _pickImage),
                      _quickChip('✅ Đã xong công việc', () {
                        _input.text = 'Tôi đã hoàn thành công việc, mời bạn kiểm tra và nghiệm thu nhé!';
                      }),
                    ] else ...[
                      _quickChip('📍 Xác nhận địa chỉ', () {
                        final addr = task['address'] ?? '';
                        _input.text = 'Địa chỉ công việc: $addr';
                      }),
                      _quickChip('📞 Đến nơi hãy gọi tôi', () {
                        _input.text = 'Khi nào đến nơi bạn vui lòng gọi điện cho tôi nhé!';
                      }),
                      _quickChip('📷 Gửi hình ảnh mô tả', _pickImage),
                      _quickChip('🙏 Cảm ơn bạn', () {
                        _input.text = 'Cảm ơn bạn rất nhiều!';
                      }),
                    ],
                  ],
                ),
              ),

            // Preview ảnh đã chọn trước khi gửi
            if (_pickedImageData != null)
              Container(
                margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: tintBorder),
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withOpacity(0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.memory(
                        base64Decode(_pickedImageData!.split(',').last),
                        width: 52,
                        height: 52,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Ảnh đã đính kèm',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Nhấn nút gửi để chia sẻ ảnh cho đối phương',
                            style: TextStyle(color: Color(0xFF64748B), fontSize: 11.5),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Color(0xFFEF4444)),
                      onPressed: () => setState(() => _pickedImageData = null),
                      tooltip: 'Hủy ảnh',
                    ),
                  ],
                ),
              ),

            // Input Bar
            if (!closed)
              Container(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Nút đính kèm ảnh
                    IconButton(
                      icon: Icon(
                        Icons.photo_library_outlined,
                        color: primaryColor,
                        size: 24,
                      ),
                      tooltip: 'Gửi hình ảnh',
                      onPressed: _sending ? null : _pickImage,
                    ),

                    // Ô nhập tin nhắn
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: TextField(
                          controller: _input,
                          minLines: 1,
                          maxLines: 4,
                          enabled: !_sending,
                          style: const TextStyle(fontSize: 14),
                          decoration: InputDecoration(
                            hintText: widget.partner
                                ? 'Nhắn tin cho khách hàng...'
                                : 'Nhắn tin cho Tasker...',
                            hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13.5),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Nút gửi
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: primaryColor,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: _sending
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                        onPressed: _sending ? null : _send,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _quickChip(String text, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        label: Text(text, style: const TextStyle(fontSize: 11.5, color: Color(0xFF334155))),
        backgroundColor: Colors.white,
        side: const BorderSide(color: Color(0xFFE2E8F0)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
        onPressed: onTap,
      ),
    );
  }
}
