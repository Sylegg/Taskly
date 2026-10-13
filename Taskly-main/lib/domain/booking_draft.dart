import 'dart:math';

class BookingField {
  const BookingField(
    this.key,
    this.label,
    this.type,
    this.required,
    this.minimum,
    this.options,
  );
  final String key, label, type;
  final bool required;
  final int? minimum;
  final List<String> options;
  factory BookingField.fromJson(Map<String, dynamic> json) => BookingField(
    json['key'],
    json['label'],
    json['type'],
    json['required'] == true,
    (json['minimum'] as num?)?.toInt(),
    List<String>.from(json['options'] ?? []),
  );
}

class BookingSchema {
  const BookingSchema(
    this.key,
    this.version,
    this.fields, {
    this.serviceSlugs = const [],
  });
  final String key;
  final int version;
  final List<BookingField> fields;
  final List<String> serviceSlugs;
  factory BookingSchema.fromJson(Map<String, dynamic> json) => BookingSchema(
    json['key'],
    json['version'],
    (json['fields'] as List)
        .map((f) => BookingField.fromJson(Map<String, dynamic>.from(f)))
        .toList(),
    serviceSlugs: List<String>.from(json['serviceSlugs'] ?? []),
  );
  String? validate(Map<String, dynamic> values) {
    for (final field in fields) {
      final value = values[field.key];
      if (value == null || value.toString().trim().isEmpty) {
        if (field.required) {
          return 'Vui lòng nhập ${field.label.toLowerCase()}.';
        }
        continue;
      }
      if (field.type == 'number') {
        final number = int.tryParse(value.toString());
        if (number == null ||
            number < (field.minimum ?? 0) ||
            number > 100000000) {
          return '${field.label} cần là số nguyên từ ${field.minimum ?? 0} đến 100000000.';
        }
      }
      if (field.type == 'choice' && !field.options.contains(value)) {
        return 'Vui lòng chọn ${field.label.toLowerCase()} hợp lệ.';
      }
    }
    if (key == 'move' &&
        values['pickup'].toString().trim().toLowerCase() ==
            values['dropoff'].toString().trim().toLowerCase()) {
      return 'Địa chỉ đi và đến phải khác nhau.';
    }
    return null;
  }
}

class CustomerBookingDraft {
  CustomerBookingDraft({
    this.serviceId = '',
    this.schemaKey = '',
    this.schemaVersion = 1,
    Map<String, dynamic>? details,
    this.addressId = '',
    this.scheduledAt,
    this.duration = 2,
    this.description = '',
    this.notes = '',
  }) : details = details ?? {};
  String? pendingId;
  String serviceId, schemaKey, addressId, description, notes;
  int schemaVersion, duration;
  DateTime? scheduledAt;
  final Map<String, dynamic> details;

  List<String> get selectedServiceIds {
    final list = details['selectedServiceIds'];
    if (list is List) {
      final ids = list
          .map((e) => e.toString())
          .where((e) => e.isNotEmpty)
          .toList();
      if (ids.isNotEmpty) return ids;
    }
    return serviceId.isNotEmpty ? [serviceId] : [];
  }

  set selectedServiceIds(List<String> ids) {
    details['selectedServiceIds'] = ids;
    if (ids.isNotEmpty) {
      serviceId = ids.first;
    } else {
      serviceId = '';
    }
  }

  factory CustomerBookingDraft.fromJson(Map<String, dynamic> json) =>
      CustomerBookingDraft(
        serviceId: json['serviceId'] ?? '',
        schemaKey: json['schemaKey'] ?? '',
        schemaVersion: json['schemaVersion'] ?? 1,
        details: Map<String, dynamic>.from(json['details'] ?? {}),
        addressId: json['addressId'] ?? '',
        scheduledAt: DateTime.tryParse(json['scheduledAt'] ?? '')?.toLocal(),
        duration: json['duration'] ?? 2,
        description: json['description'] ?? '',
        notes: json['notes'] ?? '',
      );
  String get quoteSessionId {
    return details.putIfAbsent('quoteSessionId', () {
      final random = Random.secure();
      final bytes = List<int>.generate(16, (_) => random.nextInt(256));
      bytes[6] = (bytes[6] & 15) | 64;
      bytes[8] = (bytes[8] & 63) | 128;
      final hex = bytes.map((value) => value.toRadixString(16).padLeft(2, '0')).join();
      return '${hex.substring(0,8)}-${hex.substring(8,12)}-${hex.substring(12,16)}-${hex.substring(16,20)}-${hex.substring(20)}';
    }).toString();
  }
  Map<String, dynamic> toJson() { quoteSessionId; return {
    'serviceId': serviceId,
    'schemaKey': schemaKey,
    'schemaVersion': schemaVersion,
    'details': details,
    'addressId': addressId,
    'scheduledAt': scheduledAt?.toUtc().toIso8601String(),
    'duration': duration,
    'description': description,
    'notes': notes,
  }; }
}

abstract interface class CustomerBookingDrafts {
  Future<List<BookingSchema>> bookingSchemas();
  Future<CustomerBookingDraft?> restoreBookingDraft();
  Future<void> saveBookingDraft(CustomerBookingDraft draft);
  Future<void> deleteBookingDraft();
  Future<CustomerQuote> requestBookingQuote(CustomerBookingDraft draft);
}

class CustomerQuoteItem {
  CustomerQuoteItem.fromJson(Map<String, dynamic> json)
    : serviceName = json['serviceName'] ?? 'Dịch vụ',
      mode = json['mode'] ?? '',
      quantityLabel = json['quantityLabel'] ?? '',
      quantity = (json['quantity'] as num).toInt(),
      baseAmount = (json['baseAmount'] as num).toInt(),
      unitAmount = (json['unitAmount'] as num).toInt(),
      subtotal = (json['subtotal'] as num).toInt(),
      platformFee = (json['platformFee'] as num).toInt(),
      platformFeePercent = json['platformFeePercent'] as num?,
      total = (json['total'] as num).toInt();
  final String serviceName, mode, quantityLabel;
  final int quantity, baseAmount, unitAmount, subtotal, platformFee, total;
  final num? platformFeePercent;
}

class CustomerQuote {
  const CustomerQuote(
    this.id,
    this.subtotal,
    this.platformFee,
    this.total,
    this.currency,
    this.expiresAt, {
    this.items = const [],
  });
  final String id, currency;
  final int subtotal, platformFee, total;
  final DateTime expiresAt;
  final List<CustomerQuoteItem> items;
  factory CustomerQuote.fromJson(Map<String, dynamic> json) => CustomerQuote(
    json['id'],
    (json['subtotal'] as num).toInt(),
    (json['platformFee'] as num).toInt(),
    (json['total'] as num).toInt(),
    json['currency'],
    DateTime.parse(json['expiresAt']).toLocal(),
    items: (json['items'] as List? ?? [])
        .map(
          (item) => CustomerQuoteItem.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList(),
  );
}

abstract interface class CustomerPendingBookings {
  Future<List<CustomerBookingDraft>> pendingBookings();
  Future<void> savePendingBooking(CustomerBookingDraft draft);
  Future<void> deletePendingBooking(String id);
}
