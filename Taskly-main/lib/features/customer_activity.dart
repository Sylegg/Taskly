import 'package:flutter/material.dart';

import '../app/customer_controller.dart';
import '../data/api_customer_repository.dart';
import 'home/home_components.dart';
import 'home/assistant_chat.dart';
import 'task_activity.dart';
import 'completion_review.dart';
import 'booking_draft_activity.dart';
import 'customer_support.dart';
import '../domain/booking_draft.dart';

const _activityBackground = Color(0xFFF6FCF9);
const _activityGreen = Color(0xFF0F9D7A);

class CustomerActivity extends StatefulWidget {
  const CustomerActivity({super.key, required this.controller});
  final CustomerController controller;

  @override
  State<CustomerActivity> createState() => _CustomerActivityState();
}

class _CustomerActivityState extends State<CustomerActivity> {
  int _selectedTab = 0;

  void _openSupport() {
    final repository = widget.controller.repository;
    if (repository is! ApiCustomerRepository) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            CustomerSupportConversation(session: repository.session),
      ),
    );
  }

  Widget _support() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F7F2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.auto_awesome,
                color: _activityGreen,
                size: 22,
              ),
            ),
            title: const Text(
              'Trợ lý AI',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: Color(0xFF0F172A),
              ),
            ),
            subtitle: const Text(
              'Hướng dẫn tự động về dịch vụ, giá và cách đặt lịch.',
              style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
            ),
            trailing: const Icon(Icons.chevron_right, color: Color(0xFF94A3B8)),
            onTap: () => openTaskLyAssistant(context),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F7F2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.support_agent_rounded,
                color: _activityGreen,
                size: 22,
              ),
            ),
            title: const Text(
              'Chăm sóc khách hàng',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: Color(0xFF0F172A),
              ),
            ),
            subtitle: Text(
              widget.controller.repository is ApiCustomerRepository
                  ? 'Nhắn tin với CSKH để được hỗ trợ về đơn dịch vụ và tài khoản.'
                  : 'Vui lòng đăng nhập để nhắn tin với CSKH.',
              style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
            ),
            trailing: const Icon(Icons.chevron_right, color: Color(0xFF94A3B8)),
            onTap: widget.controller.repository is ApiCustomerRepository
                ? _openSupport
                : null,
          ),
        ),
      ],
    ),
  );

  Widget _empty() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 24),
    child: Column(
      children: [
        const SizedBox(height: 32),
        Image.asset(
          'assets/images/activity_empty.png',
          width: 150,
          height: 148,
        ),
        const SizedBox(height: 14),
        const Text(
          'Ngôi nhà tươm tất sẽ giúp bạn cảm thấy thoải mái hơn.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            height: 1.45,
            color: Color(0xFF667085),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 48,
          child: FilledButton(
            onPressed: () => widget.controller.root(PageId.home),
            style: FilledButton.styleFrom(
              backgroundColor: _activityGreen,
              foregroundColor: Colors.white,
              minimumSize: const Size(152, 48),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              textStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            child: const Text('Đăng việc ngay'),
          ),
        ),
        const SizedBox(height: 24),
      ],
    ),
  );

  Widget _list({bool history = false, bool hasDrafts = false}) {
    final repository = widget.controller.repository;
    if (repository is! ApiCustomerRepository) {
      return hasDrafts ? const SizedBox.shrink() : _empty();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TaskActivityList(
        key: ValueKey(history ? 'history' : 'services'),
        session: repository.session,
        showHeading: false,
        filter: (task) {
          final finished = isCustomerHistoryTask(task);
          if (history) return finished;
          return !finished;
        },
        emptyWidget: history
            ? const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: Text('Chưa có lịch sử công việc.')),
              )
            : _empty(),
      ),
    );
  }

  void _history() => Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => Scaffold(
        backgroundColor: _activityBackground,
        appBar: AppBar(
          title: const Text(
            'Lịch sử',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          backgroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(1),
            child: Divider(height: 1, color: Color(0xFFE2E8F0)),
          ),
        ),
        body: SingleChildScrollView(child: _list(history: true)),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFFFFFF), Color(0xFFF0FBF6), Color(0xFFFFFFFF)],
      ),
      image: DecorationImage(
        image: AssetImage('assets/images/hoatdong.png'),
        opacity: 0.12,
        fit: BoxFit.cover,
        alignment: Alignment.topCenter,
      ),
    ),
    child: Scaffold(
      backgroundColor: Colors.transparent,
      extendBody: true,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: _activityGreen,
          onRefresh: () async {
            await widget.controller.refreshCatalogue();
            if (mounted) setState(() {});
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // Collapsible Top Header
              SliverToBoxAdapter(
                child: Container(
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F7F2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.assignment_rounded,
                          color: _activityGreen,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Hoạt động',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                                letterSpacing: -0.3,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Quản lý tiến độ đơn & dịch vụ',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF64748B),
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _history,
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.history_rounded,
                                  size: 16,
                                  color: _activityGreen,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Lịch sử',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: _activityGreen,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => widget.controller.open(PageId.services),
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F7F2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.grid_view_rounded,
                                  size: 15,
                                  color: _activityGreen,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Dịch vụ',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: _activityGreen,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Sticky Tabs: Đơn dịch vụ | Hỗ trợ
              SliverPersistentHeader(
                pinned: true,
                delegate: _ActivityStickyTabBarDelegate(
                  selectedTab: _selectedTab,
                  onTabChanged: (val) => setState(() => _selectedTab = val),
                ),
              ),

              // Content List
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.only(
                    top: 8,
                    bottom: TaskLyBottomNav.contentBottomPadding(context),
                  ),
                  child: _selectedTab == 1
                      ? _support()
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Padding(
                              padding: EdgeInsets.fromLTRB(16, 8, 16, 12),
                              child: Text(
                                'Đơn của bạn',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A),
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ),
                            if (widget.controller.repository is CustomerBookingDrafts)
                              BookingDraftActivity(
                                controller: widget.controller,
                                showHeading: false,
                                following: (count) => _list(hasDrafts: count > 0),
                              )
                            else
                              _list(),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: TaskLyBottomNav(
        selected: 1,
        onSelected: (index) {
          final pages = {
            0: PageId.home,
            1: PageId.tasks,
            3: PageId.community,
            4: PageId.profile,
          };
          final page = pages[index];
          if (page != null) widget.controller.root(page);
        },
      ),
    ),
  );
}

class _ActivityStickyTabBarDelegate extends SliverPersistentHeaderDelegate {
  final int selectedTab;
  final ValueChanged<int> onTabChanged;

  _ActivityStickyTabBarDelegate({
    required this.selectedTab,
    required this.onTabChanged,
  });

  @override
  double get minExtent => 60.0;

  @override
  double get maxExtent => 60.0;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      height: 60.0,
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: overlapsContent
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
        border: Border(
          bottom: BorderSide(
            color: overlapsContent
                ? const Color(0xFFE2E8F0)
                : Colors.transparent,
            width: 1,
          ),
        ),
      ),
      child: Container(
        height: 46,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: [
            // Tab 0: Đơn dịch vụ
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onTabChanged(0),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selectedTab == 0 ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: selectedTab == 0
                        ? const [
                            BoxShadow(
                              color: Color(0x120F172A),
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.receipt_long_rounded,
                        size: 17,
                        color: selectedTab == 0
                            ? _activityGreen
                            : const Color(0xFF64748B),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Đơn dịch vụ',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: selectedTab == 0
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: selectedTab == 0
                              ? _activityGreen
                              : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Tab 1: Hỗ trợ
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onTabChanged(1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selectedTab == 1 ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: selectedTab == 1
                        ? const [
                            BoxShadow(
                              color: Color(0x120F172A),
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.support_agent_rounded,
                        size: 18,
                        color: selectedTab == 1
                            ? _activityGreen
                            : const Color(0xFF64748B),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Hỗ trợ',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: selectedTab == 1
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: selectedTab == 1
                              ? _activityGreen
                              : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _ActivityStickyTabBarDelegate oldDelegate) {
    return oldDelegate.selectedTab != selectedTab;
  }
}
