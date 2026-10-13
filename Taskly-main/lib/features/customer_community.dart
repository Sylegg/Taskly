import 'package:flutter/material.dart';

import '../app/customer_controller.dart';
import '../auth/api.dart';
import '../data/api_customer_repository.dart';
import 'community_screens.dart';
import 'community_reels.dart';
import 'home/home_components.dart';

class CustomerCommunity extends StatefulWidget {
  const CustomerCommunity({super.key, required this.controller});
  final CustomerController controller;

  @override
  State<CustomerCommunity> createState() => _CustomerCommunityState();
}

class _CustomerCommunityState extends State<CustomerCommunity> {
  int tab = 0;
  String selectedFilter = 'Tất cả';

  CustomerController get c => widget.controller;
  Session? get session => c.repository is ApiCustomerRepository
      ? (c.repository as ApiCustomerRepository).session
      : null;

  final categories = const [
    'Tất cả',
    'Chuyện nhà',
    'Mẹo hay',
    'Kinh nghiệm',
    'TaskLyNews',
  ];

  @override
  void initState() {
    super.initState();
    c.refreshCatalogue();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: c,
    builder: (context, _) {
      final all = c.data?.articles ?? [];
      final articles = all.where((a) {
        if (selectedFilter == 'Tất cả') return true;
        if (selectedFilter == 'Chuyện nhà') {
          return a.groupName.toLowerCase().contains('chuyện nhà') ||
              a.title.toLowerCase().contains('chuyện nhà');
        }
        if (selectedFilter == 'Mẹo hay') {
          return a.hashtag.toLowerCase().contains('meo') ||
              a.title.toLowerCase().contains('mẹo');
        }
        if (selectedFilter == 'Kinh nghiệm') {
          return a.content.toLowerCase().contains('kinh nghiệm') ||
              a.title.toLowerCase().contains('kinh nghiệm');
        }
        if (selectedFilter == 'TaskLyNews') {
          return a.hashtag.toLowerCase().contains('tasklynews') ||
              a.authorName.toLowerCase().contains('taskly');
        }
        return true;
      }).toList();

      final isVideoTab = tab == 1;

      return Scaffold(
        backgroundColor: isVideoTab ? Colors.black : const Color(0xFFF8FAFC),
        extendBody: isVideoTab,
        body: isVideoTab
            ? Stack(
                fit: StackFit.expand,
                children: [
                  // Full-bleed video reels edge-to-edge
                  if (session != null)
                    CommunityReels(
                      session: session!,
                      bottomPadding: 96,
                    )
                  else
                    const Center(
                      child:
                          CircularProgressIndicator(color: Color(0xFF0F9D7A)),
                    ),

                  // Floating modern top header overlay
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.78),
                            Colors.black.withValues(alpha: 0.35),
                            Colors.transparent,
                          ],
                        ),
                      ),
                      child: SafeArea(
                        bottom: false,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                          child: Row(
                            children: [
                              // Nút quay lại Bảng tin / Menu
                              GestureDetector(
                                onTap: () => setState(() => tab = 0),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.35),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color:
                                          Colors.white.withValues(alpha: 0.2),
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.arrow_back_ios_new_rounded,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),

                              // Segmented Tab Capsule (Bảng tin | Video ngắn HOT)
                              Expanded(
                                child: Container(
                                  height: 42,
                                  padding: const EdgeInsets.all(3.5),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.4),
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(
                                      color:
                                          Colors.white.withValues(alpha: 0.16),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      // Tab 0: Bảng tin
                                      Expanded(
                                        child: GestureDetector(
                                          behavior: HitTestBehavior.opaque,
                                          onTap: () => setState(() => tab = 0),
                                          child: Container(
                                            alignment: Alignment.center,
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                            child: const Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  Icons.article_rounded,
                                                  size: 16,
                                                  color: Colors.white70,
                                                ),
                                                SizedBox(width: 5),
                                                Text(
                                                  'Bảng tin',
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w600,
                                                    color: Colors.white70,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),

                                      // Tab 1: Video ngắn HOT (Active)
                                      Expanded(
                                        child: Container(
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF0F9D7A),
                                            borderRadius:
                                                BorderRadius.circular(20),
                                            boxShadow: const [
                                              BoxShadow(
                                                color: Color(0x330F9D7A),
                                                blurRadius: 8,
                                                offset: Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              const Icon(
                                                Icons.play_circle_fill_rounded,
                                                size: 16,
                                                color: Colors.white,
                                              ),
                                              const SizedBox(width: 5),
                                              const Flexible(
                                                child: Text(
                                                  'Video ngắn',
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w700,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 5,
                                                  vertical: 1.5,
                                                ),
                                                decoration: BoxDecoration(
                                                  gradient:
                                                      const LinearGradient(
                                                    colors: [
                                                      Color(0xFFFF5252),
                                                      Color(0xFFFF7A00),
                                                    ],
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: const Text(
                                                  'HOT',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 8.5,
                                                    fontWeight: FontWeight.w900,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),

                              // Notification Button
                              IconButton(
                                tooltip: 'Thông báo',
                                onPressed: () => c.open(PageId.notifications),
                                icon: Container(
                                  padding: const EdgeInsets.all(7),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.35),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color:
                                          Colors.white.withValues(alpha: 0.2),
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.notifications_none_rounded,
                                    size: 19,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              )
            : SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    // Modern App Bar
                    Container(
                      color: Colors.white,
                      padding: const EdgeInsets.fromLTRB(18, 12, 10, 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE8F7F2),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(
                                        Icons.groups_rounded,
                                        color: Color(0xFF0F9D7A),
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Cộng đồng',
                                      style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF0F172A),
                                        letterSpacing: -0.3,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                  'Không gian kết nối & chia sẻ mẹo hay',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF64748B),
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Thông báo',
                            onPressed: () => c.open(PageId.notifications),
                            icon: Container(
                              padding: const EdgeInsets.all(7),
                              decoration: const BoxDecoration(
                                color: Color(0xFFF1F5F9),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.notifications_none_rounded,
                                size: 20,
                                color: Color(0xFF475569),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Modern Segmented Pill Control (Tabs)
                    Container(
                      color: Colors.white,
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                      child: Container(
                        height: 46,
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Row(
                          children: [
                            // Tab 0: Bài viết / Bảng tin
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => tab = 0),
                                child: Container(
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Color(0x120F172A),
                                        blurRadius: 8,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.article_rounded,
                                        size: 18,
                                        color: Color(0xFF0F9D7A),
                                      ),
                                      SizedBox(width: 6),
                                      Text(
                                        'Bảng tin',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF0F9D7A),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),

                            // Tab 1: Video ngắn / Reels
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => tab = 1),
                                child: Container(
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: Colors.transparent,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        Icons.play_circle_fill_rounded,
                                        size: 18,
                                        color: Color(0xFF64748B),
                                      ),
                                      const SizedBox(width: 6),
                                      const Flexible(
                                        child: Text(
                                          'Video ngắn',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                            color: Color(0xFF64748B),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 5,
                                          vertical: 1.5,
                                        ),
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [
                                              Color(0xFFFF5252),
                                              Color(0xFFFF7A00),
                                            ],
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: const Text(
                                          'HOT',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 9,
                                            fontWeight: FontWeight.w900,
                                          ),
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

                    // Filter Chips for Articles (when Tab 0 is active)
                    Container(
                      color: Colors.white,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (final cat in categories)
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                  label: Text(cat),
                                  selected: selectedFilter == cat,
                                  onSelected: (_) =>
                                      setState(() => selectedFilter = cat),
                                  labelStyle: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: selectedFilter == cat
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: selectedFilter == cat
                                        ? Colors.white
                                        : const Color(0xFF64748B),
                                  ),
                                  selectedColor: const Color(0xFF0F9D7A),
                                  backgroundColor: const Color(0xFFF8FAFC),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    side: BorderSide(
                                      color: selectedFilter == cat
                                          ? Colors.transparent
                                          : const Color(0xFFE2E8F0),
                                    ),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  showCheckmark: false,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),

                    // Main Content Area
                    Expanded(
                      child: RefreshIndicator(
                        color: const Color(0xFF0F9D7A),
                        onRefresh: c.refreshCatalogue,
                        child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.only(top: 8, bottom: 90),
                          children: [
                            if (articles.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 48,
                                  horizontal: 24,
                                ),
                                child: Center(
                                  child: Container(
                                    padding: const EdgeInsets.all(28),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(24),
                                      border: Border.all(
                                        color: const Color(0xFFEDF2F7),
                                      ),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Color(0x060F172A),
                                          blurRadius: 16,
                                          offset: Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(16),
                                          decoration: const BoxDecoration(
                                            color: Color(0xFFE8F7F2),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.groups_outlined,
                                            size: 40,
                                            color: Color(0xFF0F9D7A),
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        const Text(
                                          'Chưa có bài viết mới.',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF0F172A),
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        const Text(
                                          'Chuyển sang tab Video ngắn để khám phá các clip thú vị!',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Color(0xFF64748B),
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        ElevatedButton.icon(
                                          onPressed: () =>
                                              setState(() => tab = 1),
                                          icon: const Icon(
                                            Icons.play_circle_fill_rounded,
                                            size: 18,
                                          ),
                                          label: const Text('Xem Video ngắn'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(
                                              0xFF0F9D7A,
                                            ),
                                            foregroundColor: Colors.white,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              )
                            else
                              CommunityFeed(
                                articles: articles,
                                session: session,
                                onArticle: (id) =>
                                    c.open(PageId.article, id: id),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
        bottomNavigationBar: TaskLyBottomNav(
          selected: 3,
          isDark: isVideoTab,
          onSelected: (index) {
            final pages = {
              0: PageId.home,
              1: PageId.tasks,
              3: PageId.community,
              4: PageId.profile,
            };
            if (pages[index] != null) c.root(pages[index]!);
          },
        ),
      );
    },
  );
}
