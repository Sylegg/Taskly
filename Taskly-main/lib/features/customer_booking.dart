import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'dart:async';

import '../app/customer_controller.dart';
import '../data/api_customer_repository.dart';
import 'customer_view.dart' show CustomerAddressDialog;
import '../core/theme.dart';
import '../domain/booking_draft.dart';
import '../domain/models.dart';
import '../shared/widgets.dart';
import '../shared/service_symbol.dart';

/// Customer V3 booking backed by authenticated, durable server drafts.
class CustomerBooking extends StatefulWidget {
  const CustomerBooking({super.key, required this.controller});
  final CustomerController controller;
  @override
  State<CustomerBooking> createState() => _CustomerBookingState();
}

class _CustomerBookingState extends State<CustomerBooking> {
  CustomerController get c => widget.controller;
  CustomerBookingDrafts get repository => c.repository as CustomerBookingDrafts;
  CustomerBookingDraft? draft;
  List<BookingSchema> schemas = [];
  int step = 0;
  bool loading = true, saving = false;
  String? error;
  CustomerQuote? quote;
  bool _hasQuoted = false;
  Timer? quoteTimer;
  Timer? scheduleTimer;

  DateTime earliestSchedule() {
    final now = DateTime.now();
    final minute = DateTime(now.year, now.month, now.day, now.hour, now.minute);
    return minute.isBefore(now)
        ? minute.add(const Duration(minutes: 1))
        : minute;
  }

  DateTime validSchedule(DateTime value) {
    final earliest = earliestSchedule();
    return value.isBefore(earliest) ? earliest : value;
  }

  static const steps = [
    'Dịch vụ',
    'Yêu cầu',
    'Lịch hẹn',
    'Địa chỉ',
    'Kiểm tra',
  ];
  String searchQuery = '';
  Service? get service =>
      selectedServices.firstOrNull ??
      c.data!.services.where((s) => s.id == draft?.serviceId).firstOrNull;
  List<Service> get selectedServices {
    if (draft == null || c.data == null) return [];
    return draft!.selectedServiceIds
        .map((id) => c.data!.services.where((s) => s.id == id).firstOrNull)
        .whereType<Service>()
        .toList();
  }

  BookingSchema? get schema =>
      schemas.where((s) => s.serviceSlugs.contains(service?.slug)).firstOrNull;

  final Set<String> expandedServiceIds = {};

  void toggleExpandedService(String id) {
    HapticFeedback.selectionClick();
    setState(() {
      if (expandedServiceIds.contains(id)) {
        expandedServiceIds.remove(id);
      } else {
        expandedServiceIds.add(id);
      }
    });
  }

  bool _isServiceFilled(Service s, BookingSchema? sch, CustomerBookingDraft d) {
    final desc =
        (d.details['service_desc_${s.id}'] ??
                (s.id == d.serviceId ? d.description : ''))
            ?.toString()
            .trim();
    final hasDesc = desc != null && desc.isNotEmpty;

    if (sch == null) {
      return hasDesc;
    }
    if (s.id == d.serviceId) {
      if (sch.fields.isEmpty) return hasDesc;
      return sch.fields.every((f) {
        if (!f.required) return true;
        final val = d.details[f.key];
        return val != null && val.toString().trim().isNotEmpty;
      });
    } else {
      final hasSpecificField = sch.fields.any((f) {
        final val = d.details['${s.id}_${f.key}'];
        return val != null && val.toString().trim().isNotEmpty;
      });
      return hasSpecificField || hasDesc;
    }
  }

  Widget? _fieldIcon(BookingField f) {
    final k = f.key.toLowerCase();
    if (k.contains('area'))
      return const Icon(
        Icons.square_foot_rounded,
        size: 20,
        color: Color(0xFF059669),
      );
    if (k.contains('room'))
      return const Icon(
        Icons.meeting_room_outlined,
        size: 20,
        color: Color(0xFF059669),
      );
    if (k.contains('bath'))
      return const Icon(
        Icons.bathtub_outlined,
        size: 20,
        color: Color(0xFF059669),
      );
    if (k.contains('unit') ||
        k.contains('item') ||
        k.contains('count') ||
        k.contains('box') ||
        k.contains('weight')) {
      return const Icon(
        Icons.format_list_numbered_rounded,
        size: 20,
        color: Color(0xFF059669),
      );
    }
    if (k.contains('supplies') ||
        k.contains('device') ||
        k.contains('material')) {
      return const Icon(
        Icons.build_circle_outlined,
        size: 20,
        color: Color(0xFF059669),
      );
    }
    if (k.contains('access') || k.contains('pickup') || k.contains('dropoff')) {
      return const Icon(
        Icons.location_on_outlined,
        size: 20,
        color: Color(0xFF059669),
      );
    }
    if (k.contains('budget'))
      return const Icon(
        Icons.payments_outlined,
        size: 20,
        color: Color(0xFF059669),
      );
    if (f.type == 'choice')
      return const Icon(Icons.tune_rounded, size: 20, color: Color(0xFF059669));
    return const Icon(
      Icons.edit_note_rounded,
      size: 20,
      color: Color(0xFF059669),
    );
  }

  Widget _buildFormField(
    BookingField f,
    String keyPrefix,
    CustomerBookingDraft d,
  ) {
    final fieldKey = '$keyPrefix${f.key}';
    final fieldError = _showServiceErrors
        ? _fieldError(f, d.details[fieldKey])
        : null;
    final anchor = _fieldAnchors.putIfAbsent(fieldKey, () => GlobalKey());
    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
    );
    final focusedBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFF059669), width: 1.5),
    );

    if (f.type == 'choice') {
      return DropdownButtonFormField<String>(
        key: anchor,
        isExpanded: true,
        initialValue: f.options.contains(d.details[fieldKey])
            ? d.details[fieldKey]
            : null,
        decoration: InputDecoration(
          errorText: fieldError,
          errorMaxLines: 3,
          labelText: f.label,
          prefixIcon: _fieldIcon(f),
          filled: true,
          fillColor: const Color(0xFFF8FAFC),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
          border: inputBorder,
          enabledBorder: inputBorder,
          focusedBorder: focusedBorder,
        ),
        items: f.options
            .map(
              (v) => DropdownMenuItem(
                value: v,
                child: Text(v, style: const TextStyle(fontSize: 14)),
              ),
            )
            .toList(),
        onChanged: (v) => edit(() => d.details[fieldKey] = v),
      );
    }

    return TextFormField(
      key: anchor,
      initialValue: d.details[fieldKey]?.toString() ?? '',
      decoration: InputDecoration(
        errorText: fieldError,
        errorMaxLines: 3,
        labelText: f.label,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        labelStyle: const TextStyle(
          fontSize: 13,
          color: Color(0xFF64748B),
          fontWeight: FontWeight.w600,
        ),
        floatingLabelStyle: const TextStyle(
          fontSize: 13,
          color: Color(0xFF059669),
          fontWeight: FontWeight.w700,
        ),
        prefixIcon: _fieldIcon(f),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: inputBorder,
        enabledBorder: inputBorder,
        focusedBorder: focusedBorder,
      ),
      maxLength: f.type == 'number' ? 9 : 2000,
      inputFormatters: f.type == 'number'
          ? [FilteringTextInputFormatter.digitsOnly]
          : null,
      keyboardType: f.type == 'number'
          ? TextInputType.number
          : TextInputType.text,
      onChanged: (v) => edit(() => d.details[fieldKey] = v),
    );
  }

  void _updateServiceDescription(
    Service s,
    String text,
    CustomerBookingDraft d,
  ) {
    edit(() {
      d.details['service_desc_${s.id}'] = text;
      if (selectedServices.length <= 1) {
        d.description = text;
      } else {
        final parts = <String>[];
        for (final item in selectedServices) {
          final val =
              (d.details['service_desc_${item.id}'] ??
                      (item.id == d.serviceId ? d.description : ''))
                  ?.toString()
                  .trim();
          if (val != null && val.isNotEmpty) {
            parts.add('${item.name}: $val');
          }
        }
        d.description = parts.join('\n');
      }
    });
  }

  Widget _buildServiceDescriptionField(Service s, CustomerBookingDraft d) {
    final key = 'service_desc_${s.id}';
    String initial = d.details[key]?.toString() ?? '';
    if (initial.isEmpty &&
        selectedServices.length <= 1 &&
        s.id == d.serviceId) {
      initial = d.description;
    }

    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: TextFormField(
        key: ValueKey('desc-${s.id}'),
        initialValue: initial,
        maxLines: 3,
        maxLength: 2000,
        decoration: InputDecoration(
          labelText: 'Mô tả bổ sung cho ${s.name}',
          floatingLabelBehavior: FloatingLabelBehavior.always,
          labelStyle: const TextStyle(
            fontSize: 13,
            color: Color(0xFF64748B),
            fontWeight: FontWeight.w600,
          ),
          floatingLabelStyle: const TextStyle(
            fontSize: 13,
            color: Color(0xFF059669),
            fontWeight: FontWeight.w700,
          ),
          hintText: 'Nhập ghi chú hoặc yêu cầu cụ thể cho ${s.name}...',
          prefixIcon: const Icon(
            Icons.description_outlined,
            size: 20,
            color: Color(0xFF059669),
          ),
          filled: true,
          fillColor: const Color(0xFFF8FAFC),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF059669), width: 1.5),
          ),
        ),
        onChanged: (v) => _updateServiceDescription(s, v, d),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    c.addListener(_catalogueChanged);
    _refreshWorkAreas();
    scheduleTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && draft != null) {
        setState(() {});
      }
    });
    load();
  }

  bool _refreshingSchemas = false;
  Future<void> _catalogueChanged() async {
    if (!mounted || loading || _refreshingSchemas) return;
    _refreshingSchemas = true;
    try {
      final next = await repository.bookingSchemas();
      if (mounted) setState(() => schemas = next);
    } catch (_) {
      /* Keep the current form and typed values while offline. */
    } finally {
      _refreshingSchemas = false;
    }
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final loadedSchemas = await repository.bookingSchemas();
      if (!mounted) return;
      schemas = loadedSchemas;
      final resumeBooking =
          c.route.extra == 'resume-booking' ||
          (c.route.extra?.startsWith('resume-booking:') ?? false);
      CustomerBookingDraft? restored;
      if (repository is CustomerPendingBookings) {
        final pending = await (repository as CustomerPendingBookings)
            .pendingBookings();
        if (!mounted) return;
        if (resumeBooking) {
          final id = c.route.extra!.replaceFirst('resume-booking:', '');
          restored =
              pending.where((item) => item.pendingId == id).firstOrNull ??
              pending.firstOrNull;
          if (restored == null) {
            restored = await repository.restoreBookingDraft();
          }
        } else if (pending.isNotEmpty) {
          final choice = await showDialog<String>(
            context: context,
            barrierDismissible: false,
            builder: (dialogContext) {
              final firstPending = pending.firstOrNull;
              final firstServiceName = firstPending != null
                  ? c.data?.services
                            .where((s) => s.id == firstPending.serviceId)
                            .firstOrNull
                            ?.name ??
                        'Đơn dịch vụ'
                  : 'Đơn dịch vụ';

              return Dialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                backgroundColor: Colors.white,
                elevation: 8,
                insetPadding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 24,
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 24, 22, 18),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 1. Icon Badge Header
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: const Color(0xFFECFDF5),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFFA7F3D0),
                                width: 1.5,
                              ),
                            ),
                            child: const Icon(
                              Icons.pending_actions_rounded,
                              size: 30,
                              color: Color(0xFF059669),
                            ),
                          ),
                          Positioned(
                            right: 0,
                            top: 0,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF059669),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: Colors.white,
                                  width: 1.5,
                                ),
                              ),
                              child: Text(
                                '${pending.length}/3',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // 2. Tiêu đề
                      const Text(
                        'Bạn đang có đơn chưa hoàn thành',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // 3. Mô tả
                      Text(
                        pending.length == 1
                            ? 'Bạn đang có 1 đơn đặt dịch vụ lưu tạm. Bạn muốn sửa đơn đang có hay tạo thêm mới? (Tối đa 3 đơn chưa hoàn thành).'
                            : 'Bạn đang có ${pending.length} đơn đặt dịch vụ lưu tạm. Bạn muốn sửa đơn đang có hay tạo thêm mới? (Tối đa 3 đơn chưa hoàn thành).',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF64748B),
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 4. Thẻ thông tin đơn dịch vụ đang lưu tạm
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: const Color(0xFFBFDBFE),
                                ),
                              ),
                              child: const Icon(
                                Icons.assignment_outlined,
                                size: 20,
                                color: Color(0xFF2563EB),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    pending.length == 1
                                        ? firstServiceName
                                        : '${pending.length} đơn dịch vụ chưa hoàn tất',
                                    style: const TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF1E293B),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    pending.length == 1
                                        ? (firstPending?.scheduledAt != null
                                              ? 'Lịch hẹn: ${firstPending!.scheduledAt!.day}/${firstPending.scheduledAt!.month}/${firstPending.scheduledAt!.year}'
                                              : 'Bản nháp lưu tạm • Chưa hoàn tất')
                                        : 'Chọn đơn bạn muốn tiếp tục xử lý',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFFBEB),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: const Color(0xFFFDE68A),
                                ),
                              ),
                              child: const Text(
                                'Lưu tạm',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFD97706),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // 5. Nút chính: Sửa đơn đang có
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: () => Navigator.pop(dialogContext, 'edit'),
                          icon: const Icon(Icons.edit_note_rounded, size: 20),
                          label: Text(
                            pending.length == 1
                                ? 'Sửa đơn đang có'
                                : 'Chọn đơn để sửa (${pending.length})',
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF059669),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),

                      // 6. Nút phụ: Tạo thêm (nếu pending < 3)
                      if (pending.length < 3) ...[
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          height: 46,
                          child: OutlinedButton.icon(
                            onPressed: () =>
                                Navigator.pop(dialogContext, 'new'),
                            icon: const Icon(
                              Icons.add_circle_outline_rounded,
                              size: 19,
                              color: Color(0xFF059669),
                            ),
                            label: Text(
                              'Tạo thêm (${pending.length}/3)',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF059669),
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(
                                color: Color(0xFF059669),
                                width: 1.4,
                              ),
                              backgroundColor: const Color(0xFFF0FDF4),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),
                      ],

                      // 7. Nút Hủy
                      const SizedBox(height: 6),
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext, 'cancel'),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF64748B),
                        ),
                        child: const Text(
                          'Hủy',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
          if (!mounted) return;
          if (choice == 'cancel' || choice == null) {
            c.back();
            return;
          }
          if (choice == 'edit') {
            restored = pending.length == 1
                ? pending.first
                : await showDialog<CustomerBookingDraft>(
                    context: context,
                    builder: (dialogContext) => Dialog(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      backgroundColor: Colors.white,
                      insetPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 24,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.checklist_rounded,
                                  color: Color(0xFF059669),
                                  size: 24,
                                ),
                                const SizedBox(width: 10),
                                const Expanded(
                                  child: Text(
                                    'Chọn đơn cần sửa',
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                ),
                                IconButton(
                                  onPressed: () =>
                                      Navigator.pop(dialogContext, null),
                                  icon: const Icon(
                                    Icons.close,
                                    size: 20,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Flexible(
                              child: ListView.separated(
                                shrinkWrap: true,
                                itemCount: pending.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 10),
                                itemBuilder: (context, index) {
                                  final item = pending[index];
                                  final serviceName =
                                      c.data!.services
                                          .where((s) => s.id == item.serviceId)
                                          .firstOrNull
                                          ?.name ??
                                      'Đơn đặt dịch vụ';
                                  return InkWell(
                                    borderRadius: BorderRadius.circular(14),
                                    onTap: () =>
                                        Navigator.pop(dialogContext, item),
                                    child: Container(
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF8FAFC),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: const Color(0xFFE2E8F0),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 36,
                                            height: 36,
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFECFDF5),
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            child: const Icon(
                                              Icons.edit_note_rounded,
                                              size: 20,
                                              color: Color(0xFF059669),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  serviceName,
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w700,
                                                    color: Color(0xFF0F172A),
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  item.scheduledAt != null
                                                      ? 'Lịch hẹn: ${item.scheduledAt!.day}/${item.scheduledAt!.month}/${item.scheduledAt!.year}'
                                                      : 'Bản nháp lưu tạm',
                                                  style: const TextStyle(
                                                    fontSize: 11.5,
                                                    color: Color(0xFF64748B),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const Icon(
                                            Icons.chevron_right_rounded,
                                            color: Color(0xFF94A3B8),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
            if (!mounted) return;
            if (restored == null) {
              c.back();
              return;
            }
          }
        } else {
          restored = await repository.restoreBookingDraft();
        }
      } else {
        restored = await repository.restoreBookingDraft();
      }
      draft =
          restored ??
          CustomerBookingDraft(
            serviceId: c.draft?.serviceId ?? '',
            addressId: c.draft?.address.id ?? '',
            scheduledAt: c.draft?.scheduledAt,
          );
      if (restored != null && resumeBooking) {
        if (draft!.scheduledAt == null ||
            !draft!.scheduledAt!.isAfter(DateTime.now())) {
          step = 2;
          error = 'Giờ hẹn đã qua hoặc chưa được chọn. Vui lòng sửa giờ hẹn từ thời điểm hiện tại trở đi để đặt tiếp.';
        } else {
          step = 4;
        }
      } else if (!resumeBooking && c.route.extra != null) {
        select(c.route.extra!);
      }
      draft!.schemaKey = schema?.key ?? '';
      draft!.schemaVersion = schema?.version ?? 1;
    } catch (e) {
      if (mounted) {
        error = e is RepositoryFailure
            ? e.message
            : 'Không thể tải thông tin đặt dịch vụ. Vui lòng thử lại.';
      }
    }
    if (mounted) setState(() => loading = false);
  }

  void select(String id) {
    draft!.selectedServiceIds = [id];
    draft!.serviceId = id;
    draft!.details.clear();
    draft!.details['selectedServiceIds'] = [id];
    draft!.schemaKey = schema?.key ?? '';
    draft!.schemaVersion = schema?.version ?? 1;

    quote = null;
    quoteTimer?.cancel();
  }

  void toggleService(String id) {
    if (c.bookingLimitReached) {
      c.showBookingLimit();
      return;
    }
    if (draft == null) return;
    final current = List<String>.from(draft!.selectedServiceIds);
    if (current.contains(id)) {
      current.remove(id);
    } else {
      if (current.length >= 3) {
        HapticFeedback.mediumImpact();
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.info_outline_rounded, color: Colors.white, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Bạn chỉ có thể chọn tối đa 3 dịch vụ cùng lúc.',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFFD97706),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
        return;
      }
      current.add(id);
    }

    HapticFeedback.selectionClick();
    edit(() {
      draft!.selectedServiceIds = current;
      draft!.schemaKey = schema?.key ?? '';
      draft!.schemaVersion = schema?.version ?? 1;
    });
  }

  Future<void> confirmRemoveService(Service service) async {
    if (saving) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xóa dịch vụ?'),
        content: Text(
          'Bạn có muốn xóa dịch vụ “${service.name}” khỏi đơn đặt này không?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) removeSelectedService(service.id);
  }

  void removeSelectedService(String id) {
    final d = draft;
    if (d == null || saving) return;
    final ids = List<String>.from(d.selectedServiceIds)..remove(id);
    edit(() {
      if (id == d.serviceId) {
        // Move the next service's fields into the primary service namespace.
        final oldSchema = schema;
        for (final field in oldSchema?.fields ?? <BookingField>[]) {
          d.details.remove(field.key);
        }
        if (ids.isNotEmpty) {
          final next = c.data!.services.firstWhere((s) => s.id == ids.first);
          final nextSchema = schemas
              .where((s) => s.serviceSlugs.contains(next.slug))
              .firstOrNull;
          for (final field in nextSchema?.fields ?? <BookingField>[]) {
            final value = d.details.remove('${next.id}_${field.key}');
            if (value != null) d.details[field.key] = value;
          }
          d.description = (d.details['service_desc_${next.id}'] ?? '')
              .toString();
        } else {
          d.description = '';
        }
      }
      d.details.removeWhere((key, _) => key.startsWith('${id}_'));
      d.details.remove('service_desc_$id');
      d.selectedServiceIds = ids;
      d.schemaKey = schema?.key ?? '';
      d.schemaVersion = schema?.version ?? 1;
      expandedServiceIds.remove(id);
      if (ids.isEmpty) step = 0;
    });
  }

  void edit(VoidCallback change) => setState(() {
    change();

    error = null;
    quote = null;
    quoteTimer?.cancel();
  });
  @override
  void dispose() {
    c.removeListener(_catalogueChanged);
    scheduleTimer?.cancel();
    quoteTimer?.cancel();
    super.dispose();
  }

  bool _showServiceErrors = false;
  final Map<String, GlobalKey> _fieldAnchors = {};
  String? _fieldError(BookingField field, dynamic value) {
    if (value == null || value.toString().trim().isEmpty)
      return field.required
          ? 'Vui lòng nhập ${field.label.toLowerCase()}.'
          : null;
    if (field.type == 'number') {
      final number = int.tryParse(value.toString());
      if (number == null || number < (field.minimum ?? 0) || number > 100000000)
        return '${field.label} cần là số nguyên từ ${field.minimum ?? 0} đến 100000000.';
    }
    if (field.type == 'choice' && !field.options.contains(value))
      return 'Vui lòng chọn ${field.label.toLowerCase()} hợp lệ.';
    return null;
  }

  String? validateServiceDetails() {
    _showServiceErrors = true;
    String? firstMessage, firstKey;
    for (final service in selectedServices) {
      final sch = schemas
          .where((s) => s.serviceSlugs.contains(service.slug))
          .firstOrNull;
      if (sch == null) {
        firstMessage ??= '${service.name}: Dịch vụ chưa có biểu mẫu yêu cầu.';
        continue;
      }
      final prefix = service.id == draft!.serviceId ? '' : '${service.id}_';
      for (final field in sch.fields) {
        final key = '$prefix${field.key}';
        final message = _fieldError(field, draft!.details[key]);
        if (message != null) {
          expandedServiceIds.add(service.id);
          firstMessage ??= '${service.name}: $message';
          firstKey ??= key;
        }
      }
    }
    if (firstKey != null)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final target = _fieldAnchors[firstKey]?.currentContext;
        if (mounted && target != null)
          Scrollable.ensureVisible(
            target,
            duration: const Duration(milliseconds: 300),
            alignment: 0.15,
          );
      });
    return firstMessage;
  }

  Future<void> confirmQuote() async {
    if (saving || quote == null || c.repository is! ApiCustomerRepository)
      return;
    if (!quote!.expiresAt.isAfter(DateTime.now())) {
      setState(() => error = 'Báo giá đã hết hạn. Vui lòng lấy báo giá mới.');
      return;
    }
    final repo = c.repository as ApiCustomerRepository;
    int balance;
    setState(() => saving = true);
    try {
      final result = await repo.session.request('/users/me/refund-balance');
      balance = (result['amount'] as num).toInt();
      repo.refundBalance = balance;
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
      return;
    } finally {
      if (mounted) setState(() => saving = false);
    }
    if (!mounted) return;
    String selected = 'CASH';
    bool useBalance = false;
    final balanceToUse = balance < quote!.total ? balance : quote!.total;
    final method = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, update) => SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Xác nhận giá và thanh toán',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Text('Tổng tiền: ${quote!.total} đ'),
                  RadioListTile<String>(
                    title: const Text('Thanh toán trực tiếp'),
                    subtitle: const Text(
                      'Trả tiền sau khi làm xong. Partner xác nhận đã nhận tiền.',
                    ),
                    value: 'CASH',
                    groupValue: selected,
                    onChanged: (v) => update(() => selected = v!),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Sử dụng số dư tài khoản'),
                    subtitle: Text('Số dư khả dụng: $balance đ'),
                    value: useBalance,
                    onChanged: balanceToUse > 0
                        ? (value) => update(() => useBalance = value)
                        : null,
                  ),
                  if (useBalance) ...[
                    Text('Trừ từ số dư: $balanceToUse đ'),
                    Text('Số dư còn lại: ${balance - balanceToUse} đ'),
                  ],
                  Text(
                    'Còn phải trả: ${quote!.total - (useBalance ? balanceToUse : 0)} đ',
                  ),
                  RadioListTile<String>(
                    title: const Text('Ngân hàng (giả lập)'),
                    subtitle: const Text(
                      'Bấm nút để giả lập thanh toán thành công.',
                    ),
                    value: 'BANK',
                    groupValue: selected,
                    onChanged: (v) => update(() => selected = v!),
                  ),
                  const Text(
                    'Đơn sẽ tìm Partner trong 1 tiếng. Nếu không có người nhận, đơn tự hủy và tiền đã thanh toán được hoàn vào số dư trong app. Bạn có thể hủy sau 15 phút, trước khi công việc bắt đầu.',
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(ctx, selected),
                      child: Text(
                        selected == 'BANK'
                            ? 'Thanh toán giả lập và đăng đơn'
                            : 'Xác nhận và tìm Partner',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    if (method == null || !mounted) return;
    setState(() => saving = true);
    try {
      await (c.repository as ApiCustomerRepository).session.request(
        '/users/me/booking-checkout',
        method: 'POST',
        body: {
          'quoteId': quote!.id,
          'method': method,
          'balanceAmount': useBalance ? balanceToUse : 0,
        },
      );
      await c.refresh();
      if (!mounted) return;
      c.root(PageId.tasks);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> requestQuote() async {
    if (saving) return;
    if (draft?.scheduledAt == null ||
        !draft!.scheduledAt!.isAfter(DateTime.now())) {
      edit(() {
        step = 2;
      });
      setState(() {
        error = 'Giờ hẹn đã qua hoặc chưa được chọn. Vui lòng sửa giờ hẹn từ thời điểm hiện tại trở đi để đặt tiếp.';
      });
      return;
    }
    final validation = validateServiceDetails();
    if (validation != null) {
      setState(() {
        step = 1;
        error = validation;
      });
      return;
    }
    setState(() {
      saving = true;
      error = null;
      quote = null;
    });
    try {
      await repository.saveBookingDraft(draft!);
      final result = await repository.requestBookingQuote(draft!);
      if (!mounted) return;
      quote = result;
      _hasQuoted = true;
      quoteTimer?.cancel();
      quoteTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } catch (e) {
      if (mounted) {
        error = e is RepositoryFailure
            ? e.message
            : 'Không thể lấy báo giá. Vui lòng thử lại.';
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> editBookingAddress(Address? address) async {
    final result = await showDialog<Address>(
      context: context,
      builder: (_) => CustomerAddressDialog(
        address: address,
        session: c.repository is ApiCustomerRepository
            ? (c.repository as ApiCustomerRepository).session
            : null,
        isApi: !c.demoMode,
        onSave: c.saveAddress,
        saveError: () => c.error,
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      saving = false;
      {
        final matches = c.data!.addresses.where(
          (a) => result.id.isNotEmpty
              ? a.id == result.id
              : a.label == result.label &&
                    a.detail == result.detail &&
                    a.city == result.city,
        );
        if (matches.isNotEmpty) draft!.addressId = matches.last.id;
        error = null;
        quote = null;
      }
    });
  }

  Future<void> _showAddressPickerSheet(BuildContext context) async {
    final d = draft;
    if (d == null || c.data == null) return;
    final addresses = c.data!.addresses;
    if (addresses.isEmpty) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(sheetContext).size.height * 0.75,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Row(
                        children: [
                          Icon(
                            Icons.location_on_rounded,
                            color: Color(0xFF059669),
                            size: 22,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Chọn địa chỉ dịch vụ',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0F172A),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Color(0xFF64748B),
                      ),
                      tooltip: 'Đóng',
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.all(20),
                  itemCount: addresses.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final a = addresses[index];
                    final isSelected = d.addressId == a.id;
                    final fullAddress = [
                      a.detail,
                      if (a.ward.isNotEmpty) a.ward,
                      if (a.district.isNotEmpty) a.district,
                      if (a.city.isNotEmpty) a.city,
                    ].where((s) => s.trim().isNotEmpty).join(', ');

                    return InkWell(
                      onTap: () {
                        edit(() => d.addressId = a.id);
                        Navigator.of(sheetContext).pop();
                      },
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFFF0FDF4)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF059669)
                                : const Color(0xFFE2E8F0),
                            width: isSelected ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              isSelected
                                  ? Icons.check_circle_rounded
                                  : Icons.radio_button_unchecked_rounded,
                              color: isSelected
                                  ? const Color(0xFF059669)
                                  : const Color(0xFF94A3B8),
                              size: 22,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Wrap(
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    spacing: 6,
                                    runSpacing: 4,
                                    children: [
                                      Text(
                                        a.label,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15,
                                          color: isSelected
                                              ? const Color(0xFF059669)
                                              : const Color(0xFF0F172A),
                                        ),
                                      ),
                                      if (a.isDefault)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFDCFCE7),
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                          child: const Text(
                                            'Mặc định',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF15803D),
                                            ),
                                          ),
                                        ),
                                      if (a.buildingType.isNotEmpty)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF1F5F9),
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                          child: Text(
                                            'Loại: ${a.buildingType}',
                                            style: const TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF475569),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    fullAddress.isNotEmpty
                                        ? fullAddress
                                        : a.detail,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF334155),
                                    ),
                                  ),
                                  if (a.contactName.isNotEmpty ||
                                      a.contactPhone.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      '${a.contactName.isNotEmpty ? a.contactName : ''}${a.contactName.isNotEmpty && a.contactPhone.isNotEmpty ? ' • ' : ''}${a.contactPhone}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.edit_outlined,
                                size: 20,
                                color: Color(0xFF64748B),
                              ),
                              tooltip: 'Sửa địa chỉ',
                              onPressed: () async {
                                Navigator.of(sheetContext).pop();
                                await editBookingAddress(a);
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      Navigator.of(sheetContext).pop();
                      await editBookingAddress(null);
                    },
                    icon: const Icon(
                      Icons.add_location_alt_outlined,
                      color: Color(0xFF059669),
                    ),
                    label: const Text(
                      'Thêm địa chỉ mới',
                      style: TextStyle(
                        color: Color(0xFF059669),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF059669)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showEditServicesSheet(BuildContext context) async {
    final d = draft;
    if (d == null || c.data == null) return;
    final allServices = c.data!.services;
    final previousIds = List<String>.from(d.selectedServiceIds);
    final previousPrimary = d.serviceId;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final selectedIds = d.selectedServiceIds;
            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(sheetContext).size.height * 0.85,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(7),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFECFDF5),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.cleaning_services_rounded,
                                  color: Color(0xFF059669),
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Thêm dịch vụ',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                    Text(
                                      'Đã chọn ${selectedIds.length}/3 dịch vụ',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(sheetContext).pop(),
                          icon: const Icon(
                            Icons.close_rounded,
                            color: Color(0xFF64748B),
                          ),
                          tooltip: 'Đóng',
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFFE2E8F0)),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.all(20),
                      itemCount: allServices.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final s = allServices[index];
                        final isSelected = selectedIds.contains(s.id);
                        final locked = previousIds.contains(s.id);
                        final orderIdx = selectedIds.indexOf(s.id) + 1;

                        return InkWell(
                          onTap: () {
                            if (isSelected && selectedIds.length <= 1) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Cần chọn ít nhất 1 dịch vụ.'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                              return;
                            }
                            if (locked) return;
                            toggleService(s.id);
                            setModalState(() {});
                          },
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFFF0FDF4)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xFF059669)
                                    : const Color(0xFFE2E8F0),
                                width: isSelected ? 1.5 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isSelected
                                      ? Icons.check_box_rounded
                                      : Icons.check_box_outline_blank_rounded,
                                  color: isSelected
                                      ? const Color(0xFF059669)
                                      : const Color(0xFF94A3B8),
                                  size: 22,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (locked)
                                        const Padding(
                                          padding: EdgeInsets.only(bottom: 4),
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.lock_outline,
                                                size: 13,
                                                color: Color(0xFF64748B),
                                              ),
                                              SizedBox(width: 4),
                                              Text(
                                                'Đã chọn trước đó • Đã khóa',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Color(0xFF64748B),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      Row(
                                        children: [
                                          if (isSelected) ...[
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 5,
                                                    vertical: 1.5,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF10B981),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                '#$orderIdx',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 9.5,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                          ],
                                          Expanded(
                                            child: Text(
                                              s.name,
                                              style: TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 14.5,
                                                color: isSelected
                                                    ? const Color(0xFF065F46)
                                                    : const Color(0xFF0F172A),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (s.subtitle.isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          s.subtitle,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF64748B),
                                          ),
                                        ),
                                      ],
                                      if (s.hourlyRate > 0) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          'Từ ${money(s.hourlyRate)}${s.priceUnit}',
                                          style: const TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF059669),
                                          ),
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
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(sheetContext).pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF059669),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Xong',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    if (!mounted) return;
    final added = d.selectedServiceIds
        .where((id) => !previousIds.contains(id))
        .toList();
    if (added.isNotEmpty || d.serviceId != previousPrimary) {
      edit(() {
        expandedServiceIds.clear();
        expandedServiceIds.addAll(added);
        step = 1;
      });
    }
  }

  Future<void> _showEditServiceDetailsSheet(
    BuildContext context, {
    String? serviceId,
  }) async {
    final d = draft;
    if (d == null) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(sheetContext).size.height * 0.85,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.assignment_rounded,
                              color: Color(0xFF2563EB),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Chỉnh sửa thông tin dịch vụ',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                Text(
                                  'Cập nhật chi tiết công việc cho Tasker',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Color(0xFF64748B),
                      ),
                      tooltip: 'Đóng',
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),
              Flexible(
                child: ListView(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    16,
                    20,
                    MediaQuery.of(sheetContext).viewInsets.bottom + 20,
                  ),
                  children: [
                    for (int i = 0; i < selectedServices.length; i++) ...[
                      () {
                        final s = selectedServices[i];
                        if (serviceId != null && s.id != serviceId)
                          return const SizedBox.shrink();
                        final sSchema =
                            schemas
                                .where(
                                  (sch) => sch.serviceSlugs.contains(s.slug),
                                )
                                .firstOrNull ??
                            (s.id == d.serviceId ? schema : null);
                        final prefix = s.id == d.serviceId ? '' : '${s.id}_';

                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 7,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF059669),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      '#${i + 1}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      s.name,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              if (sSchema != null &&
                                  sSchema.fields.isNotEmpty) ...[
                                ...sSchema.fields.map(
                                  (f) => Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: _buildFormField(f, prefix, d),
                                  ),
                                ),
                              ],
                              _buildServiceDescriptionField(s, d),
                            ],
                          ),
                        );
                      }(),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF059669),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Lưu thông tin',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showEditScheduleSheet(BuildContext context) async {
    final d = draft;
    if (d == null) return;
    DateTime tempDt = validSchedule(
      d.scheduledAt ?? DateTime.now().add(const Duration(days: 1)),
    );

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final now = DateTime.now();
            final today = DateTime(now.year, now.month, now.day);
            final tomorrow = today.add(const Duration(days: 1));
            final dayAfter = today.add(const Duration(days: 2));

            bool isSameDay(DateTime a, DateTime b) =>
                a.year == b.year && a.month == b.month && a.day == b.day;

            const timePresets = [
              '08:00',
              '09:00',
              '10:30',
              '13:30',
              '14:00',
              '15:30',
              '17:00',
              '18:00',
            ];
            final currentTimeStr =
                '${tempDt.hour.toString().padLeft(2, '0')}:${tempDt.minute.toString().padLeft(2, '0')}';

            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(sheetContext).size.height * 0.85,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(7),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF3C7),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.calendar_month_rounded,
                                  color: Color(0xFFD97706),
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Thay đổi lịch hẹn',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                    Text(
                                      'Chọn thời gian đối tác đến thực hiện',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(sheetContext).pop(),
                          icon: const Icon(
                            Icons.close_rounded,
                            color: Color(0xFF64748B),
                          ),
                          tooltip: 'Đóng',
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFFE2E8F0)),
                  Flexible(
                    child: ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        // Selected Date & Time Highlight Card
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFF0FDF4), Color(0xFFECFDF5)],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFA7F3D0)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x0A000000),
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.event_available_rounded,
                                  color: Color(0xFF059669),
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Thời gian đã chọn',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF047857),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${timeLabel(tempDt)} • ${dateLabel(tempDt)}',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF065F46),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          '1. Chọn ngày thực hiện',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ChoiceChip(
                              label: const Text('Hôm nay'),
                              selected: isSameDay(tempDt, today),
                              onSelected: (_) {
                                setModalState(() {
                                  tempDt = DateTime(
                                    today.year,
                                    today.month,
                                    today.day,
                                    tempDt.hour,
                                    tempDt.minute,
                                  );
                                  tempDt = validSchedule(tempDt);
                                });
                              },
                              selectedColor: const Color(0xFFDCFCE7),
                              labelStyle: TextStyle(
                                color: isSameDay(tempDt, today)
                                    ? const Color(0xFF15803D)
                                    : const Color(0xFF334155),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            ChoiceChip(
                              label: const Text('Ngày mai'),
                              selected: isSameDay(tempDt, tomorrow),
                              onSelected: (_) {
                                setModalState(() {
                                  tempDt = DateTime(
                                    tomorrow.year,
                                    tomorrow.month,
                                    tomorrow.day,
                                    tempDt.hour,
                                    tempDt.minute,
                                  );
                                });
                              },
                              selectedColor: const Color(0xFFDCFCE7),
                              labelStyle: TextStyle(
                                color: isSameDay(tempDt, tomorrow)
                                    ? const Color(0xFF15803D)
                                    : const Color(0xFF334155),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            ChoiceChip(
                              label: const Text('Ngày kia'),
                              selected: isSameDay(tempDt, dayAfter),
                              onSelected: (_) {
                                setModalState(() {
                                  tempDt = DateTime(
                                    dayAfter.year,
                                    dayAfter.month,
                                    dayAfter.day,
                                    tempDt.hour,
                                    tempDt.minute,
                                  );
                                });
                              },
                              selectedColor: const Color(0xFFDCFCE7),
                              labelStyle: TextStyle(
                                color: isSameDay(tempDt, dayAfter)
                                    ? const Color(0xFF15803D)
                                    : const Color(0xFF334155),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            ActionChip(
                              avatar: const Icon(
                                Icons.date_range_rounded,
                                size: 16,
                              ),
                              label: const Text('Chọn ngày khác'),
                              onPressed: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: tempDt,
                                  firstDate: now,
                                  lastDate: now.add(const Duration(days: 365)),
                                );
                                if (picked != null) {
                                  setModalState(() {
                                    tempDt = DateTime(
                                      picked.year,
                                      picked.month,
                                      picked.day,
                                      tempDt.hour,
                                      tempDt.minute,
                                    );
                                    tempDt = validSchedule(tempDt);
                                  });
                                }
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          '2. Chọn khung giờ bắt đầu',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final t in timePresets)
                              ChoiceChip(
                                label: Text(t),
                                selected: currentTimeStr == t,
                                onSelected: (_) {
                                  final parts = t.split(':');
                                  final h = int.parse(parts[0]);
                                  final m = int.parse(parts[1]);
                                  setModalState(() {
                                    tempDt = DateTime(
                                      tempDt.year,
                                      tempDt.month,
                                      tempDt.day,
                                      h,
                                      m,
                                    );
                                  });
                                },
                                selectedColor: const Color(0xFFDCFCE7),
                                labelStyle: TextStyle(
                                  color: currentTimeStr == t
                                      ? const Color(0xFF15803D)
                                      : const Color(0xFF334155),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ActionChip(
                              avatar: const Icon(
                                Icons.access_time_rounded,
                                size: 16,
                              ),
                              label: const Text('Chọn giờ tùy chỉnh'),
                              onPressed: () async {
                                final picked = await showTimePicker(
                                  context: context,
                                  initialTime: TimeOfDay(
                                    hour: tempDt.hour,
                                    minute: tempDt.minute,
                                  ),
                                );
                                if (picked != null) {
                                  setModalState(() {
                                    tempDt = DateTime(
                                      tempDt.year,
                                      tempDt.month,
                                      tempDt.day,
                                      picked.hour,
                                      picked.minute,
                                    );
                                  });
                                }
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          final validated = validSchedule(tempDt);
                          edit(() => d.scheduledAt = validated);
                          Navigator.of(sheetContext).pop();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF059669),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Cập nhật lịch hẹn',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showEditAddressAndNotesSheet(BuildContext context) async {
    final d = draft;
    if (d == null || c.data == null) return;
    String? addressValidationError;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final addresses = c.data!.addresses;
            final selectedAddresses = addresses.where(
              (a) => a.id == d.addressId,
            );
            final currentAddressError = selectedAddresses.isEmpty
                ? addressValidationError
                : addressError(selectedAddresses.first);
            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(sheetContext).size.height * 0.85,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(7),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEE2E2),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.location_on_rounded,
                                  color: Color(0xFFDC2626),
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Địa chỉ và ghi chú',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                    Text(
                                      'Chọn nơi thực hiện và thêm dặn dò',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(sheetContext).pop(),
                          icon: const Icon(
                            Icons.close_rounded,
                            color: Color(0xFF64748B),
                          ),
                          tooltip: 'Đóng',
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFFE2E8F0)),
                  Flexible(
                    child: ListView(
                      padding: EdgeInsets.fromLTRB(
                        20,
                        16,
                        20,
                        MediaQuery.of(sheetContext).viewInsets.bottom + 20,
                      ),
                      children: [
                        const Text(
                          'Địa chỉ thực hiện',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 10),
                        ...addresses.map((a) {
                          final isSelected = d.addressId == a.id;
                          final fullAddress = [
                            a.detail,
                            if (a.ward.isNotEmpty) a.ward,
                            if (a.district.isNotEmpty) a.district,
                            if (a.city.isNotEmpty) a.city,
                          ].where((s) => s.trim().isNotEmpty).join(', ');

                          if (isSelected) {
                            return bookingAddressCard(
                              a,
                              onEdit: () async {
                                await editBookingAddress(a);
                                setModalState(() {});
                              },
                            );
                          }
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            child: InkWell(
                              onTap: () {
                                edit(() => d.addressId = a.id);
                                setModalState(() {});
                              },
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xFFF0FDF4)
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isSelected
                                        ? const Color(0xFF059669)
                                        : const Color(0xFFE2E8F0),
                                    width: isSelected ? 1.5 : 1,
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      isSelected
                                          ? Icons.check_circle_rounded
                                          : Icons
                                                .radio_button_unchecked_rounded,
                                      color: isSelected
                                          ? const Color(0xFF059669)
                                          : const Color(0xFF94A3B8),
                                      size: 22,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Wrap(
                                            crossAxisAlignment:
                                                WrapCrossAlignment.center,
                                            spacing: 6,
                                            runSpacing: 4,
                                            children: [
                                              Text(
                                                a.label,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 14.5,
                                                  color: isSelected
                                                      ? const Color(0xFF059669)
                                                      : const Color(0xFF0F172A),
                                                ),
                                              ),
                                              if (a.isDefault)
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 6,
                                                        vertical: 2,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: const Color(
                                                      0xFFDCFCE7,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          4,
                                                        ),
                                                  ),
                                                  child: const Text(
                                                    'Mặc định',
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: Color(0xFF15803D),
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            fullAddress.isNotEmpty
                                                ? fullAddress
                                                : a.detail,
                                            style: const TextStyle(
                                              fontSize: 12.5,
                                              color: Color(0xFF334155),
                                            ),
                                          ),
                                          if (a.contactName.isNotEmpty ||
                                              a.contactPhone.isNotEmpty) ...[
                                            const SizedBox(height: 3),
                                            Text(
                                              '${a.contactName.isNotEmpty ? a.contactName : ''}${a.contactName.isNotEmpty && a.contactPhone.isNotEmpty ? ' • ' : ''}${a.contactPhone}',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: Color(0xFF64748B),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.edit_outlined,
                                        size: 18,
                                        color: Color(0xFF64748B),
                                      ),
                                      tooltip: 'Sửa địa chỉ',
                                      onPressed: () async {
                                        await editBookingAddress(a);
                                        setModalState(() {});
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                        OutlinedButton.icon(
                          onPressed: () async {
                            await editBookingAddress(null);
                            setModalState(() {});
                          },
                          icon: const Icon(
                            Icons.add_location_alt_outlined,
                            size: 18,
                          ),
                          label: const Text('Thêm địa chỉ mới'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF059669),
                            side: const BorderSide(color: Color(0xFF059669)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Ghi chú cho Đối tác / Partner',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          initialValue: d.notes,
                          maxLines: 3,
                          maxLength: 1000,
                          decoration: InputDecoration(
                            labelText: 'Lưu ý chi tiết',
                            floatingLabelBehavior: FloatingLabelBehavior.always,
                            labelStyle: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w600,
                            ),
                            floatingLabelStyle: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF059669),
                              fontWeight: FontWeight.w700,
                            ),
                            hintText: 'Ví dụ: Gọi trước khi đến 15 phút, nhà đối diện trường học...',
                            hintStyle: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF94A3B8),
                            ),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Color(0xFFE2E8F0),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Color(0xFFE2E8F0),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Color(0xFF059669),
                                width: 1.5,
                              ),
                            ),
                          ),
                          onChanged: (v) => edit(() => d.notes = v),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (currentAddressError != null)
                          Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: const Color(0xFFFECACA),
                              ),
                            ),
                            child: Text(
                              currentAddressError,
                              style: const TextStyle(
                                color: Color(0xFFB91C1C),
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ElevatedButton(
                          onPressed: () {
                            final selected = addresses.where(
                              (a) => a.id == d.addressId,
                            );
                            final message = selected.isEmpty
                                ? 'Vui lòng chọn địa chỉ.'
                                : addressError(selected.first);
                            if (message != null) {
                              setModalState(
                                () => addressValidationError = message,
                              );
                              return;
                            }
                            Navigator.of(sheetContext).pop();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF059669),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            'Xong',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget reviewSection(
    String title,
    dynamic targetOrAction,
    List<Widget> content, {
    IconData? icon,
    Color? iconColor,
    Color? iconBg,
    String actionLabel = 'Chỉnh sửa',
  }) {
    IconData resolvedIcon = icon ?? Icons.checklist_rounded;
    Color resolvedIconColor = iconColor ?? const Color(0xFF059669);
    Color resolvedIconBg = iconBg ?? const Color(0xFFECFDF5);

    if (icon == null) {
      if (title.contains('Dịch vụ')) {
        resolvedIcon = Icons.cleaning_services_rounded;
        resolvedIconColor = const Color(0xFF059669);
        resolvedIconBg = const Color(0xFFECFDF5);
      } else if (title.contains('Thông tin')) {
        resolvedIcon = Icons.assignment_rounded;
        resolvedIconColor = const Color(0xFF2563EB);
        resolvedIconBg = const Color(0xFFEFF6FF);
      } else if (title.contains('Lịch')) {
        resolvedIcon = Icons.calendar_month_rounded;
        resolvedIconColor = const Color(0xFFD97706);
        resolvedIconBg = const Color(0xFFFEF3C7);
      } else if (title.contains('Địa chỉ')) {
        resolvedIcon = Icons.location_on_rounded;
        resolvedIconColor = const Color(0xFFDC2626);
        resolvedIconBg = const Color(0xFFFEE2E2);
      }
    }

    final VoidCallback? onEditAction = targetOrAction is VoidCallback
        ? targetOrAction
        : (targetOrAction is int
              ? () => edit(() => step = targetOrAction)
              : null);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: resolvedIconBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(resolvedIcon, size: 18, color: resolvedIconColor),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
                if (onEditAction != null)
                  TextButton.icon(
                    onPressed: saving ? null : onEditAction,
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF059669),
                      backgroundColor: const Color(0xFFF0FDF4),
                      side: const BorderSide(color: Color(0xFFA7F3D0)),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      visualDensity: VisualDensity.compact,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    icon: const Icon(Icons.edit_outlined, size: 14),
                    label: Text(
                      actionLabel,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            ...content,
          ],
        ),
      ),
    );
  }

  Widget bookingAddressCard(Address a, {required VoidCallback onEdit}) {
    final fullAddress = [
      a.detail,
      if (a.ward.isNotEmpty) a.ward,
      if (a.district.isNotEmpty) a.district,
      if (a.city.isNotEmpty) a.city,
    ].where((s) => s.trim().isNotEmpty).join(', ');
    final missingFields = addressFields(a).entries
        .where((e) => e.value.trim().isEmpty)
        .toList();
    final isInvalidPhone = !RegExp(r'^0[0-9]{9}$')
        .hasMatch(a.contactPhone.trim());

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF059669), width: 1.5),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0C059669),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Icon + Title + Badges + Checkmark
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD1FAE5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.location_on_rounded,
                    size: 20,
                    color: Color(0xFF059669),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Text(
                        a.label,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      if (a.isDefault)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFF86EFAC)),
                          ),
                          child: const Text(
                            'Địa chỉ mặc định',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF15803D),
                            ),
                          ),
                        ),
                      if (a.buildingType.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Loại: ${a.buildingType}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF475569),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF059669),
                  size: 24,
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1, color: Color(0xFFD1FAE5)),
            const SizedBox(height: 12),

            // Full address row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.home_work_outlined,
                  size: 18,
                  color: Color(0xFF059669),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    fullAddress.isNotEmpty
                        ? fullAddress
                        : 'Địa chỉ: ${a.detail.isEmpty ? 'Chưa có — vui lòng bổ sung' : a.detail}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: a.detail.isEmpty
                          ? Colors.red.shade700
                          : const Color(0xFF1E293B),
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Contact info card
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.person_outline_rounded,
                        size: 16,
                        color: a.contactName.trim().isEmpty
                            ? Colors.red.shade700
                            : const Color(0xFF64748B),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Người liên hệ: ${a.contactName.trim().isEmpty ? 'Chưa có — vui lòng bổ sung' : a.contactName}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: a.contactName.trim().isEmpty
                                ? Colors.red.shade700
                                : const Color(0xFF334155),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.phone_outlined,
                        size: 16,
                        color: isInvalidPhone
                            ? Colors.red.shade700
                            : const Color(0xFF64748B),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Số điện thoại: ${a.contactPhone.trim().isEmpty ? 'Chưa có — vui lòng bổ sung' : a.contactPhone}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: isInvalidPhone
                                ? Colors.red.shade700
                                : const Color(0xFF334155),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Building description and note (if present)
            if (a.buildingDescription.isNotEmpty || a.note.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (a.buildingDescription.isNotEmpty)
                      Row(
                        children: [
                          const Icon(
                            Icons.info_outline,
                            size: 16,
                            color: Color(0xFF64748B),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Mô tả vị trí: ${a.buildingDescription}',
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF475569),
                              ),
                            ),
                          ),
                        ],
                      ),
                    if (a.buildingDescription.isNotEmpty && a.note.isNotEmpty)
                      const SizedBox(height: 6),
                    if (a.note.isNotEmpty)
                      Row(
                        children: [
                          const Icon(
                            Icons.sticky_note_2_outlined,
                            size: 16,
                            color: Color(0xFF64748B),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Ghi chú cho Partner: ${a.note}',
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF475569),
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ],

            // Missing fields warning banner
            if (missingFields.isNotEmpty || isInvalidPhone) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.error_outline_rounded,
                          size: 16,
                          color: Colors.red.shade700,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Cần cập nhật đầy đủ địa chỉ trước khi tiếp tục.',
                            style: TextStyle(
                              color: Colors.red.shade700,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (missingFields.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Còn thiếu: ${missingFields.map((f) => f.key).join(', ')}',
                        style: TextStyle(
                          color: Colors.red.shade800,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],

            // Card action buttons
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: saving ? null : onEdit,
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: Text(
                      addressError(a) != null
                          ? 'Bổ sung thông tin địa chỉ'
                          : 'Sửa địa chỉ',
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF059669),
                      side: const BorderSide(color: Color(0xFF059669)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Map<String, String> addressFields(Address a) => {
    'Tên địa chỉ': a.label,
    'Loại bất động sản': a.buildingType,
    'Địa chỉ': a.detail,
    'Mô tả vị trí': a.buildingDescription,
    'Tỉnh / thành phố': a.city,
    'Ghi chú cho Partner': a.note,
    'Người liên hệ': a.contactName,
    'Số điện thoại': a.contactPhone,
    if (a.ward.isNotEmpty) 'Phường / xã': a.ward,
    if (a.district.isNotEmpty) 'Quận / huyện': a.district,
  };

  Future<void> _refreshWorkAreas() async {
    if (c.repository is! ApiCustomerRepository) return;
    try {
      final result = await (c.repository as ApiCustomerRepository).session
          .request('/public/work-areas');
      if (!mounted) return;
      final areas = (result as List).cast<Map>();
      setState(() {
        _areaErrors.clear();
        for (final address in c.data?.addresses ?? <Address>[]) {
          if (!areas.any(
            (a) =>
                a['city'].toString().trim().toLowerCase() ==
                    address.city.trim().toLowerCase() &&
                a['recruiting'] == true,
          )) {
            _areaErrors[address.city] =
                'Khu vực đang bảo trì hoặc chưa được mở. Vui lòng đổi địa chỉ.';
          }
        }
      });
    } catch (_) {
      /* The next action retries and blocks on failure. */
    }
  }

  final Map<String, String> _areaErrors = {};
  String? addressError(Address a) {
    if (_areaErrors.containsKey(a.city)) return _areaErrors[a.city];
    final missing = addressFields(a).entries
        .where((e) => e.value.trim().isEmpty)
        .map((e) => e.key)
        .toList();
    if (missing.isNotEmpty) return 'Vui lòng bổ sung: ${missing.join(', ')}.';
    if (!RegExp(r'^0[0-9]{9}$').hasMatch(a.contactPhone.trim())) {
      return 'Số điện thoại liên hệ phải có 10 chữ số và bắt đầu bằng 0.';
    }
    return null;
  }

  Future<void> next() async {
    if (saving) return;
    if (step == 0) {
      setState(() => saving = true);
      try {
        final updatedSchemas = await repository.bookingSchemas();
        if (!mounted) return;
        schemas = updatedSchemas;
        draft?.schemaKey = schema?.key ?? '';
        draft?.schemaVersion = schema?.version ?? 1;
      } catch (e) {
        if (!mounted) return;
        setState(() {
          saving = false;
          error = e is RepositoryFailure
              ? e.message
              : 'Không thể tải yêu cầu mới nhất của dịch vụ.';
        });
        return;
      }
      setState(() => saving = false);
    }
    String? message;
    if (step == 0) {
      if (draft == null || draft!.selectedServiceIds.isEmpty) {
        message =
            'Vui lòng chọn ít nhất 1 dịch vụ (tối đa 3 dịch vụ) để tiếp tục.';
      } else if (schema == null) {
        message = 'Dịch vụ này chưa có biểu mẫu đặt việc. Vui lòng chọn dịch vụ khác.';
      }
    }
    if (step == 1) {
      message = validateServiceDetails();
      if (message != null && selectedServices.isNotEmpty) {
        expandedServiceIds.add(selectedServices.first.id);
      }
    }
    if (step == 2 &&
        (draft!.scheduledAt == null ||
            !draft!.scheduledAt!.isAfter(DateTime.now()))) {
      message = 'Chọn ngày và giờ trong tương lai.';
    }
    if (step == 3 && c.repository is ApiCustomerRepository) {
      setState(() => saving = true);
      try {
        final result = await (c.repository as ApiCustomerRepository).session
            .request('/public/work-areas');
        final areas = (result as List).cast<Map>();
        _areaErrors.clear();
        for (final address in c.data!.addresses) {
          if (!areas.any(
            (a) =>
                a['city'].toString().trim().toLowerCase() ==
                    address.city.trim().toLowerCase() &&
                a['recruiting'] == true,
          ))
            _areaErrors[address.city] =
                'Khu vực đang bảo trì hoặc chưa được mở. Vui lòng đổi địa chỉ.';
        }
      } catch (_) {
        message = 'Không thể kiểm tra khu vực. Vui lòng thử lại.';
      }
      if (!mounted) return;
      setState(() => saving = false);
    }
    if (step == 3 && message == null) {
      final addresses = c.data!.addresses.where(
        (a) => a.id == draft!.addressId,
      );
      message = addresses.isEmpty
          ? 'Chọn hoặc thêm địa chỉ của bạn.'
          : addressError(addresses.first);
    }
    if (message == null && step == 3) {
      setState(() => saving = true);
      try {
        await repository.saveBookingDraft(draft!);
      } catch (e) {
        message = e is RepositoryFailure
            ? e.message
            : 'Không thể lưu đơn chưa hoàn thành. Vui lòng thử lại.';
      }
      if (!mounted) return;
      setState(() => saving = false);
    }
    setState(() {
      error = message;
      if (message == null && step < 4) step++;
    });
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop && !saving) step > 0 ? setState(() => step--) : c.back();
    },
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Đặt dịch vụ'),
        leading: IconButton(
          tooltip: 'Quay lại',
          icon: const Icon(Icons.arrow_back),
          onPressed: saving
              ? null
              : () => step > 0 ? setState(() => step--) : c.back(),
        ),
        actions: [
          IconButton(
            tooltip: 'Trang dịch vụ',
            icon: const Icon(Icons.home_outlined),
            onPressed: saving
                ? null
                : () {
                    c.toServices();
                    if (Navigator.of(context).canPop()) {
                      Navigator.of(context).pop();
                    }
                  },
          ),
        ],
      ),
      body: SafeArea(
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : draft == null
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(error ?? 'Không thể tải thông tin đặt dịch vụ'),
                    TextButton(onPressed: load, child: const Text('Thử lại')),
                  ],
                ),
              )
            : Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: AbsorbPointer(
                    absorbing: saving,
                    child: CustomScrollView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      slivers: [
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 64),
                          sliver: SliverFillRemaining(
                            hasScrollBody: false,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  'BƯỚC ${step + 1}/5',
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                LinearProgressIndicator(
                                  value: (step + 1) / 5,
                                  minHeight: 6,
                                ),
                                const SizedBox(height: 20),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        steps[step],
                                        style: Theme.of(context)
                                            .textTheme
                                            .headlineSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.w800,
                                              color: const Color(0xFF0F172A),
                                            ),
                                      ),
                                    ),
                                    if (step == 3 &&
                                        c.data != null &&
                                        c.data!.addresses.isNotEmpty) ...[
                                      const SizedBox(width: 8),
                                      OutlinedButton.icon(
                                        onPressed: saving
                                            ? null
                                            : () => _showAddressPickerSheet(
                                                context,
                                              ),
                                        icon: const Icon(
                                          Icons.swap_horiz_rounded,
                                          size: 18,
                                        ),
                                        label: const Text('Đổi địa chỉ'),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: const Color(
                                            0xFF059669,
                                          ),
                                          side: const BorderSide(
                                            color: Color(0xFF059669),
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 5,
                                          ),
                                          visualDensity: VisualDensity.compact,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                          ),
                                          backgroundColor: const Color(
                                            0xFFECFDF5,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 16),
                                if (error != null)
                                  if (!(step == 1 && _showServiceErrors))
                                    notice(error!, AppColors.error),

                                ...content(),

                                if (step < 4) ...[
                                  const Spacer(),
                                  const SizedBox(height: 24),
                                  PrimaryButton(
                                    'Tiếp tục',
                                    next,
                                    icon: Icons.arrow_forward,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    ),
  );
  Widget notice(String text, Color color) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Panel(
      child: Text(text, style: TextStyle(color: color)),
    ),
  );
  List<Widget> content() {
    final d = draft!;
    switch (step) {
      case 0:
        final selectedIds = d.selectedServiceIds;
        final selectedList = selectedServices;
        final allServices = c.data!.services;
        final filtered = searchQuery.trim().isEmpty
            ? allServices
            : allServices.where((s) {
                final q = searchQuery.trim().toLowerCase();
                return s.name.toLowerCase().contains(q) ||
                    s.subtitle.toLowerCase().contains(q) ||
                    s.description.toLowerCase().contains(q);
              }).toList();

        return [
          // 1. GUIDANCE & MULTI-SELECT STATUS BANNER
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFECFDF5), Color(0xFFF0FDF4)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFA7F3D0)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0A10B981),
                  blurRadius: 10,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.layers_rounded,
                        color: Color(0xFF059669),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              Text(
                                'Đã chọn ${selectedIds.length}/3 dịch vụ',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14.5,
                                  color: Color(0xFF065F46),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: selectedIds.length == 3
                                      ? const Color(0xFFFEF3C7)
                                      : const Color(0xFFDCFCE7),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: selectedIds.length == 3
                                        ? const Color(0xFFFDE68A)
                                        : const Color(0xFF86EFAC),
                                  ),
                                ),
                                child: Text(
                                  selectedIds.length == 3
                                      ? 'Đạt tối đa 3/3'
                                      : 'Tối đa 3 dịch vụ',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                    color: selectedIds.length == 3
                                        ? const Color(0xFF92400E)
                                        : const Color(0xFF166534),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            selectedIds.isEmpty
                                ? 'Tick chọn 1 đến 3 dịch vụ bạn muốn nhân viên thực hiện cùng lúc.'
                                : selectedIds.length < 3
                                ? 'Bạn có thể tick chọn thêm ${3 - selectedIds.length} dịch vụ nữa.'
                                : 'Đã đủ 3 dịch vụ. Nhấn vào dịch vụ đã chọn nếu muốn thay đổi.',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF047857),
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // 3 SEGMENTS PROGRESS INDICATOR
                Row(
                  children: [
                    for (int i = 0; i < 3; i++)
                      Expanded(
                        child: Container(
                          height: 5,
                          margin: EdgeInsets.only(right: i < 2 ? 6 : 0),
                          decoration: BoxDecoration(
                            color: i < selectedIds.length
                                ? const Color(0xFF10B981)
                                : const Color(0xFFCBD5E1)
                                      .withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                  ],
                ),
                // SELECTED CHIPS TRAY
                if (selectedList.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Divider(color: Color(0x3310B981), height: 1),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: selectedList.map((s) {
                      final idx = selectedIds.indexOf(s.id) + 1;
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFF6EE7B7)),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x0D000000),
                              blurRadius: 4,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 1.5,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '#$idx',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 140),
                              child: Text(
                                s.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF065F46),
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            GestureDetector(
                              onTap: () => toggleService(s.id),
                              child: const Icon(
                                Icons.cancel_rounded,
                                size: 16,
                                color: Color(0xFF94A3B8),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),

          // 2. SEARCH BOX (nếu có hơn 4 dịch vụ)
          if (allServices.length > 4)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: TextField(
                onChanged: (v) => setState(() => searchQuery = v),
                decoration: InputDecoration(
                  hintText: 'Tìm dịch vụ (dọn nhà, máy lạnh, sofa...)',
                  hintStyle: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF94A3B8),
                  ),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    size: 20,
                    color: Color(0xFF64748B),
                  ),
                  suffixIcon: searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18),
                          onPressed: () => setState(() => searchQuery = ''),
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                      color: Color(0xFF10B981),
                      width: 1.5,
                    ),
                  ),
                ),
              ),
            ),

          // 3. SERVICE CARDS LIST
          if (filtered.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Center(
                child: Column(
                  children: [
                    const Icon(
                      Icons.search_off_rounded,
                      size: 40,
                      color: Color(0xFF94A3B8),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Không tìm thấy dịch vụ nào cho "$searchQuery"',
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ...filtered.map((s) {
              final isSelected = selectedIds.contains(s.id);
              final orderIndex = selectedIds.indexOf(s.id) + 1;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => toggleService(s.id),
                    borderRadius: BorderRadius.circular(20),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFFF0FDF4)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF10B981)
                              : const Color(0xFFE2E8F0),
                          width: isSelected ? 2 : 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: isSelected
                                ? const Color(0x1A10B981)
                                : const Color(0x080F172A),
                            blurRadius: isSelected ? 12 : 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          // Leading squircle icon container
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFFD1FAE5)
                                  : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xFFA7F3D0)
                                    : const Color(0xFFF1F5F9),
                              ),
                            ),
                            child: Center(
                              child: ServiceSymbol.forService(
                                s,
                                size: 28,
                                color: isSelected
                                    ? const Color(0xFF059669)
                                    : const Color(0xFF475569),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          // Service title & subtitle
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        s.name,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 15.5,
                                          color: isSelected
                                              ? const Color(0xFF065F46)
                                              : const Color(0xFF0F172A),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  s.subtitle,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    color: Color(0xFF64748B),
                                    height: 1.35,
                                  ),
                                ),
                                if (s.hourlyRate > 0) ...[
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2.5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? const Color(0xFFDCFCE7)
                                          : const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'Từ ${money(s.hourlyRate)}${s.priceUnit}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: isSelected
                                            ? const Color(0xFF15803D)
                                            : const Color(0xFF475569),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Trailing selection checkmark or radio outline
                          if (isSelected)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (selectedIds.length > 1) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF10B981),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '#$orderIndex',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                ],
                                const Icon(
                                  Icons.check_circle,
                                  color: Color(0xFF10B981),
                                  size: 26,
                                ),
                              ],
                            )
                          else
                            Icon(
                              Icons.circle_outlined,
                              color: selectedIds.length >= 3
                                  ? const Color(0xFFCBD5E1)
                                        .withValues(alpha: 0.5)
                                  : const Color(0xFF94A3B8),
                              size: 24,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
        ];
      case 1:
        if (selectedServices.length >= 2) {
          return [
            // Top guidance banner
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFECFDF5), Color(0xFFF0FDF4)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFA7F3D0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981)
                              .withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.view_agenda_rounded,
                          color: Color(0xFF059669),
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Đã chọn ${selectedServices.length} dịch vụ',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                                color: Color(0xFF065F46),
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Chạm vào từng hộp dịch vụ để điền thông tin chi tiết.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF047857),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: selectedServices.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final s = entry.value;
                      final sch = schemas
                          .where((sc) => sc.serviceSlugs.contains(s.slug))
                          .firstOrNull;
                      final filled = _isServiceFilled(s, sch, d);
                      final isCurrentExpanded = expandedServiceIds.contains(
                        s.id,
                      );
                      return GestureDetector(
                        onTap: () => toggleExpandedService(s.id),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: filled
                                ? const Color(0xFFDCFCE7)
                                : (isCurrentExpanded
                                      ? const Color(0xFFEFF6FF)
                                      : Colors.white),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: filled
                                  ? const Color(0xFF86EFAC)
                                  : (isCurrentExpanded
                                        ? const Color(0xFF93C5FD)
                                        : const Color(0xFFCBD5E1)),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                filled
                                    ? Icons.check_circle_rounded
                                    : (isCurrentExpanded
                                          ? Icons.edit_rounded
                                          : Icons.pending_outlined),
                                size: 12,
                                color: filled
                                    ? const Color(0xFF16A34A)
                                    : (isCurrentExpanded
                                          ? const Color(0xFF2563EB)
                                          : const Color(0xFF64748B)),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '#${idx + 1} ${s.name}',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: filled
                                      ? const Color(0xFF15803D)
                                      : (isCurrentExpanded
                                            ? const Color(0xFF1D4ED8)
                                            : const Color(0xFF475569)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            // Service Accordion Boxes
            ...selectedServices.asMap().entries.map((entry) {
              final index = entry.key;
              final s = entry.value;
              final isExpanded = expandedServiceIds.contains(s.id);
              final sSchema = schemas
                  .where((sch) => sch.serviceSlugs.contains(s.slug))
                  .firstOrNull;
              final isFilled = _isServiceFilled(s, sSchema, d);
              final isPrimary = index == 0;

              return AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeInOut,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isExpanded
                        ? const Color(0xFF10B981)
                        : (isFilled
                              ? const Color(0xFFA7F3D0)
                              : const Color(0xFFE2E8F0)),
                    width: isExpanded ? 1.8 : 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isExpanded
                          ? const Color(0xFF10B981).withValues(alpha: 0.1)
                          : Colors.black.withValues(alpha: 0.03),
                      blurRadius: isExpanded ? 14 : 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Material(
                        color: isExpanded
                            ? const Color(0xFFF0FDF4)
                            : (isFilled
                                  ? const Color(0xFFF8FAFC)
                                  : Colors.white),
                        child: InkWell(
                          onTap: () => toggleExpandedService(s.id),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 14,
                            ),
                            child: Row(
                              children: [
                                Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: isExpanded
                                            ? const Color(0xFFECFDF5)
                                            : const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: isExpanded
                                              ? const Color(0xFFA7F3D0)
                                              : const Color(0xFFE2E8F0),
                                        ),
                                      ),
                                      child: Center(
                                        child: ServiceSymbol.forService(
                                          s,
                                          size: 22,
                                          color: isExpanded
                                              ? const Color(0xFF059669)
                                              : const Color(0xFF475569),
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      top: -4,
                                      left: -4,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 5,
                                          vertical: 1.5,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isExpanded
                                              ? const Color(0xFF059669)
                                              : const Color(0xFF64748B),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Text(
                                          '#${index + 1}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              s.name,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 14.5,
                                                color: Color(0xFF0F172A),
                                              ),
                                            ),
                                          ),
                                          if (isFilled)
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 7,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFDCFCE7),
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              child: const Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons.check,
                                                    size: 11,
                                                    color: Color(0xFF16A34A),
                                                  ),
                                                  SizedBox(width: 2),
                                                  Text(
                                                    'Đã điền',
                                                    style: TextStyle(
                                                      fontSize: 10.5,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: Color(0xFF15803D),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            )
                                          else if (isExpanded)
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 7,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFEFF6FF),
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              child: const Text(
                                                'Đang điền',
                                                style: TextStyle(
                                                  fontSize: 10.5,
                                                  fontWeight: FontWeight.w700,
                                                  color: Color(0xFF2563EB),
                                                ),
                                              ),
                                            )
                                          else
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 7,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFF1F5F9),
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              child: const Text(
                                                'Chạm để điền',
                                                style: TextStyle(
                                                  fontSize: 10.5,
                                                  fontWeight: FontWeight.w600,
                                                  color: Color(0xFF64748B),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        '${money(s.hourlyRate)} • ${s.subtitle.isNotEmpty ? s.subtitle : 'Dịch vụ Taskly'}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF64748B),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: isExpanded
                                        ? const Color(0xFFDCFCE7)
                                        : Colors.transparent,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    isExpanded
                                        ? Icons.keyboard_arrow_up_rounded
                                        : Icons.keyboard_arrow_down_rounded,
                                    color: isExpanded
                                        ? const Color(0xFF059669)
                                        : const Color(0xFF94A3B8),
                                    size: 22,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (isExpanded) ...[
                        const Divider(height: 1, color: Color(0xFFE2E8F0)),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (isPrimary && schema != null) ...[
                                ...schema!.fields.map(
                                  (f) => Padding(
                                    padding: const EdgeInsets.only(bottom: 14),
                                    child: _buildFormField(f, '', d),
                                  ),
                                ),
                                if (schema!.key == 'shop')
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 14),
                                    child: notice(
                                      'Ngân sách mua hàng được tách khỏi phí dịch vụ. Phí dịch vụ chưa được báo giá.',
                                      AppColors.muted,
                                    ),
                                  ),
                                _buildServiceDescriptionField(s, d),
                              ] else ...[
                                if (sSchema != null &&
                                    sSchema.fields.isNotEmpty) ...[
                                  ...sSchema.fields.map(
                                    (f) => Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 14,
                                      ),
                                      child: _buildFormField(f, '${s.id}_', d),
                                    ),
                                  ),
                                ],
                                if (sSchema?.key == 'shop')
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 14),
                                    child: notice(
                                      'Ngân sách mua hàng được tách khỏi phí dịch vụ. Phí dịch vụ chưa được báo giá.',
                                      AppColors.muted,
                                    ),
                                  ),
                                _buildServiceDescriptionField(s, d),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),
          ];
        }

        return [
          ...schema!.fields.map(
            (f) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _buildFormField(f, '', d),
            ),
          ),
          if (schema!.key == 'shop')
            notice(
              'Ngân sách mua hàng được tách khỏi phí dịch vụ. Phí dịch vụ chưa được báo giá.',
              AppColors.muted,
            ),
          if (service != null || selectedServices.isNotEmpty)
            _buildServiceDescriptionField(service ?? selectedServices.first, d),
        ];
      case 2:
        final earliest = earliestSchedule();
        final currentDt = validSchedule(
          d.scheduledAt ?? DateTime.now().add(const Duration(days: 1)),
        );
        DateTime timeOnDay(int hour, int minute) => DateTime(
          currentDt.year,
          currentDt.month,
          currentDt.day,
          hour,
          minute,
        );
        final currentHour = currentDt.hour.clamp(0, 23);
        final currentMinute = currentDt.minute.clamp(0, 59);
        final currentTimeStr =
            '${currentHour.toString().padLeft(2, '0')}:${currentMinute.toString().padLeft(2, '0')}';

        const presets = [
          '08:00',
          '09:00',
          '10:30',
          '13:30',
          '14:00',
          '15:30',
          '17:00',
          '18:00',
        ];

        return [
          // 1. DATE PICKER CARD
          InkWell(
            onTap: () async {
              final now = DateTime.now();
              final today = DateTime(now.year, now.month, now.day);
              final lastDay = today.add(const Duration(days: 365));
              final selectedDay = DateTime(
                currentDt.year,
                currentDt.month,
                currentDt.day,
              );
              final day = await showDatePicker(
                context: context,
                initialDate:
                    selectedDay.isBefore(today) || selectedDay.isAfter(lastDay)
                    ? today
                    : selectedDay,
                firstDate: today,
                lastDate: lastDay,
              );
              if (day != null && mounted) {
                edit(
                  () => d.scheduledAt = validSchedule(
                    DateTime(
                      day.year,
                      day.month,
                      day.day,
                      currentHour,
                      currentMinute,
                    ),
                  ),
                );
              }
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x06000000),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.calendar_month_rounded,
                      color: Color(0xFF059669),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Ngày thực hiện',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          d.scheduledAt == null
                              ? 'Chọn ngày thực hiện'
                              : dateLabel(d.scheduledAt!),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.edit_calendar_rounded,
                      size: 18,
                      color: Color(0xFF059669),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 2. 24H & 60M DIGITAL TIME SELECTOR CARD (NO ANALOG CLOCK, NO DURATION)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x06000000),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.access_time_filled_rounded,
                        color: Color(0xFF059669),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Giờ bắt đầu',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Chọn giờ (24h) và phút (60p)',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF059669),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        currentTimeStr,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Divider(height: 1, color: Color(0xFFF1F5F9)),
                ),

                // 24H & 60M Side-by-side Dropdown Selectors
                Row(
                  children: [
                    // Hour selector (00..23)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Giờ (00 - 23)',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF475569),
                            ),
                          ),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<int>(
                            key: ValueKey('hour-$currentHour'),
                            initialValue: currentHour,
                            isExpanded: true,
                            menuMaxHeight: 400,
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 8,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Color(0xFFE2E8F0),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Color(0xFFE2E8F0),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Color(0xFF059669),
                                  width: 1.5,
                                ),
                              ),
                            ),
                            icon: const Icon(
                              Icons.arrow_drop_down_rounded,
                              color: Color(0xFF059669),
                              size: 20,
                            ),
                            items: List.generate(24, (h) {
                              return DropdownMenuItem<int>(
                                value: h,
                                enabled: !timeOnDay(h, 59).isBefore(earliest),
                                child: Text(
                                  '${h.toString().padLeft(2, '0')} giờ',
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                    color: Color(0xFF1E293B),
                                  ),
                                ),
                              );
                            }).where((item) => item.enabled).toList(),
                            onChanged: (newHour) {
                              if (newHour == null) return;
                              if (timeOnDay(
                                newHour,
                                59,
                              ).isBefore(earliestSchedule())) {
                                return;
                              }
                              edit(
                                () => d.scheduledAt = validSchedule(
                                  timeOnDay(newHour, currentMinute),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.fromLTRB(4, 22, 4, 0),
                      child: Text(
                        ':',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ),
                    // Minute selector (00..59)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Phút (00 - 59)',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF475569),
                            ),
                          ),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<int>(
                            key: ValueKey('minute-$currentMinute'),
                            initialValue: currentMinute,
                            isExpanded: true,
                            menuMaxHeight: 400,
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 8,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Color(0xFFE2E8F0),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Color(0xFFE2E8F0),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Color(0xFF059669),
                                  width: 1.5,
                                ),
                              ),
                            ),
                            icon: const Icon(
                              Icons.arrow_drop_down_rounded,
                              color: Color(0xFF059669),
                              size: 20,
                            ),
                            items: List.generate(60, (m) {
                              return DropdownMenuItem<int>(
                                value: m,
                                enabled: !timeOnDay(
                                  currentHour,
                                  m,
                                ).isBefore(earliest),
                                child: Text(
                                  '${m.toString().padLeft(2, '0')} phút',
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                    color: Color(0xFF1E293B),
                                  ),
                                ),
                              );
                            }).where((item) => item.enabled).toList(),
                            onChanged: (newMinute) {
                              if (newMinute == null) return;
                              final selected = timeOnDay(
                                currentHour,
                                newMinute,
                              );
                              if (selected.isBefore(earliestSchedule())) return;
                              edit(() => d.scheduledAt = selected);
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Quick presets
                const Text(
                  'Khung giờ phổ biến',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: presets
                      .where((preset) {
                        final parts = preset.split(':');
                        return !timeOnDay(
                          int.parse(parts[0]),
                          int.parse(parts[1]),
                        ).isBefore(earliest);
                      })
                      .map((preset) {
                        final isSelected = currentTimeStr == preset;
                        final parts = preset.split(':');
                        final selected = timeOnDay(
                          int.parse(parts[0]),
                          int.parse(parts[1]),
                        );
                        final available = !selected.isBefore(earliest);
                        return InkWell(
                          onTap: available
                              ? () {
                                  if (selected.isBefore(earliestSchedule()))
                                    return;
                                  edit(() => d.scheduledAt = selected);
                                }
                              : null,
                          borderRadius: BorderRadius.circular(20),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFF059669)
                                  : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xFF059669)
                                    : const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Text(
                              preset,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: !available
                                    ? const Color(0xFFCBD5E1)
                                    : isSelected
                                    ? Colors.white
                                    : const Color(0xFF334155),
                              ),
                            ),
                          ),
                        );
                      })
                      .toList(),
                ),
              ],
            ),
          ),
        ];
      case 3:
        final addresses = c.data!.addresses;
        return [
          if (addresses.isEmpty)
            const EmptyState(
              'Chưa có địa chỉ',
              'Thêm địa chỉ để tiếp tục đặt dịch vụ.',
            ),
          ...addresses
              .where(
                (a) =>
                    !addresses.any((item) => item.id == d.addressId) ||
                    a.id == d.addressId,
              )
              .map((a) {
                final isSelected = d.addressId == a.id;
                final fullAddress = [
                  a.detail,
                  if (a.ward.isNotEmpty) a.ward,
                  if (a.district.isNotEmpty) a.district,
                  if (a.city.isNotEmpty) a.city,
                ].where((s) => s.trim().isNotEmpty).join(', ');

                if (isSelected) {
                  return bookingAddressCard(
                    a,
                    onEdit: () => editBookingAddress(a),
                  );
                }

                // Unselected address card
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: InkWell(
                    onTap: () => edit(() => d.addressId = a.id),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x04000000),
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: const Icon(
                              Icons.location_on_outlined,
                              size: 18,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Wrap(
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  spacing: 8,
                                  runSpacing: 4,
                                  children: [
                                    Text(
                                      a.label,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15,
                                        color: Color(0xFF1E293B),
                                      ),
                                    ),
                                    if (a.isDefault)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFDCFCE7),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: const Text(
                                          'Mặc định',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF15803D),
                                          ),
                                        ),
                                      ),
                                    if (a.buildingType.isNotEmpty)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF1F5F9),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: Text(
                                          'Loại: ${a.buildingType}',
                                          style: const TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF475569),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  fullAddress.isNotEmpty
                                      ? fullAddress
                                      : a.detail,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF64748B),
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (a.contactName.isNotEmpty ||
                                    a.contactPhone.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    '${a.contactName.isNotEmpty ? a.contactName : ''}${a.contactName.isNotEmpty && a.contactPhone.isNotEmpty ? ' • ' : ''}${a.contactPhone}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF94A3B8),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.radio_button_unchecked_rounded,
                            color: Color(0xFFCBD5E1),
                            size: 22,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: saving ? null : () => editBookingAddress(null),
              icon: const Icon(
                Icons.add_location_alt_outlined,
                color: Color(0xFF059669),
              ),
              label: const Text(
                'Thêm địa chỉ mới',
                style: TextStyle(
                  color: Color(0xFF059669),
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF059669)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x06000000),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.sticky_note_2_outlined,
                        size: 20,
                        color: Color(0xFF059669),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Lưu ý cho Đối tác / Partner',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Ghi chú chỉ dẫn hoặc yêu cầu đặc biệt khi đến làm',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: d.notes,
                  maxLines: 3,
                  maxLength: 2000,
                  decoration: InputDecoration(
                    labelText: 'Nội dung ghi chú cho thợ / đối tác',
                    floatingLabelBehavior: FloatingLabelBehavior.always,
                    labelStyle: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w600,
                    ),
                    floatingLabelStyle: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF059669),
                      fontWeight: FontWeight.w700,
                    ),
                    hintText: 'Ví dụ: Gọi trước khi đến 15 phút, gửi xe tại hầm B1, bấm chuông phòng...',
                    hintStyle: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF94A3B8),
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.all(12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color(0xFF059669),
                        width: 1.5,
                      ),
                    ),
                  ),
                  onChanged: (v) => edit(() => d.notes = v),
                ),
              ],
            ),
          ),
        ];
      default:
        final address = c.data!.addresses
            .where((a) => a.id == d.addressId)
            .firstOrNull;
        return [
          reviewSection(
            'Dịch vụ đã chọn',
            () => _showEditServicesSheet(context),
            [
              ...selectedServices.asMap().entries.map((entry) {
                final idx = entry.key;
                final s = entry.value;
                final serviceSchema = schemas
                    .where((schema) => schema.serviceSlugs.contains(s.slug))
                    .firstOrNull;
                final prefix = s.id == d.serviceId ? '' : '${s.id}_';
                final description =
                    (d.details['service_desc_${s.id}'] ??
                            (s.id == d.serviceId ? d.description : ''))
                        .toString()
                        .trim();
                final fields = serviceSchema?.fields ?? [];

                final expanded =
                    selectedServices.length == 1 ||
                    expandedServiceIds.contains(s.id);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        '#${idx + 1} ${s.name}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text('${money(s.hourlyRate)}${s.priceUnit}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Xóa dịch vụ',
                            onPressed: saving
                                ? null
                                : () => confirmRemoveService(s),
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Color(0xFFDC2626),
                            ),
                          ),
                          if (selectedServices.length > 1)
                            Icon(
                              expanded ? Icons.expand_less : Icons.expand_more,
                            ),
                        ],
                      ),
                      onTap: selectedServices.length == 1
                          ? null
                          : () => setState(() {
                              final wasExpanded = expandedServiceIds.contains(
                                s.id,
                              );
                              expandedServiceIds.clear();
                              if (!wasExpanded) expandedServiceIds.add(s.id);
                            }),
                    ),
                    if (expanded) ...[
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () => _showEditServiceDetailsSheet(
                            context,
                            serviceId: s.id,
                          ),
                          icon: const Icon(Icons.edit_outlined, size: 16),
                          label: const Text('Chỉnh sửa thông tin'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (fields.isEmpty && description.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 8),
                          child: Text(
                            'Chưa có yêu cầu chi tiết nào.',
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        )
                      else ...[
                        for (final f in fields)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 4,
                                  child: Text(
                                    f.label,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  flex: 5,
                                  child: Text(
                                    '${d.details['$prefix${f.key}'] ?? 'Chưa có'}',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF0F172A),
                                    ),
                                    textAlign: TextAlign.end,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (description.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(top: 4, bottom: 8),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.speaker_notes_outlined,
                                  size: 16,
                                  color: Color(0xFF64748B),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Mô tả bổ sung:',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF475569),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        description,
                                        style: const TextStyle(
                                          fontSize: 12.5,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ],
                    if (idx < selectedServices.length - 1) const Divider(),
                  ],
                );
              }),
            ],
            actionLabel: 'Thêm dịch vụ',
          ),
          reviewSection('Lịch hẹn', () => _showEditScheduleSheet(context), [
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.calendar_month_rounded,
                              size: 16,
                              color: Color(0xFFD97706),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Ngày thực hiện',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFFB45309),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          d.scheduledAt == null
                              ? 'Chưa chọn'
                              : dateLabel(d.scheduledAt!),
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF78350F),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.access_time_rounded,
                              size: 16,
                              color: Color(0xFF2563EB),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Giờ bắt đầu',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1D4ED8),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          d.scheduledAt == null
                              ? 'Chưa chọn'
                              : timeLabel(d.scheduledAt!),
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1E3A8A),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ]),
          reviewSection(
            'Địa chỉ và liên hệ',
            () => _showEditAddressAndNotesSheet(context),
            [
              if (address == null)
                const Text(
                  'Vui lòng chọn lại địa chỉ',
                  style: TextStyle(color: Color(0xFFDC2626)),
                )
              else ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.place_rounded,
                        size: 18,
                        color: Color(0xFFDC2626),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              Text(
                                address.label,
                                style: const TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              if (address.isDefault)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFDCFCE7),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'Địa chỉ mặc định',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF15803D),
                                    ),
                                  ),
                                ),
                              if (address.buildingType.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'Loại: ${address.buildingType}',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF475569),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            [
                              address.detail,
                              if (address.ward.isNotEmpty) address.ward,
                              if (address.district.isNotEmpty) address.district,
                              if (address.city.isNotEmpty) address.city,
                            ].where((s) => s.trim().isNotEmpty).join(', '),
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF334155),
                              height: 1.35,
                            ),
                          ),
                          if (address.buildingDescription.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              'Vị trí: ${address.buildingDescription}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                          if (address.contactName.isNotEmpty ||
                              address.contactPhone.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              '${address.contactName.isNotEmpty ? address.contactName : ''}${address.contactName.isNotEmpty && address.contactPhone.isNotEmpty ? ' • ' : ''}${address.contactPhone}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                if (d.notes.isNotEmpty || address.note.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.speaker_notes_outlined,
                          size: 16,
                          color: Color(0xFF64748B),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Lưu ý cho Đối tác / Partner:',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF475569),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                d.notes.isNotEmpty ? d.notes : address.note,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ],
          ),
          if (quote != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFA7F3D0)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x08000000),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.receipt_long_rounded,
                        color: Color(0xFF059669),
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Chi tiết báo giá',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF065F46),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  for (final item in quote!.items) ...[
                    Text(
                      item.serviceName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF065F46),
                      ),
                    ),
                    const SizedBox(height: 5),
                    if (item.mode != 'FIXED')
                      Text(
                        '${money(item.unitAmount)} × ${item.quantity} ${item.quantityLabel}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF475569),
                        ),
                      ),
                    if (item.baseAmount > 0 && item.mode != 'FIXED')
                      Text(
                        'Phí cơ bản: ${money(item.baseAmount)}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Tiền dịch vụ',
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                        Text(
                          money(item.subtotal),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    if (item.mode == 'HOURLY')
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          'Giá ${item.serviceName} tạm tính theo ${item.quantity} giờ. Bạn cần trao đổi và thống nhất lại thời gian, chi phí với Partner (người giúp) trước khi thực hiện.',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFFB45309),
                            height: 1.4,
                          ),
                        ),
                      ),
                    const Divider(height: 22, color: Color(0xFFA7F3D0)),
                  ],
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Tổng tiền dịch vụ',
                          style: TextStyle(
                            fontSize: 13.5,
                            color: Color(0xFF334155),
                          ),
                        ),
                      ),
                      Text(
                        money(quote!.subtotal),
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Divider(color: Color(0xFF6EE7B7), height: 1),
                  ),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Tổng cộng',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ),
                      Text(
                        money(quote!.total),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF059669),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ],
          const Spacer(),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: saving ? null : () => setState(() => step--),
            icon: const Icon(Icons.arrow_back, size: 18),
            label: const Text('Quay lại bước trước'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 12),
          PrimaryButton(
            quote == null
                ? (_hasQuoted ? 'Cập nhật giá' : 'Lấy báo giá')
                : 'Xác nhận giá',
            saving
                ? null
                : quote == null
                ? requestQuote
                : confirmQuote,
          ),
        ];
    }
  }
}
