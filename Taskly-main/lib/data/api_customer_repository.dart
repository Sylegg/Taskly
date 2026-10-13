import '../auth/api.dart';
import '../domain/models.dart';
import '../domain/booking_draft.dart';
import '../domain/repository_updates.dart';
import 'mock/mock_customer_repository.dart';

/// Account operations use the authenticated backend. Unimplemented task actions
/// fail explicitly instead of generating successful transactions in memory.
class ApiCustomerRepository extends MockCustomerRepository
    implements
        CustomerBookingDrafts,
        CustomerPendingBookings,
        CatalogueRefresh {
  ApiCustomerRepository(this.session) : super(latency: Duration.zero) {
    store.authenticated = true;
    store.catalogueOverride = [];
    store.taskersOverride = [];
    store.addresses = [];
    store.methods = [];
    store.tasks = [];
    store.conversations = [];
    store.notifications = [];
    store.complaints = [];
  }
  final Session session;
  int refundBalance = 0;
  bool bookingLimitReached = false;
  Future<void> refreshBookingCapacity() async {
    final capacity = await session.request('/users/me/booking-capacity');
    bookingLimitReached = capacity['canCreate'] != true;
  }

  @override
  Stream<void> get changes => session.liveChanges;
  @override
  Future<CustomerSnapshot> refreshCatalogue() async {
    final catalogue = await session.request('/public/services');
    updateCatalogue(catalogue);
    await loadBanners();
    await loadArticles();
    return store.snapshot();
  }

  Future<void> loadArticles() async {
    dynamic response;
    try {
      response = await session.request('/public/articles');
    } on ApiFailure catch (e) {
      if (e.status == 404) {
        store.articles = [];
        return;
      }
      rethrow;
    }
    if (response is! List) {
      throw const RepositoryFailure('Dữ liệu cộng đồng không hợp lệ.');
    }
    store.articles = response
        .map(
          (a) => CommunityArticle(
            id: a['id'].toString(),
            title: a['title'],
            summary: a['summary'] ?? '',
            content: a['content'],
            imageUrl: session.api.publicAssetUrl(a['imageUrl'] as String?),
            createdAt: DateTime.parse(a['createdAt']),
            authorName: a['authorName'] ?? 'TaskLy',
            hashtag: a['hashtag'] ?? 'TaskLyNews',
            groupName: a['groupName'] ?? '',
            featured: a['featured'] == true,
          ),
        )
        .toList();
  }

  Future<void> loadBanners() async {
    dynamic response;
    try {
      response = await session.request('/public/banners');
    } on ApiFailure catch (e) {
      if (e.status == 404) {
        store.banners = [];
        return;
      }
      rethrow;
    }
    if (response is! List) {
      throw const RepositoryFailure('Dữ liệu banner không hợp lệ.');
    }
    store.banners = response
        .map(
          (b) => HomeBanner(
            id: b['id'].toString(),
            title: b['title'] ?? '',
            imageUrl: session.api.publicAssetUrl(b['imageUrl'] as String?),
          ),
        )
        .where((b) => b.imageUrl.isNotEmpty)
        .toList();
  }

  void updateCatalogue(dynamic catalogue) {
    store.categories = ((catalogue['categories'] ?? []) as List)
        .map(
          (c) => ServiceCategory(
            id: c['id'].toString(),
            name: c['name'],
            slug: c['slug'],
            iconKey: c['iconKey'] ?? '',
            iconUrl: session.api.publicAssetUrl(c['iconUrl'] as String?),
          ),
        )
        .toList();
    store.catalogueOverride = ((catalogue['services'] ?? []) as List)
        .where((s) => s['currency'] == 'VND')
        .map(
          (s) => Service(
            s['id'].toString(),
            s['name'],
            s['shortDescription'] ?? '',
            (s['iconKey'] as String?)?.trim().isNotEmpty == true
                ? (s['iconKey'] as String).trim()
                : s['slug'],
            s['pricing']?['enabled'] == true
                ? ((s['pricing']['mode'] == 'FIXED'
                              ? s['pricing']['baseAmount']
                              : s['pricing']['unitAmount'])
                          as num)
                      .toInt()
                : 0,
            s['description'] ?? '',
            [],
            slug: s['slug'],
            priceUnit: s['pricing']?['mode'] == 'HOURLY'
                ? '/giờ'
                : s['pricing']?['mode'] == 'FIELD'
                ? '/đơn vị'
                : '',
            currency: s['currency'],
            iconUrl: session.api.publicAssetUrl(s['iconUrl'] as String?),
            popular: s['popular'] == true,
            categoryId: s['category']?['id']?.toString() ?? '',
          ),
        )
        .toList();
  }

  List<Map<String, dynamic>> reviews = [];
  int totalTasks = 0, completedTasks = 0;
  Future<dynamic> request(
    String path, {
    String method = 'GET',
    Map<String, dynamic>? body,
  }) async {
    try {
      return await session.request(
        '/users/me$path',
        method: method,
        body: body,
      );
    } on ApiFailure catch (e) {
      throw RepositoryFailure(e.message);
    }
  }

  // Older backends do not expose these account sections yet. Only an
  // explicitly missing endpoint may use an empty section; real failures
  // (authentication, network, server errors) must still reach the caller.
  Future<dynamic> optionalSection(String path, dynamic fallback) async {
    try {
      return await session.request('/users/me$path');
    } on ApiFailure catch (e) {
      if (e.status == 404) return fallback;
      throw RepositoryFailure(e.message);
    }
  }

  @override
  Future<CustomerSnapshot> load() async {
    await refreshBookingCapacity();
    final results = await Future.wait([
      request(''),
      request('/addresses'),
      optionalSection('/payment-methods', <dynamic>[]),
      optionalSection('/settings', {'notificationsEnabled': false}),
      optionalSection('/reviews', <dynamic>[]),
      optionalSection('/statistics', <String, dynamic>{}),
      session.request('/public/services'),
      optionalSection('/helpers', <dynamic>[]),
      optionalSection('/favorite-helpers', <dynamic>[]),
      optionalSection('/booking-notifications', <dynamic>[]),
      optionalSection('/refund-balance', {'amount': 0}),
    ]);
    refundBalance = ((results[10] as Map)['amount'] as num?)?.toInt() ?? 0;
    store.notifications = (results[9] as List)
        .map(
          (n) => AppNotification(
            n['id'].toString(),
            n['title'].toString(),
            (n['taskId'] ?? n['taskid'] ?? '').toString(),
            DateTime.parse(n['at'].toString()),
            read: (n['readAt'] ?? n['readat']) != null,
          ),
        )
        .toList();
    await loadBanners();
    await loadArticles();
    final profile = results[0] as Map;
    store.profile = Profile(
      profile['fullName'] ?? '',
      profile['phone'] ?? '',
      profile['email'] ?? '',
      '',
      nameLocked: profile['nameLocked'] == true,
    );
    store.addresses = (results[1] as List)
        .map(
          (a) => Address(
            a['id'].toString(),
            a['label'],
            a['addressLine'],
            a['notes'] ?? '',
            city: a['city'] ?? '',
            isDefault: a['defaultAddress'] == true,
            contactName: a['recipientName'] ?? a['contactName'] ?? '',
            contactPhone: a['recipientPhone'] ?? a['contactPhone'] ?? '',
            buildingType: a['buildingType'] ?? '',
            buildingDescription: a['buildingDescription'] ?? '',
            ward: a['ward'] ?? '',
            district: a['district'] ?? '',
            latitude: (a['latitude'] as num?)?.toDouble(),
            longitude: (a['longitude'] as num?)?.toDouble(),
          ),
        )
        .toList();
    store.methods = (results[2] as List)
        .map(
          (m) => PaymentMethod(
            m['id'].toString(),
            m['name'],
            m['detail'],
            kind: m['kind'],
            isDefault: m['isDefault'] == true,
          ),
        )
        .toList();
    store.notificationEnabled = results[3]['notificationsEnabled'] == true;
    reviews = (results[4] as List)
        .map((r) => Map<String, dynamic>.from(r))
        .toList();
    totalTasks = (results[5]['total'] as num?)?.toInt() ?? 0;
    completedTasks = (results[5]['completed'] as num?)?.toInt() ?? 0;
    updateCatalogue(results[6]);
    final helpers = results[7] is List ? results[7] as List : const [];
    store.taskersOverride = helpers
        .map(
          (t) => Tasker(
            t['id'].toString(),
            t['name'] ?? '',
            '',
            0,
            0,
            0,
            0,
            t['bio'] ?? '',
            '',
          ),
        )
        .toList();
    final favs = results[8] is List ? results[8] as List : const [];
    store.favoriteHelperIds
      ..clear()
      ..addAll(favs.map((t) => t['id'].toString()));
    return store.snapshot();
  }

  @override
  Future<void> setHelperFavorite(String id, bool favorite) async {
    await request('/favorite-helpers/$id', method: favorite ? 'PUT' : 'DELETE');
  }

  Future<void> changePassword(String current, String next) async {
    await request(
      '/change-password',
      method: 'POST',
      body: {'currentPassword': current, 'newPassword': next},
    );
  }

  @override
  Future<void> saveProfile(String name, String phone, String email) async {
    if (store.profile.email.isNotEmpty &&
        email.trim().isNotEmpty &&
        email.trim() != store.profile.email.trim()) {
      throw const RepositoryFailure('Không thể thay đổi email đã đăng ký.');
    }
    final trimmedPhone = phone.trim();
    if (name.trim().length < 2 ||
        !RegExp(r'^0[0-9]{9}$').hasMatch(trimmedPhone)) {
      throw const RepositoryFailure(
        'Kiểm tra họ tên (tối thiểu 2 ký tự) và số điện thoại (10 chữ số bắt đầu bằng 0).',
      );
    }
    final res = await request(
      '/profile',
      method: 'PATCH',
      body: {
        'fullName': name.trim(),
        'phone': trimmedPhone,
        'language': session.user?['language'] ?? 'vi',
      },
    );
    final newPhone = (res is Map<String, dynamic> && res['phone'] != null)
        ? res['phone'].toString()
        : trimmedPhone;
    final newName = (res is Map<String, dynamic> && res['fullName'] != null)
        ? res['fullName'].toString()
        : name.trim();
    store.profile = Profile(
      newName,
      newPhone,
      store.profile.email,
      store.profile.avatar,
      nameLocked: store.profile.nameLocked,
    );
    if (session.user != null) {
      session.user!['fullName'] = newName;
      session.user!['phone'] = newPhone;
    }
  }

  @override
  Future<void> saveAddress(Address address) async {
    final a = address;
    await request(
      '/addresses${a.id.isEmpty ? '' : '/${a.id}'}',
      method: a.id.isEmpty ? 'POST' : 'PUT',
      body: {
        'label': a.label.trim(),
        'addressLine': a.detail.trim(),
        'notes': a.note.trim(),
        'city': a.city.trim(),
        'defaultAddress': a.isDefault,
        'recipientName': a.contactName.trim(),
        'recipientPhone': a.contactPhone.trim(),
        'buildingType': a.buildingType.trim(),
        'buildingDescription': a.buildingDescription.trim(),
        'ward': a.ward,
        'district': a.district,
        if (a.latitude != null) 'latitude': a.latitude,
        if (a.longitude != null) 'longitude': a.longitude,
      },
    );
  }

  @override
  Future<void> deleteAddress(String id) async {
    await request('/addresses/$id', method: 'DELETE');
  }

  @override
  Future<void> setDefaultAddress(String id) async {
    await request('/addresses/$id/default', method: 'POST');
  }

  @override
  Future<void> addPaymentMethod(
    String name,
    String detail, {
    String kind = 'CASH',
  }) async {
    await request(
      '/payment-methods',
      method: 'POST',
      body: {'name': name.trim(), 'detail': detail.trim(), 'kind': kind},
    );
  }

  @override
  Future<void> removePaymentMethod(String id) async {
    await request('/payment-methods/$id', method: 'DELETE');
  }

  @override
  Future<void> setDefaultPaymentMethod(String id) async {
    await request('/payment-methods/$id/default', method: 'POST');
  }

  @override
  Future<void> setNotifications(bool enabled) async {
    await request(
      '/settings',
      method: 'PUT',
      body: {'notificationsEnabled': enabled},
    );
  }

  @override
  Future<TaskDraft> newDraft() async {
    if (store.catalogueOverride!.isEmpty) {
      throw const RepositoryFailure(
        'Chưa có dịch vụ khả dụng. Vui lòng thử lại sau.',
      );
    }
    final draft = TaskDraft(
      serviceId: store.catalogueOverride!.first.id,
      address:
          store.addresses.where((a) => a.isDefault).firstOrNull ??
          store.addresses.firstOrNull ??
          const Address('', 'Địa chỉ mới', '', ''),
      scheduledAt: DateTime.now().add(const Duration(days: 1)),
    );
    draft.paymentMethodId =
        store.methods.where((m) => m.isDefault).firstOrNull?.id ??
        store.methods.firstOrNull?.id ??
        '';
    return draft;
  }

  Future<Never> unavailable() async => throw const RepositoryFailure(
    'Chức năng này chưa có API. Không có thay đổi hay giao dịch nào được thực hiện.',
  );
  @override
  Future<PriceBreakdown> quote(TaskDraft draft) => unavailable();
  @override
  Future<PriceSuggestion> priceSuggestion(TaskDraft draft) => unavailable();
  @override
  Future<TaskDraft> suggestDraft(String prompt) => unavailable();
  @override
  Future<List<Tasker>> findTaskers(String taskId) => unavailable();
  @override
  Future<void> match(String taskId, String taskerId) => unavailable();
  @override
  Future<void> cancel(String taskId, String reason) => unavailable();
  @override
  Future<void> reschedule(String taskId, DateTime time) => unavailable();
  @override
  Future<void> sendMessage(String conversationId, String text) => unavailable();
  @override
  Future<void> readConversation(String id) => unavailable();
  @override
  Future<void> readNotification(String id) async {
    await request('/booking-notifications/$id/read', method: 'POST');
    store.notifications = store.notifications
        .map(
          (n) => n.id == id
              ? AppNotification(
                  n.id,
                  n.title,
                  n.taskId,
                  n.at,
                  read: true,
                  complaintId: n.complaintId,
                )
              : n,
        )
        .toList();
    store.changed();
  }

  Future<void> readAllNotifications() async {
    try {
      await request('/booking-notifications/read-all', method: 'POST');
    } catch (_) {}
    store.notifications = store.notifications
        .map(
          (n) => AppNotification(
            n.id,
            n.title,
            n.taskId,
            n.at,
            read: true,
            complaintId: n.complaintId,
          ),
        )
        .toList();
    store.changed();
  }

  Future<void> reloadNotifications() async {
    try {
      final res = await optionalSection('/booking-notifications', <dynamic>[]);
      store.notifications = (res as List)
          .map(
            (n) => AppNotification(
              n['id'].toString(),
              n['title'].toString(),
              (n['taskId'] ?? n['taskid'] ?? '').toString(),
              DateTime.parse(n['at'].toString()),
              read: (n['readAt'] ?? n['readat']) != null,
            ),
          )
          .toList();
      store.changed();
    } catch (_) {}
  }

  @override
  Future<String> submitComplaint(
    String taskId,
    String issue,
    String description,
    List<String> evidence,
  ) => unavailable();
  @override
  Future<void> sendOtp(String phone) => unavailable();
  @override
  Future<void> verifyOtp(String code) => unavailable();
  @override
  Future<List<BookingSchema>> bookingSchemas() async {
    try {
      final result = await session.request('/public/booking-schemas');
      return (result as List)
          .map((s) => BookingSchema.fromJson(Map<String, dynamic>.from(s)))
          .toList();
    } on ApiFailure catch (e) {
      throw RepositoryFailure(e.message);
    }
  }

  @override
  Future<List<CustomerBookingDraft>> pendingBookings() async {
    try {
      final result = await request('/pending-bookings');
      if (result is List) {
        return result
            .map(
              (item) => CustomerBookingDraft.fromJson(
                Map<String, dynamic>.from(item['draft'] ?? item),
              )..pendingId = item['id']?.toString(),
            )
            .toList();
      }
    } catch (_) {}
    return [];
  }

  @override
  Future<void> deletePendingBooking(String id) async {
    try {
      await request('/pending-bookings/$id', method: 'DELETE');
    } catch (_) {}
  }

  @override
  Future<void> savePendingBooking(CustomerBookingDraft draft) async {
    draft.pendingId ??= 'booking-${DateTime.now().microsecondsSinceEpoch}';
    await request(
      '/pending-bookings/${draft.pendingId}',
      method: 'PUT',
      body: draft.toJson(),
    );
  }

  @override
  Future<CustomerBookingDraft?> restoreBookingDraft() async {
    final result = await request('/booking-draft');
    return result == null
        ? null
        : CustomerBookingDraft.fromJson(Map<String, dynamic>.from(result));
  }

  @override
  Future<void> saveBookingDraft(CustomerBookingDraft draft) async {
    try {
      await savePendingBooking(draft);
    } catch (_) {}
    await request('/booking-draft', method: 'PUT', body: draft.toJson());
  }

  @override
  Future<void> deleteBookingDraft() async {
    await request('/booking-draft', method: 'DELETE');
  }

  @override
  Future<CustomerQuote> requestBookingQuote(CustomerBookingDraft draft) async {
    final result = await request(
      '/booking-quotes',
      method: 'POST',
      body: draft.toJson(),
    );
    return CustomerQuote.fromJson(Map<String, dynamic>.from(result));
  }

  @override
  Future<String> post(TaskDraft draft, String requestId) async =>
      throw const RepositoryFailure(
        'API đặt công việc chưa được kết nối trong bản này.',
      );
  @override
  Future<void> pay(String taskId, String methodId) async =>
      throw const RepositoryFailure(
        'Chưa kết nối cổng thanh toán. Không có khoản tiền nào được thu.',
      );
  @override
  Future<void> signOut() => session.logout();
  @override
  Future<void> rate(
    String taskId,
    int stars,
    String comment, {
    Map<String, int> categories = const {},
    List<String> tags = const [],
  }) async {
    await request(
      '/reviews/$taskId',
      method: 'POST',
      body: {'stars': stars, 'comment': comment},
    );
  }
}
