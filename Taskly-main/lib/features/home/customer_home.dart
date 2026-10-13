import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../app/customer_controller.dart';
import '../../data/api_customer_repository.dart';
import '../../domain/models.dart';
import '../task_chat.dart';
import 'home_components.dart';

/// Optional server metadata. Missing rewards/favorites stay hidden.
class HomeExtras {
  const HomeExtras({
    this.offline = false,
    this.loading = false,
    this.favoritePartnerIds = const [],
    this.rewardPoints,
    this.rewardTarget = 300,
    this.serviceRatings = const {},
  });
  final bool offline, loading;
  final List<String> favoritePartnerIds;
  final int? rewardPoints;
  final int rewardTarget;
  final Map<String, double> serviceRatings;
}

class TaskLyCustomerHome extends StatefulWidget {
  const TaskLyCustomerHome({
    super.key,
    required this.controller,
    this.extras = const HomeExtras(),
    this.onRetry,
    this.onOpenTasker,
  });
  final CustomerController controller;
  final HomeExtras extras;
  final Future<void> Function()? onRetry;
  final VoidCallback? onOpenTasker;
  @override
  State<TaskLyCustomerHome> createState() => _TaskLyCustomerHomeState();
}

class _TaskLyCustomerHomeState extends State<TaskLyCustomerHome>
    with WidgetsBindingObserver {
  Timer? _catalogueTimer;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) c.refreshCatalogue();
    });
    _catalogueTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        c.refreshCatalogue();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) c.refreshCatalogue();
  }

  @override
  void dispose() {
    _catalogueTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  bool _isNavVisible = true;
  String? selectedAddressId;
  bool assistantDismissed = false;
  CustomerController get c => widget.controller;
  CustomerSnapshot get data => c.data!;
  String get name {
    final fullName = data.profile.name.trim();
    return fullName.isEmpty ? 'bạn' : fullName;
  }

  Tasker? partner(CustomerTask task) =>
      data.taskers.where((p) => p.id == task.taskerId).firstOrNull;
  Future<void> book() async {
    await c.startCreate();
    final selected = data.addresses
        .where((a) => a.id == selectedAddressId)
        .firstOrNull;
    if (selected != null && c.draft != null) {
      c.draft!.address = selected;
      c.changed();
    }
  }

  void service(String id) {
    if (data.services.any((s) => s.id == id)) {
      c.open(PageId.serviceDetail, id: id);
    } else {
      final idx = homeServiceIds.indexOf(id);
      if (idx >= 0 && idx < homeServiceLabels.length) {
        c.search = homeServiceLabels[idx].replaceAll('\n', ' ');
      } else {
        c.search = switch (id) {
          'shop' => 'Cửa hàng',
          'services' => 'Tiện ích khác',
          'news' => 'Tin tức',
          'payment' => 'Thanh toán',
          'lifestyle' => 'Đời sống',
          _ => id,
        };
      }
      c.open(PageId.services);
    }
  }

  Future<void> addressPicker() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          children: [
            const Text(
              'Dịch vụ đến nơi bạn cần',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 14),
            ...data.addresses.map(
              (a) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.location_on_outlined,
                  color: HomeColors.dark,
                ),
                title: Text(a.label),
                subtitle: Text(a.detail),
                trailing: a.id == selectedAddressId
                    ? const Icon(Icons.check_circle, color: HomeColors.emerald)
                    : null,
                onTap: () => Navigator.pop(context, a.id),
              ),
            ),
            TextButton.icon(
              onPressed: () {
                Navigator.pop(context, 'manage');
              },
              icon: const Icon(Icons.add),
              label: const Text('Quản lý địa chỉ'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || choice == null) return;
    if (choice == 'manage') {
      c.open(PageId.addresses);
      return;
    }
    setState(() => selectedAddressId = choice);
  }

  void infoSheet(String title, String text) => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    backgroundColor: Colors.white,
    builder: (_) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            Text(text, style: const TextStyle(height: 1.7)),
            const SizedBox(height: 20),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Đã hiểu'),
            ),
          ],
        ),
      ),
    ),
  );
  Widget horizontal(List<Widget> cards, double height) => SizedBox(
    height: height * MediaQuery.textScalerOf(context).scale(1).clamp(1, 2),
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      itemCount: cards.length,
      separatorBuilder: (_, _) => const SizedBox(width: 12),
      itemBuilder: (_, i) => cards[i],
    ),
  );
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: c,
    builder: (context, _) => Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: widget.extras.loading || (c.data == null && c.error == null)
                ? const HomeSkeleton()
                : c.data == null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.cloud_off_outlined,
                          color: HomeColors.muted,
                          size: 38,
                        ),
                        const SizedBox(height: 12),
                        const Text('Không thể tải dữ liệu'),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: widget.onRetry ?? c.initialize,
                          child: const Text('Thử lại'),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    color: HomeColors.emerald,
                    onRefresh: () async {
                      await widget.onRetry?.call();
                      await c.initialize();
                    },
                    child: NotificationListener<ScrollNotification>(
                      onNotification: (notification) {
                        if (notification.metrics.axis != Axis.vertical) {
                          return false;
                        }
                        if (notification is UserScrollNotification) {
                          if (notification.direction ==
                                  ScrollDirection.reverse &&
                              _isNavVisible) {
                            setState(() => _isNavVisible = false);
                          } else if (notification.direction ==
                                  ScrollDirection.forward &&
                              !_isNavVisible) {
                            setState(() => _isNavVisible = true);
                          }
                        } else if (notification is ScrollUpdateNotification) {
                          final delta = notification.scrollDelta ?? 0;
                          if (delta > 8 && _isNavVisible) {
                            setState(() => _isNavVisible = false);
                          } else if (delta < -8 && !_isNavVisible) {
                            setState(() => _isNavVisible = true);
                          }
                        }
                        return false;
                      },
                      child: ListView(
                        padding: const EdgeInsets.only(top: 12, bottom: 84),
                        physics: const AlwaysScrollableScrollPhysics(),
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        children: content()
                            .map(
                              (section) => section is PopularServicesCard
                                  ? section
                                  : Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                      ),
                                      child: section,
                                    ),
                            )
                            .toList(),
                      ),
                    ),
                  ),
          ),
        ),
      ),
      extendBody: true,
      bottomNavigationBar: TaskLyBottomNav(
        selected: 0,
        isVisible: _isNavVisible,
        onSelected: (i) {
          c.root(
            {
              0: PageId.home,
              3: PageId.community,
              1: PageId.tasks,
              4: PageId.profile,
            }[i]!,
          );
        },
      ),
    ),
  );

  List<Widget> content() {
    final address =
        data.addresses.where((a) => a.id == selectedAddressId).firstOrNull ??
        data.addresses.where((a) => a.isDefault).firstOrNull ??
        data.addresses.firstOrNull;
    final activeStatuses = {
      TaskStatus.accepted,
      TaskStatus.onTheWay,
      TaskStatus.arrived,
      TaskStatus.inProgress,
      TaskStatus.completed,
      TaskStatus.disputed,
    };
    final now = DateTime.now();
    final upcoming =
        data.tasks
            .where(
              (t) =>
                  t.draft.scheduledAt.isAfter(now) &&
                  {
                    TaskStatus.posted,
                    TaskStatus.matching,
                    TaskStatus.accepted,
                  }.contains(t.status),
            )
            .toList()
          ..sort((a, b) => a.draft.scheduledAt.compareTo(b.draft.scheduledAt));
    final active = data.tasks
        .where(
          (t) =>
              activeStatuses.contains(t.status) &&
              !upcoming.any((u) => u.id == t.id),
        )
        .toList();
    final waiting = data.tasks
        .where(
          (t) =>
              {TaskStatus.posted, TaskStatus.matching}.contains(t.status) &&
              !upcoming.any((u) => u.id == t.id),
        )
        .toList();
    final history =
        data.tasks.where((t) => t.status == TaskStatus.paid).toList()..sort(
          (a, b) => (b.completedAt ?? b.draft.scheduledAt).compareTo(
            a.completedAt ?? a.draft.scheduledAt,
          ),
        );
    final previous = history.firstOrNull;
    final favorites = data.taskers
        .where((p) => widget.extras.favoritePartnerIds.contains(p.id))
        .toList();
    return [
      if (widget.onOpenTasker != null)
        Align(
          alignment: Alignment.centerRight,
          child: IconButton(
            tooltip: 'chuyển Tasker',
            onPressed: widget.onOpenTasker,
            icon: const Icon(Icons.swap_horiz),
          ),
        ),
      if (widget.extras.offline)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: HomeSurface(
            color: const Color(0xFFFFF3DB),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                const Icon(
                  Icons.wifi_off_rounded,
                  size: 17,
                  color: HomeColors.muted,
                ),
                const SizedBox(width: 9),
                const Expanded(
                  child: Text(
                    'Bạn đang ngoại tuyến',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
                TextButton(
                  onPressed: widget.onRetry ?? c.refresh,
                  child: const Text('Thử lại', style: TextStyle(fontSize: 11)),
                ),
              ],
            ),
          ),
        ),
      TaskLyHomeHeader(
        name: name,
        address: address == null
            ? 'Thêm địa chỉ của bạn'
            : '${address.label} · ${address.detail}',
        unread: data.notifications.any((n) => !n.read),
        onNotifications: () => c.open(PageId.notifications),
        onAddress: addressPicker,
        onSearch: (query) {
          c.categoryFilter = '';
          c.search = query;
          c.open(PageId.services);
        },
        onBook: book,
      ),
      if (c.error != null)
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: HomeSurface(
            border: true,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.cloud_off_outlined, color: HomeColors.muted),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Không thể tải dữ liệu',
                        style: TextStyle(fontSize: 13),
                      ),
                      Text(
                        c.error!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: HomeColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    c.error = null;
                    await c.initialize();
                  },
                  child: const Text('Thử lại'),
                ),
              ],
            ),
          ),
        ),
      Padding(
        padding: const EdgeInsets.only(top: 14),
        child: Container(
          decoration: BoxDecoration(
            image: const DecorationImage(
              image: AssetImage('assets/images/hinh1.png'),
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(
                color: Color(0x22087A60),
                blurRadius: 18,
                offset: Offset(0, 6),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Việc nhà nhẹ hơn cùng TaskLy',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Dịch vụ đáng tin cậy, đặt nhanh và an tâm hơn.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                          const SizedBox(height: 12),
                          FilledButton(
                            onPressed: book,
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFF087A60),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              minimumSize: const Size(0, 38),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Đặt dịch vụ ngay',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    const TaskLyRobot(size: 72),
                  ],
                ),
              ),
              ArcServiceCarousel(
                onService: (id) {
                  c.categoryFilter = id;
                  c.search = '';
                  c.open(PageId.services);
                },
                onAllServices: () {
                  c.search = '';
                  c.categoryFilter = '';
                  c.open(PageId.services);
                },
                categories: data.categories,
                isEmbedded: true,
              ),
            ],
          ),
        ),
      ),
      PopularServicesCard(services: data.services, onService: service),
      HomePromoSection(banners: data.banners),
      if (!c.demoMode && data.services.isEmpty)
        const HomeSurface(
          child: Text(
            'Chưa có dịch vụ khả dụng. Danh mục sẽ được cập nhật từ TaskLy.',
          ),
        ),
      if (active.isNotEmpty || waiting.isNotEmpty) ...[
        const SectionHeader('Công việc đang diễn ra'),
        ...[...active, ...waiting]
            .take(2)
            .map(
              (t) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ActiveTaskCard(
                  task: t,
                  service: data.service(t.draft.serviceId),
                  partner: partner(t),
                  eta: t.status == TaskStatus.onTheWay
                      ? 'Dự kiến ${data.config.etaMinutes} phút'
                      : null,
                  onDetails: () => c.taskRoot(t.id),
                  onMessage: () {
                    if (c.repository is ApiCustomerRepository) {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => TaskChatScreen(
                            session:
                                (c.repository as ApiCustomerRepository).session,
                            taskId: t.id,
                            partner: false,
                            initialServiceName:
                                data.service(t.draft.serviceId).name,
                            initialTaskerName: partner(t)?.name,
                          ),
                        ),
                      );
                    } else {
                      c.chatFor(t.id);
                    }
                  },
                  onTrack: () =>
                      t.status == TaskStatus.completed ||
                          t.status == TaskStatus.disputed
                      ? c.taskRoot(t.id)
                      : c.open(PageId.tracking, id: t.id),
                ),
              ),
            ),
      ],
      if (upcoming.isNotEmpty) ...[
        const SectionHeader('Lịch sắp tới'),
        ...upcoming
            .take(2)
            .map(
              (t) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: UpcomingTaskCard(
                  task: t,
                  service: data.service(t.draft.serviceId),
                  onTap: () => c.taskRoot(t.id),
                ),
              ),
            ),
      ],
      if (previous != null && !assistantDismissed) ...[
        const SizedBox(height: 24),
        TaskLyAssistantCard(
          name: name,
          service: data.service(previous.draft.serviceId).name,
          onBook: () => c.startCreate(repeat: previous),
          onDismiss: () => setState(() => assistantDismissed = true),
        ),
      ],
      if (history.isNotEmpty) ...[
        const SectionHeader('Đặt lại gần đây'),
        ...history
            .take(2)
            .map(
              (t) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: BookAgainCard(
                  task: t,
                  service: data.service(t.draft.serviceId),
                  partner: partner(t),
                  onBook: () => c.startCreate(repeat: t),
                ),
              ),
            ),
      ],
      if (favorites.isNotEmpty) ...[
        const SectionHeader('Partner yêu thích'),
        horizontal(
          favorites
              .map(
                (p) => FavoritePartnerCard(
                  partner: p,
                  skill: 'Dịch vụ gia đình',
                  onBook: () => c.startCreate(),
                ),
              )
              .toList(),
          260,
        ),
      ],
      if (widget.extras.rewardPoints != null) ...[
        SectionHeader(
          'TaskLy Rewards',
          action: '${widget.extras.rewardPoints} điểm',
          onTap: () => rewards(),
        ),
        RewardsProgressCard(
          points: widget.extras.rewardPoints!,
          target: widget.extras.rewardTarget,
          onTap: rewards,
        ),
      ],
      if (history.isEmpty && active.isEmpty) ...[
        const SectionHeader('TaskLy giúp bạn thế nào?'),
        HomeSurface(
          color: HomeColors.soft,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Một chút hỗ trợ. Thêm nhiều thảnh thơi.',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 14),
              ...[
                'Chọn dịch vụ & thời gian phù hợp',
                'Xem chi phí, chủ động chọn Partner',
                'Theo dõi công việc & đánh giá',
              ].indexed.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 12,
                        backgroundColor: Colors.white,
                        child: Text(
                          '${item.$1 + 1}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: HomeColors.dark,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          item.$2,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (c.demoMode)
                TextButton.icon(
                  onPressed: () => c.open(PageId.ai),
                  icon: const Icon(Icons.auto_awesome, size: 16),
                  label: const Text(
                    'Nhờ TaskLy lên kế hoạch',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
            ],
          ),
        ),
      ],
      const SizedBox(height: 22),
      const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.verified_user_outlined, color: HomeColors.dark, size: 15),
          SizedBox(width: 7),
          Flexible(
            child: Text(
              'An tâm giao việc. Thảnh thơi tận hưởng.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: HomeColors.muted),
            ),
          ),
        ],
      ),
    ];
  }

  void rewards() => infoSheet(
    'TaskLy Rewards',
    'Bạn đang có ${widget.extras.rewardPoints} TaskPoints.\nMốc phần thưởng: ${widget.extras.rewardTarget} điểm.\nThông tin phần thưởng sẽ được cập nhật khi chương trình chính thức mở.',
  );
}
