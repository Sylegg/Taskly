import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/customer_controller.dart';
import '../auth/api.dart';
import '../data/api_customer_repository.dart';
import '../core/theme.dart';
import '../domain/models.dart';
import '../domain/task_policy.dart';
import '../shared/widgets.dart';
import '../shared/service_symbol.dart';
import '../shared/vietnamese_banks.dart';
import 'home/customer_home.dart';
import 'home/home_components.dart';
import 'customer_booking.dart';
import 'booking_draft_activity.dart';
import 'community_screens.dart';
import 'task_activity.dart';
import 'task_chat.dart';
import 'customer_activity.dart';
import 'customer_community.dart';
import 'customer_notifications.dart';
import '../domain/booking_draft.dart';

part 'booking_screens.dart';
part 'task_screens.dart';
part 'account_screens.dart';
part 'customer_wallet.dart';

class CustomerView extends StatefulWidget {
  const CustomerView({
    super.key,
    required this.controller,
    this.onOpenTasker,
    this.onLogout,
    this.homeOffline = false,
    this.onHomeRetry,
  });
  final CustomerController controller;
  final VoidCallback? onOpenTasker;
  final Future<void> Function()? onLogout;
  final bool homeOffline;
  final Future<void> Function()? onHomeRetry;
  @override
  State<CustomerView> createState() => _CustomerViewState();
}

class _CustomerViewState extends State<CustomerView> {
  bool _discoverHelpers = false;
  void _selectHelperTab(bool discover) {
    setState(() => _discoverHelpers = discover);
  }

  CustomerController get c => widget.controller;
  CustomerSnapshot get data => c.data!;
  @override
  void initState() {
    super.initState();
    c.addListener(_bookingLimitChanged);
    c.initialize();
  }

  int _lastBookingLimitNotice = 0;
  bool _bookingLimitDialogOpen = false;
  void _bookingLimitChanged() {
    if (c.bookingLimitNotice == _lastBookingLimitNotice) return;
    _lastBookingLimitNotice = c.bookingLimitNotice;
    if (_bookingLimitDialogOpen) return;
    _bookingLimitDialogOpen = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Đã đạt giới hạn 3 đơn'),
          content: const Text(CustomerController.bookingLimitMessage),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Đã hiểu'))],
        ),
      );
      _bookingLimitDialogOpen = false;
    });
  }
  @override
  void dispose() {
    c.removeListener(_bookingLimitChanged);
    super.dispose();
  }

  static const tabPages = {
    0: PageId.home,
    3: PageId.community,
    1: PageId.tasks,
    4: PageId.profile,
  };
  static const titles = {
    PageId.splash: 'TaskLy',
    PageId.onboarding: 'Chào mừng đến TaskLy',
    PageId.login: 'Đăng nhập',
    PageId.register: 'Tạo tài khoản',
    PageId.recovery: 'Khôi phục truy cập',
    PageId.otp: 'Xác minh số điện thoại',
    PageId.locationPermission: 'Chọn vị trí',
    PageId.home: 'TaskLy',
    PageId.services: 'Dịch vụ',
    PageId.serviceDetail: 'Chi tiết dịch vụ',
    PageId.create: 'Tạo Task',
    PageId.ai: 'TaskLy AI',
    PageId.recommendations: 'Tìm Tasker',
    PageId.tasker: 'Hồ sơ Tasker',
    PageId.matched: 'Ghép thành công',
    PageId.tasks: 'Hoạt động',
    PageId.task: 'Chi tiết công việc',
    PageId.tracking: 'Theo dõi Tasker',
    PageId.payment: 'Nghiệm thu & thanh toán',
    PageId.paymentSuccess: 'Thanh toán thành công',
    PageId.rating: 'Đánh giá Tasker',
    PageId.ratingSuccess: 'Cảm ơn bạn',
    PageId.community: 'Cộng đồng',
    PageId.article: 'Bài viết',
    PageId.messages: 'Chat',
    PageId.chat: 'Cuộc trò chuyện',
    PageId.notifications: 'Thông báo',
    PageId.profile: 'Tài khoản',
    PageId.editProfile: 'Thông tin cá nhân',
    PageId.addresses: 'Địa chỉ đã lưu',
    PageId.paymentMethods: 'Tài khoản ngân hàng',
    PageId.reviews: 'Đánh giá của tôi',
    PageId.settings: 'Cài đặt',
    PageId.favoriteHelpers: 'Người giúp yêu thích',
    PageId.help: 'Trợ giúp & điều khoản',
    PageId.support: 'Hỗ trợ công việc',
    PageId.complaint: 'Gửi khiếu nại',
    PageId.complaintStatus: 'Chi tiết khiếu nại',
  };

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: c,
    builder: (context, _) {
      if (c.route.page == PageId.home) {
        return TaskLyCustomerHome(
          controller: c,
          extras: HomeExtras(offline: widget.homeOffline),
          onRetry: widget.onHomeRetry,
          onOpenTasker: widget.onOpenTasker,
        );
      }
      if (c.route.page == PageId.create &&
          c.repository is CustomerBookingDrafts &&
          c.data != null) {
        return CustomerBooking(controller: c);
      }
      if (c.data == null) {
        return Scaffold(
          body: Center(
            child: c.error == null
                ? const CircularProgressIndicator()
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(c.error!),
                      TextButton(
                        onPressed: c.initialize,
                        child: const Text('Thử lại'),
                      ),
                    ],
                  ),
          ),
        );
      }
      final page = c.route.page;
      if (page == PageId.task &&
          !c.demoMode &&
          c.repository is ApiCustomerRepository &&
          c.route.id != null) {
        return TaskActivityDetail(
          session: (c.repository as ApiCustomerRepository).session,
          id: c.route.id!,
          onBack: c.back,
        );
      }
      if (page == PageId.tasks && !c.demoMode) {
        return CustomerActivity(controller: c);
      }
      if (page == PageId.community && !c.demoMode) {
        return CustomerCommunity(controller: c);
      }
      final shell = [
        PageId.home,
        PageId.tasks,
        PageId.community,
        PageId.profile,
      ].contains(page);
      return PopScope(
        canPop: !c.canBack,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) {
            page == PageId.create ? c.previousStep() : c.back();
          }
        },
        child: Scaffold(
          appBar: AppBar(
            leading: c.canBack
                ? IconButton(
                    tooltip: 'Quay lại',
                    onPressed: c.busy
                        ? null
                        : () {
                            page == PageId.create ? c.previousStep() : c.back();
                          },
                    icon: const Icon(Icons.arrow_back),
                  )
                : (page == PageId.profile
                      ? Padding(
                          padding: const EdgeInsets.only(left: 14),
                          child: Center(
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                gradient: const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xFFDCEAFF),
                                    Color(0xFFF6FAFF),
                                  ],
                                ),
                                border: Border.all(
                                  color: const Color(0xFFD4E2FF),
                                ),
                              ),
                              alignment: Alignment.center,
                              child: const Text(
                                'T',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF245AD3),
                                ),
                              ),
                            ),
                          ),
                        )
                      : const Padding(
                          padding: EdgeInsets.all(14),
                          child: Icon(Icons.task_alt, color: AppColors.primary),
                        )),
            title: page == PageId.profile
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Text(
                        'Tài khoản',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16.5,
                          color: Color(0xFF0F172A),
                          letterSpacing: -0.3,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'TaskLy Customer',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: Color(0xFF7C8CA1),
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  )
                : Text(
                    titles[page] ?? 'TaskLy',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 19,
                    ),
                  ),
            actions: [
              if (c.demoMode && widget.onOpenTasker != null)
                IconButton(
                  tooltip: 'chuyển Tasker',
                  onPressed: c.busy ? null : widget.onOpenTasker,
                  icon: const Icon(Icons.swap_horiz),
                ),
              if (shell)
                IconButton(
                  tooltip: 'Thông báo',
                  onPressed: () => c.open(PageId.notifications),
                  icon: Badge(
                    isLabelVisible: data.notifications.any((n) => !n.read),
                    label: Text(''),
                    child: const Icon(Icons.notifications_none_rounded),
                  ),
                ),
            ],
          ),
          body: SafeArea(
            child: Column(
              children: [
                if (c.busy) const LinearProgressIndicator(minHeight: 3),
                if (c.error != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                    color: Theme.of(context).colorScheme.errorContainer,
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: AppColors.error),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            c.error!,
                            key: const Key('error-message'),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Đóng thông báo lỗi',
                          onPressed: () {
                            c.error = null;
                            c.changed();
                          },
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: c.data == null
                      ? Center(
                          child: c.error == null
                              ? const CircularProgressIndicator()
                              : PrimaryButton('Thử lại', c.initialize),
                        )
                      : AbsorbPointer(
                          absorbing: c.busy,
                          child: Align(
                            alignment: Alignment.topCenter,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 640),
                              child: _shouldPinBottomActions
                                  ? CustomScrollView(
                                      key: ValueKey(
                                        '${page.name}-${c.route.id}-${page == PageId.create ? c.wizardStep : ''}',
                                      ),
                                      keyboardDismissBehavior:
                                          ScrollViewKeyboardDismissBehavior
                                              .onDrag,
                                      slivers: [
                                        SliverPadding(
                                          padding: const EdgeInsets.fromLTRB(
                                            20,
                                            8,
                                            20,
                                            24,
                                          ),
                                          sliver: SliverFillRemaining(
                                            hasScrollBody: false,
                                            child: _buildPinnedScreen(screen()),
                                          ),
                                        ),
                                      ],
                                    )
                                  : ListView(
                                      key: ValueKey(
                                        '${page.name}-${c.route.id}-${page == PageId.create ? c.wizardStep : ''}',
                                      ),
                                      keyboardDismissBehavior:
                                          ScrollViewKeyboardDismissBehavior
                                              .onDrag,
                                      padding: const EdgeInsets.fromLTRB(
                                        20,
                                        8,
                                        20,
                                        24,
                                      ),
                                      children: screen(),
                                    ),
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: shell
              ? TaskLyBottomNav(
                  selected: tabPages.entries
                      .firstWhere((entry) => entry.value == page)
                      .key,
                  onSelected: (i) {
                    c.root(tabPages[i]!);
                  },
                )
              : null,
        ),
      );
    },
  );

  bool get _shouldPinBottomActions => false;

  bool _isActionButton(Widget w) {
    return w is PrimaryButton ||
        w is OutlinedButton ||
        w is ElevatedButton ||
        w is FilledButton ||
        w is TextButton;
  }

  Widget _buildPinnedScreen(List<Widget> items) {
    if (items.isEmpty) return const SizedBox.shrink();

    int lastButtonIdx = -1;
    for (int i = items.length - 1; i >= 0; i--) {
      if (_isActionButton(items[i])) {
        lastButtonIdx = i;
        break;
      }
    }

    if (lastButtonIdx == -1 ||
        (items.length > 4 && lastButtonIdx < (items.length * 0.4))) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: items,
      );
    }

    int groupStart = lastButtonIdx;
    while (groupStart > 0) {
      final prev = items[groupStart - 1];
      if (_isActionButton(prev) || prev is SizedBox) {
        groupStart--;
      } else {
        break;
      }
    }

    final body = items.sublist(0, groupStart);
    final footer = items.sublist(groupStart).where((w) {
      return !(w is SizedBox && w == items[groupStart]);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: body,
        ),
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: footer,
          ),
        ),
      ],
    );
  }

  List<Widget> screen() {
    if (c.repository is CustomerBookingDrafts &&
        {PageId.ai}.contains(c.route.page)) {
      return [
        const SizedBox(height: 40),
        const EmptyState(
          'Tính năng đang được hoàn thiện',
          'Gợi ý AI chưa được kết nối với backend. Bạn có thể khám phá dịch vụ và tiếp tục bản nháp trong Hoạt động.',
        ),
        PrimaryButton('Khám phá dịch vụ', () => c.open(PageId.services)),
      ];
    }
    return switch (c.route.page) {
      PageId.splash ||
      PageId.onboarding ||
      PageId.login ||
      PageId.register ||
      PageId.recovery ||
      PageId.otp ||
      PageId.locationPermission => authScreens(),
      PageId.home => const [],
      PageId.services => serviceList(),
      PageId.serviceDetail => serviceDetail(),
      PageId.create => createScreen(),
      PageId.ai => aiScreen(),
      PageId.recommendations ||
      PageId.tasker ||
      PageId.matched => matchingScreens(),
      PageId.tasks => [
        if (c.repository is CustomerBookingDrafts)
          BookingDraftActivity(controller: c),
        if (c.repository is ApiCustomerRepository)
          TaskActivityList(
            session: (c.repository as ApiCustomerRepository).session,
          )
        else
          ...taskList(),
      ],
      PageId.community => [
        CommunityFeed(
          articles: data.articles,
          onArticle: (id) => c.open(PageId.article, id: id),
        ),
      ],
      PageId.article => [
        CommunityArticleView(
          article: data.articles.where((a) => a.id == c.route.id).firstOrNull,
        ),
      ],
      PageId.task => [
        if (c.repository is ApiCustomerRepository && c.route.id != null)
          TaskActivityDetail(
            session: (c.repository as ApiCustomerRepository).session,
            id: c.route.id!,
            onBack: () => c.back(),
          )
        else
          ...taskDetail(),
      ],
      PageId.tracking => trackingScreen(),
      PageId.payment ||
      PageId.paymentSuccess ||
      PageId.rating ||
      PageId.ratingSuccess => paymentScreens(),
      PageId.messages ||
      PageId.chat ||
      PageId.notifications => communicationScreens(),
      PageId.support ||
      PageId.complaint ||
      PageId.complaintStatus => supportScreens(),
      _ => accountScreens(),
    };
  }

  Widget heading(String title, [String? subtitle]) => Padding(
    padding: const EdgeInsets.only(top: 8, bottom: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineSmall),
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(color: AppColors.muted, height: 1.5),
          ),
        ],
      ],
    ),
  );
  Widget section(
    String title, {
    String? action,
    VoidCallback? onTap,
  }) => Padding(
    padding: const EdgeInsets.only(top: 8, bottom: 12),
    child: Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleMedium),
        ),
        if (action != null) TextButton(onPressed: onTap, child: Text(action)),
      ],
    ),
  );
  Widget field(
    String label,
    String value,
    ValueChanged<String> onChanged, {
    int lines = 1,
    TextInputType? keyboard,
    int? maxLength,
    String? helper,
    Key? key,
    bool readOnly = false,
    bool enabled = true,
    Widget? prefixIcon,
    Widget? suffixIcon,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
      key: key ?? ValueKey(label),
      initialValue: value,
      onChanged: onChanged,
      readOnly: readOnly,
      enabled: enabled,
      minLines: lines,
      maxLines: lines,
      maxLength: maxLength,
      keyboardType: keyboard,
      decoration: InputDecoration(
        labelText: label,
        helperText: helper,
        alignLabelWithHint: lines > 1,
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
      ),
    ),
  );
  Widget info(String text, {IconData icon = Icons.verified_user_outlined}) =>
      Panel(
        color: AppColors.mint,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppColors.primary, size: 22),
            const SizedBox(width: 12),
            Expanded(child: Text(text, style: const TextStyle(height: 1.5))),
          ],
        ),
      );
  Widget detailRow(
    IconData icon,
    String title,
    String value, {
    Widget? leading,
  }) {
    final isAddress =
        title.toLowerCase().contains('địa điểm') ||
        title.toLowerCase().contains('địa chỉ') ||
        title.toLowerCase().contains('điểm đến');
    return InkWell(
      onTap: isAddress ? () => openGoogleMaps(value) : null,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            leading ?? Icon(icon, color: AppColors.primary, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 3),
                  Text(
                    value,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isAddress ? AppColors.navy : null,
                    ),
                  ),
                ],
              ),
            ),
            if (isAddress) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.mint,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.directions_rounded,
                      size: 15,
                      color: AppColors.primary,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Bản đồ',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget menu(
    String title,
    IconData icon,
    VoidCallback tap, {
    String? subtitle,
  }) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFE6EDF7)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x05000000),
          blurRadius: 8,
          offset: Offset(0, 2),
        ),
      ],
    ),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: tap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 39,
                height: 39,
                decoration: BoxDecoration(
                  color: const Color(0xFFEDF5FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 20, color: const Color(0xFF2563EB)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF7C8CA1),
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: Color(0xFF8BA6CA),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  Widget taskerCard(Tasker person, VoidCallback? onTap) => Panel(
    child: Column(
      children: [
        Row(
          children: [
            UserAvatar(person.name, person.avatar),
            IconButton(
              tooltip: c.favoriteHelperIds.contains(person.id)
                  ? 'Bỏ yêu thích'
                  : 'Thêm yêu thích',
              onPressed: c.busy
                  ? null
                  : () => c.toggleHelperFavorite(person.id),
              icon: Icon(
                c.favoriteHelperIds.contains(person.id)
                    ? Icons.favorite
                    : Icons.favorite_border,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    person.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    person.school,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (c.repository is! ApiCustomerRepository)
                    Text(
                      '★ ${person.rating} • ${person.jobs} việc • ${person.distance} km',
                      style: const TextStyle(fontSize: 12),
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (c.repository is! ApiCustomerRepository || onTap != null)
          Row(
            children: [
              if (c.repository is! ApiCustomerRepository)
                Expanded(
                  child: Text(
                    '${person.match}% phù hợp • Gợi ý tự động',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              if (onTap != null)
                TextButton(onPressed: onTap, child: const Text('Xem hồ sơ')),
            ],
          ),
      ],
    ),
  );
  Widget taskCard(CustomerTask task) => Panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                task.id,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            Flexible(child: StatusChip(task.status)),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          data.service(task.draft.serviceId).name,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        detailRow(
          Icons.schedule,
          '${dateLabel(task.draft.scheduledAt)} • ${timeLabel(task.draft.scheduledAt)}',
          '${task.draft.duration} giờ',
        ),
        Text(task.draft.address.detail),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Text(
                money(task.price.total),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
            ),
            TextButton(
              onPressed: () => c.open(PageId.task, id: task.id),
              child: const Text('Xem chi tiết →'),
            ),
          ],
        ),
      ],
    ),
  );
  Future<bool> confirm(String title, String message) async =>
      await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Quay lại'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Xác nhận'),
            ),
          ],
        ),
      ) ??
      false;
}
