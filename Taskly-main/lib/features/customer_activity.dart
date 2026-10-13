import 'package:flutter/material.dart';

import '../app/customer_controller.dart';
import '../data/api_customer_repository.dart';
import 'home/home_components.dart';
import 'home/assistant_chat.dart';
import 'task_activity.dart';
import 'booking_draft_activity.dart';
import 'customer_support.dart';
import '../domain/booking_draft.dart';

const _activityBackground = Color(0xFFFBFAFF);
const _activityGreen = Color(0xFF0DB653);
const _finishedStatuses = {
  'COMPLETED',
  'PAID',
  'CANCELLED',
  'EXPIRED',
  'REFUNDED',
};

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
        Card(
          child: ListTile(
            leading: const Icon(Icons.auto_awesome, color: _activityGreen),
            title: const Text('Trợ lý AI'),
            subtitle: const Text(
              'Hướng dẫn tự động về dịch vụ, giá và cách đặt lịch.',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => openTaskLyAssistant(context),
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.support_agent, color: _activityGreen),
            title: const Text('Chăm sóc khách hàng'),
            subtitle: Text(
              widget.controller.repository is ApiCustomerRepository
                  ? 'Nhắn tin với CSKH để được hỗ trợ về đơn dịch vụ và tài khoản.'
                  : 'Vui lòng đăng nhập để nhắn tin với CSKH.',
            ),
            trailing: const Icon(Icons.chevron_right),
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
          final finished = _finishedStatuses.contains(task['status']);
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
          title: const Text('Lịch sử'),
          backgroundColor: Colors.white,
        ),
        body: SingleChildScrollView(child: _list(history: true)),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _activityBackground,
    appBar: AppBar(
      automaticallyImplyLeading: false,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      titleSpacing: 14,
      title: const Text(
        'Hoạt động',
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: Color(0xFF252B35),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _history,
          style: TextButton.styleFrom(
            foregroundColor: _activityGreen,
            textStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          child: const Text('Lịch sử'),
        ),
        TextButton(
          onPressed: () => widget.controller.open(PageId.services),
          style: TextButton.styleFrom(foregroundColor: _activityGreen),
          child: const Text('Dịch vụ'),
        ),
        const SizedBox(width: 6),
      ],
    ),
    body: SafeArea(
      child: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(
                  value: 0,
                  icon: Icon(Icons.receipt_long_outlined),
                  label: Text('Đơn dịch vụ'),
                ),
                ButtonSegment(
                  value: 1,
                  icon: Icon(Icons.support_agent),
                  label: Text('Hỗ trợ'),
                ),
              ],
              selected: {_selectedTab},
              onSelectionChanged: (selection) =>
                  setState(() => _selectedTab = selection.first),
            ),
          ),
          if (_selectedTab == 1)
            _support()
          else ...[
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Text(
                'Đơn của bạn',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
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
        ],
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
  );
}
