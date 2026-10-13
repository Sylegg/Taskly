part of 'customer_view.dart';

extension _AccountScreens on _CustomerViewState {
  List<Widget> communicationScreens() {
    if (c.route.page == PageId.notifications) {
      return [CustomerNotificationView(controller: c)];
    }
    if (c.route.page == PageId.chat) {
      final chat = data.conversations.firstWhere(
        (item) => item.id == c.route.id,
      );
      final person = data.tasker(chat.taskerId);
      final task = data.task(chat.taskId);
      return [
        Panel(
          color: AppColors.mint,
          child: Column(
            children: [
              Row(
                children: [
                  UserAvatar(person.name, person.avatar),
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
                          '${data.service(task.draft.serviceId).name} • ${task.id}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              StatusChip(task.status),
              TextButton(
                onPressed: () => c.open(PageId.task, id: task.id),
                child: const Text('Xem tiến trình công việc'),
              ),
            ],
          ),
        ),
        ...chat.messages.map(
          (message) => Align(
            alignment: message.mine
                ? Alignment.centerRight
                : Alignment.centerLeft,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 390),
              margin: EdgeInsets.only(
                bottom: 14,
                left: message.mine ? 36 : 0,
                right: message.mine ? 0 : 36,
              ),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: message.mine ? AppColors.primary : Colors.white,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.text,
                    style: TextStyle(
                      color: message.mine ? Colors.white : AppColors.navy,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    timeLabel(message.at),
                    style: TextStyle(
                      fontSize: 11,
                      color: message.mine ? AppColors.mint : AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () {
            c.messageInput =
                'Địa chỉ công việc: ${task.draft.address.detail}. ${task.draft.address.note}';
            c.changed();
          },
          icon: const Icon(Icons.place_outlined),
          label: const Text('Điền vị trí công việc'),
        ),
        const SizedBox(height: 12),
        field(
          'Tin nhắn',
          c.messageInput,
          (v) => c.messageInput = v,
          lines: 2,
          key: ValueKey(
            'message-${chat.messages.length}-${c.messageInput.startsWith('Địa chỉ công việc:')}',
          ),
        ),
        PrimaryButton(
          'Gửi tin nhắn',
          () => c.sendMessage(chat.id),
          icon: Icons.send_outlined,
        ),
      ];
    }
    final chats = data.conversations.where(
      (chat) =>
          data
              .tasker(chat.taskerId)
              .name
              .toLowerCase()
              .contains(c.conversationSearch.toLowerCase()) ||
          chat.taskId.toLowerCase().contains(
            c.conversationSearch.toLowerCase(),
          ),
    );
    return [
      heading('Giữ kết nối,nan tâm giao việc.'),
      field('Tìm tên hoặc mã công việc', c.conversationSearch, (v) {
        c.conversationSearch = v;
        c.changed();
      }),
      if (chats.isEmpty)
        EmptyState(
          'Chưa có hội thoại phù hợp',
          c.repository is ApiCustomerRepository
              ? 'Tin nhắn công việc chưa được kết nối với backend.'
              : 'Chat mở sau khi bạn ghép Tasker. Thử từ khóa khác nếu đang tìm kiếm.',
        ),
      ...chats.map((chat) {
        final person = data.tasker(chat.taskerId);
        return InkWell(
          onTap: () {
            if (c.repository is ApiCustomerRepository) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => TaskChatScreen(
                    session: (c.repository as ApiCustomerRepository).session,
                    taskId: chat.taskId,
                    partner: false,
                    initialTaskerName: person.name,
                  ),
                ),
              );
            } else {
              c.chatFor(chat.taskId);
            }
          },
          borderRadius: BorderRadius.circular(20),
          child: Panel(
            child: Row(
              children: [
                UserAvatar(person.name, person.avatar),
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
                        chat.taskId,
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        chat.messages.lastOrNull?.text ??
                            'Bắt đầu cuộc trò chuyện',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (chat.unread > 0)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Badge(label: Text('${chat.unread}')),
                  ),
              ],
            ),
          ),
        );
      }),
      info(
        'Tin nhắn trong chế độ mô phỏng chỉ lưu trong phiên chạy.',
        icon: Icons.chat_bubble_outline,
      ),
    ];
  }

  List<Widget> accountScreens() {
    switch (c.route.page) {
      case PageId.editProfile:
        return [
          heading('Thông tin của bạn'),
          Container(
            padding: const EdgeInsets.all(18),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE8EDF5)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x06214777),
                  blurRadius: 16,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (data.profile.nameLocked)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.person_outline,
                      color: AppColors.muted,
                    ),
                    title: const Text('Họ tên theo CCCD'),
                    subtitle: Text(data.profile.name),
                  )
                else
                  field(
                    'Họ tên',
                    c.profileName,
                    (v) => c.profileName = v,
                    prefixIcon: const Icon(Icons.person_outline),
                  ),
                field(
                  'Số điện thoại',
                  c.profilePhone,
                  (v) => c.profilePhone = v,
                  keyboard: TextInputType.phone,
                  prefixIcon: const Icon(Icons.phone_outlined),
                ),
                field(
                  'Email (Gmail)',
                  data.profile.email.isNotEmpty
                      ? data.profile.email
                      : c.profileEmail,
                  (_) {},
                  readOnly: true,
                  keyboard: TextInputType.emailAddress,
                  helper: 'Email dùng để đăng nhập và nhận OTP, không thể chỉnh sửa.',
                  prefixIcon: const Icon(Icons.email_outlined),
                  suffixIcon: const Icon(
                    Icons.lock_outline,
                    size: 20,
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
          info(
            'Số điện thoại và họ tên có thể cập nhật trực tiếp. Email/Gmail tài khoản được cố định vì lý do bảo mật.',
            icon: Icons.shield_outlined,
          ),
          const SizedBox(height: 16),
          PrimaryButton('Lưu thông tin', c.saveProfile),
        ];
      case PageId.addresses:
        return [
          heading(
            'Địa chỉ đã lưu',
            'Chọn địa chỉ mặc định để điền nhanh khi tạo công việc mới.',
          ),
          if (data.addresses.isEmpty)
            const EmptyState(
              'Chưa có địa chỉ',
              'Thêm nơi bạn thường cần hỗ trợ.',
            ),
          ...data.addresses.map((a) {
            final icon = switch (a.buildingType.toLowerCase()) {
              'chung cư' || 'apartment' => Icons.apartment_rounded,
              'văn phòng' || 'office' => Icons.business_rounded,
              _ =>
                (a.label.toLowerCase().contains('văn phòng') ||
                        a.label.toLowerCase().contains('công ty'))
                    ? Icons.business_rounded
                    : (a.label.toLowerCase().contains('chung cư') ||
                          a.label.toLowerCase().contains('căn hộ'))
                    ? Icons.apartment_rounded
                    : Icons.home_rounded,
            };

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: a.isDefault
                      ? AppColors.primary.withValues(alpha: 0.35)
                      : const Color(0xFFE2E8F0),
                  width: a.isDefault ? 1.5 : 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: a.isDefault ? AppColors.primary : AppColors.mint,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(
                      icon,
                      color: a.isDefault ? Colors.white : AppColors.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: () => openGoogleMaps(
                        a.detail,
                        lat: a.latitude,
                        lng: a.longitude,
                      ),
                      borderRadius: BorderRadius.circular(8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  a.label,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.navy,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (a.isDefault) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.mint,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'Mặc định',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            a.detail,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF64748B),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (a.contactName.isNotEmpty ||
                              a.contactPhone.isNotEmpty ||
                              a.note.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              [
                                if (a.contactName.isNotEmpty ||
                                    a.contactPhone.isNotEmpty)
                                  '${a.contactName}${a.contactName.isNotEmpty && a.contactPhone.isNotEmpty ? ' · ' : ''}${a.contactPhone}',
                                if (a.note.isNotEmpty) a.note,
                              ].join(' • '),
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF94A3B8),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.all(6),
                        constraints: const BoxConstraints(),
                        icon: const Icon(
                          Icons.navigation_rounded,
                          size: 20,
                          color: AppColors.primary,
                        ),
                        tooltip: 'Chỉ đường Google Maps',
                        onPressed: () => openGoogleMaps(
                          a.detail,
                          lat: a.latitude,
                          lng: a.longitude,
                        ),
                      ),
                      if (!a.isDefault)
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.all(6),
                          constraints: const BoxConstraints(),
                          icon: const Icon(
                            Icons.star_outline_rounded,
                            size: 20,
                            color: Color(0xFF94A3B8),
                          ),
                          tooltip: 'Đặt làm mặc định',
                          onPressed: () => c.setDefaultAddress(a.id),
                        ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.all(6),
                        constraints: const BoxConstraints(),
                        icon: const Icon(
                          Icons.edit_outlined,
                          size: 20,
                          color: AppColors.primary,
                        ),
                        tooltip: 'Chỉnh sửa',
                        onPressed: () => addressDialog(a),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.all(6),
                        constraints: const BoxConstraints(),
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          size: 20,
                          color: Color(0xFF94A3B8),
                        ),
                        tooltip: 'Xóa địa chỉ',
                        onPressed: () async {
                          if (await confirm(
                            'Xóa địa chỉ?',
                            'Các công việc đã đăng vẫn giữ địa chỉ ban đầu.',
                          )) {
                            await c.deleteAddress(a.id);
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
          PrimaryButton(
            'Thêm địa chỉ mới',
            () => addressDialog(null),
            icon: Icons.add_location_alt_outlined,
          ),
        ];
      case PageId.paymentMethods:
        final bankMethods = data.methods
            .where((m) => m.kind == 'BANK')
            .toList();
        return [
          heading(
            'Tài khoản ngân hàng',
            'Quản lý ngân hàng và chọn tài khoản mặc định nhận tiền hoàn.',
          ),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFBBF7D0)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.verified_user_outlined,
                    color: Color(0xFF16A34A),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Tài khoản đã liên kết được bảo vệ an toàn và dùng để nhận tiền hoàn tự động khi hủy đơn dịch vụ.',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: Color(0xFF166534),
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (bankMethods.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x060F172A),
                    blurRadius: 14,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: const BoxDecoration(
                      color: AppColors.mint,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.account_balance_outlined,
                      color: AppColors.primary,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Chưa có tài khoản ngân hàng',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Thêm tài khoản ngân hàng để nhận tiền hoàn tự động và thực hiện các giao dịch nhanh chóng.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF64748B),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _bankFeatureBadge('🛡️ Bảo mật cao'),
                      _bankFeatureBadge('⚡ Nhận hoàn 24/7'),
                      _bankFeatureBadge('🆓 Miễn phí'),
                    ],
                  ),
                ],
              ),
            )
          else
            ...bankMethods.map(_buildBankCard),
          const SizedBox(height: 16),
          PrimaryButton(
            'Thêm tài khoản ngân hàng',
            paymentMethodDialog,
            icon: Icons.add_card_rounded,
          ),
        ];
      case PageId.reviews:
        if (c.repository is ApiCustomerRepository) {
          final reviews = (c.repository as ApiCustomerRepository).reviews;
          return [
            heading('Những trải nghiệm đã chia sẻ'),
            if (reviews.isEmpty)
              const EmptyState(
                'Chưa có đánh giá',
                'Đánh giá của bạn được lưu sau khi công việc hoàn tất và thanh toán.',
              ),
            ...reviews.map(
              (review) => Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(review['title'] as String),
                    Text(
                      '★' * (review['stars'] as int),
                      style: const TextStyle(color: AppColors.primary),
                    ),
                    Text(review['comment'] as String),
                    Text(
                      dateLabel(DateTime.parse(review['createdAt'] as String)),
                    ),
                  ],
                ),
              ),
            ),
          ];
        }
        final tasks = data.tasks.where((t) => t.review != null);
        return [
          heading('Những trải nghiệm đã chia sẻ'),
          if (tasks.isEmpty)
            const EmptyState(
              'Chưa có đánh giá',
              'Sau khi hoàn tất và thanh toán công việc, bạn có thể đánh giá Tasker.',
            ),
          ...tasks.map(
            (task) => Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.tasker(task.taskerId!).name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    '${'★' * task.review!.stars} • ${dateLabel(task.review!.at)}',
                    style: const TextStyle(color: AppColors.primary),
                  ),
                  const SizedBox(height: 10),
                  Text(task.review!.comment),
                  if (task.review!.tags.isNotEmpty)
                    Wrap(
                      spacing: 6,
                      children: task.review!.tags
                          .map((tag) => Chip(label: Text(tag)))
                          .toList(),
                    ),
                  ...task.review!.categories.entries.map(
                    (entry) => Text('${entry.key}: ${entry.value}/5'),
                  ),
                  TextButton(
                    onPressed: () => c.open(PageId.task, id: task.id),
                    child: Text('Xem ${task.id}'),
                  ),
                ],
              ),
            ),
          ),
        ];
      case PageId.favoriteHelpers:
        final favorites = data.taskers.where(
          (t) => c.favoriteHelperIds.contains(t.id),
        );
        final discovered = data.taskers.where(
          (t) => !c.favoriteHelperIds.contains(t.id),
        );
        return [
          heading(
            'Người giúp yêu thích',
            'Lưu những người bạn tin tưởng để dễ tìm lại.',
          ),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Yêu thích')),
                ButtonSegment(value: true, label: Text('Khám phá người giúp')),
              ],
              selected: {_discoverHelpers},
              showSelectedIcon: false,
              onSelectionChanged: (selection) =>
                  _selectHelperTab(selection.single),
            ),
          ),
          const SizedBox(height: 16),
          if (!_discoverHelpers && favorites.isEmpty)
            const EmptyState(
              'Chưa có người giúp yêu thích',
              'Nhấn biểu tượng trái tim để thêm người giúp vào danh sách.',
            ),
          if (!_discoverHelpers) ...favorites.map((t) => taskerCard(t, null)),
          if (_discoverHelpers && discovered.isEmpty)
            const EmptyState(
              'Chưa có người giúp khả dụng',
              'Danh sách sẽ xuất hiện khi có người giúp tham gia.',
            ),
          if (_discoverHelpers) ...discovered.map((t) => taskerCard(t, null)),
        ];
      case PageId.settings:
        return [
          heading('Thiết lập trải nghiệm'),
          menu(
            'Đổi mật khẩu',
            Icons.lock_outline,
            changePasswordDialog,
            subtitle: 'Bảo vệ tài khoản với mật khẩu mới',
          ),
          Panel(
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: data.notificationEnabled,
              onChanged: c.setNotifications,
              title: const Text('Thông báo trong ứng dụng'),
              subtitle: const Text('Lưu lựa chọn thông báo theo tài khoản.'),
            ),
          ),
          menu(
            'Trợ giúp & quyền riêng tư',
            Icons.policy_outlined,
            () => c.open(PageId.help),
          ),
          if (c.demoMode) ...[
            section('Công cụ mẫu'),
            menu('Mô phỏng lỗi ở thao tác tiếp theo', Icons.wifi_off, () {
              c.demoControls?.failNextRequest();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Thao tác repository tiếp theo sẽ báo lỗi để kiểm tra retry.',
                  ),
                ),
              );
            }),
            menu('Đặt lại toàn bộ dữ liệu mẫu', Icons.restart_alt, () async {
              if (await confirm(
                'Đặt lại mẫu?',
                'Xóa các thay đổi trong phiên và khôi phục dữ liệu mẫu.',
              )) {
                c.resetDemo();
              }
            }),
          ],
        ];
      case PageId.help:
        return [
          heading('Chúng tôi có thể giúp gì?', 'Hướng dẫn sử dụng TaskLy'),
          ...(c.repository is ApiCustomerRepository
                  ? const {
                      'Thông tin được lưu ở đâu?': 'Hồ sơ, địa chỉ, phương thức thanh toán và cài đặt được lưu theo tài khoản trên máy chủ. Đăng nhập lại để tải thông tin đã lưu.',
                      'Thêm ngân hàng có thu tiền không?': 'Thêm ngân hàng chỉ lưu thông tin nhận diện tài khoản, chưa liên kết ngân hàng hoặc thực hiện chuyển tiền.',
                      'Đổi số điện thoại hoặc email thế nào?': 'Thông tin đăng nhập cần xác minh trước khi thay đổi. Bạn có thể chỉnh sửa họ tên tại mục Chỉnh sửa hồ sơ.',
                      'Vì sao không lưu được?': 'Kiểm tra kết nối mạng và thử lại. Nếu phiên hết hạn, hãy đăng nhập lại. Thông tin chỉ được xác nhận đã lưu khi máy chủ xử lý thành công.',
                    }
                  : data.config.help)
              .entries
              .map(
                (entry) => Panel(
                  padding: 4,
                  child: ExpansionTile(
                    shape: const Border(),
                    collapsedShape: const Border(),
                    title: Text(
                      entry.key,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    children: [Text(entry.value)],
                  ),
                ),
              ),
        ];
      default:
        final profile = data.profile;
        final displayName = profile.name.trim().isNotEmpty
            ? profile.name
            : 'Khách hàng TaskLy';
        final displayContact = profile.email.isNotEmpty
            ? profile.email
            : (profile.phone.isNotEmpty
                  ? profile.phone
                  : 'Tài khoản TaskLy Customer');

        return [
          // 1. USER PROFILE CARD (Partner HTML style)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE8EDF5)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0A214777),
                  blurRadius: 20,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    UserAvatar(profile.name, profile.avatar, radius: 26),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            style: const TextStyle(
                              fontSize: 16.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            displayContact,
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: Color(0xFF7C8CA1),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4.5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE7EFFF),
                              borderRadius: BorderRadius.circular(99),
                              border: Border.all(
                                color: const Color(0xFFD4E2FF),
                              ),
                            ),
                            child: const Text(
                              'Khách hàng TaskLy',
                              style: TextStyle(
                                color: Color(0xFF2456C0),
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Chỉnh sửa thông tin tài khoản',
                      onPressed: c.busy ? null : c.editProfile,
                      icon: const Icon(
                        Icons.edit_outlined,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                if (c.repository is ApiCustomerRepository) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Divider(height: 1, color: Color(0xFFE8EDF5)),
                  ),
                  Row(
                    children: [
                      const Icon(
                        Icons.account_balance_wallet_outlined,
                        color: AppColors.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Số dư tài khoản',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              _formatRefundCurrency((c.repository as ApiCustomerRepository).refundBalance),
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF059669),
                              ),
                            ),
                          ],
                        ),
                      ),
                      FilledButton.tonal(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFECFDF5),
                          foregroundColor: const Color(0xFF059669),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: refundWithdrawalDialog,
                        child: const Text(
                          'Rút tiền',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          if (c.repository is ApiCustomerRepository)
            FilledButton.icon(
              icon: const Icon(Icons.add_card_rounded),
              label: const Text('Nạp tiền & lịch sử nạp'),
              onPressed: c.busy ? null : customerTopUpDialog,
            ),
          // 2. HỒ SƠ & HOẠT ĐỘNG
          if (c.repository is ApiCustomerRepository)
            TextButton.icon(
              icon: const Icon(Icons.history_rounded),
              label: const Text('Lịch sử rút tiền'),
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                builder: (_) => _RefundWithdrawalHistorySheet(
                  session: (c.repository as ApiCustomerRepository).session,
                ),
              ),
            ),
          const Padding(
            padding: EdgeInsets.only(top: 22, bottom: 12),
            child: Text(
              'Hồ sơ & hoạt động',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
                letterSpacing: -0.2,
              ),
            ),
          ),
          menu(
            'Chỉnh sửa hồ sơ',
            Icons.person_outline,
            c.editProfile,
            subtitle: 'Cập nhật họ tên, điện thoại & ảnh đại diện',
          ),
          menu(
            'Địa chỉ đã lưu',
            Icons.location_on_outlined,
            () => c.open(PageId.addresses),
            subtitle: ' địa chỉ đã lưu',
          ),

          menu(
            'Tài khoản ngân hàng',
            Icons.account_balance_wallet_outlined,
            () => c.open(PageId.paymentMethods),
            subtitle: 'Quản lý thông tin ngân hàng & nhận tiền hoàn',
          ),
          menu(
            'Đánh giá của tôi',
            Icons.star_outline,
            () => c.open(PageId.reviews),
            subtitle: 'Lịch sử nhận xét & góp ý dịch vụ',
          ),
          menu(
            'Trung tâm trợ giúp',
            Icons.support_agent,
            () => c.open(PageId.help),
            subtitle: 'Hướng dẫn sử dụng & câu hỏi thường gặp',
          ),
          if (widget.onOpenTasker != null)
            menu(
              'Chuyển sang ứng dụng Đối tác (TaskLy Partner)',
              Icons.swap_horiz,
              widget.onOpenTasker!,
              subtitle: 'Tuyển dụng, đào tạo 9 bước, nhận việc & thu nhập',
            ),
          const SizedBox(height: 12),

          // Security & logout actions
          OutlinedButton(
            onPressed: c.busy ? null : changePasswordDialog,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              backgroundColor: Colors.white,
              side: const BorderSide(color: Color(0xFFD7E3F3)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(
                  Icons.lock_outline_rounded,
                  size: 20,
                  color: Color(0xFF2D5CBD),
                ),
                SizedBox(width: 8),
                Text(
                  'Đổi mật khẩu',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2D5CBD),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: c.busy
                ? null
                : () async {
                    if (await confirm(
                      'Đăng xuất?',
                      'Thông tin đã lưu vẫn thuộc tài khoản của bạn.',
                    )) {
                      if (widget.onLogout != null) {
                        await widget.onLogout!();
                      } else {
                        await c.logout();
                      }
                    }
                  },
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              backgroundColor: const Color(0xFFFFF0F1),
              side: const BorderSide(color: Color(0xFFFFDADF)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.logout_rounded, size: 20, color: Color(0xFFC83B50)),
                SizedBox(width: 8),
                Text(
                  'Đăng xuất',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFC83B50),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ];
    }
  }

  Future<void> changePasswordDialog() async {
    if (c.repository is! ApiCustomerRepository) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đăng nhập bằng tài khoản thật để đổi mật khẩu.'),
        ),
      );
      return;
    }
    final form = GlobalKey<FormState>();
    String current = '', next = '';
    bool hidden = true, saving = false;
    String? error;
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, update) => PopScope(
          canPop: !saving,
          child: AlertDialog(
            backgroundColor: Colors.white,
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 24,
            ),
            title: const Text('Đổi mật khẩu'),
            content: SizedBox(
              width: 560,
              child: SingleChildScrollView(
                child: Form(
                  key: form,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Sau khi đổi mật khẩu, bạn cần đăng nhập lại.',
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        enabled: !saving,
                        obscureText: hidden,
                        onChanged: (v) => current = v,
                        decoration: const InputDecoration(
                          labelText: 'Mật khẩu hiện tại',
                          prefixIcon: Icon(Icons.lock_outline),
                        ),
                        validator: (v) => (v?.isEmpty ?? true)
                            ? 'Nhập mật khẩu hiện tại'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        enabled: !saving,
                        obscureText: hidden,
                        onChanged: (v) => next = v,
                        decoration: const InputDecoration(
                          labelText: 'Mật khẩu mới',
                          helperText: 'Từ 10 đến 128 ký tự',
                          prefixIcon: Icon(Icons.lock_reset),
                        ),
                        validator: (v) =>
                            v == null ||
                                v.trim().isEmpty ||
                                v.length < 10 ||
                                v.length > 128
                            ? 'Mật khẩu cần từ 10 đến 128 ký tự'
                            : v == current
                            ? 'Mật khẩu mới phải khác mật khẩu hiện tại'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        enabled: !saving,
                        obscureText: hidden,
                        decoration: const InputDecoration(
                          labelText: 'Nhập lại mật khẩu mới',
                          prefixIcon: Icon(Icons.verified_user_outlined),
                        ),
                        validator: (v) =>
                            v != next ? 'Mật khẩu nhập lại chưa khớp' : null,
                      ),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: !hidden,
                        title: const Text('Hiện mật khẩu'),
                        onChanged: saving
                            ? null
                            : (v) => update(() => hidden = !(v ?? false)),
                      ),
                      if (error != null)
                        Text(
                          error!,
                          style: const TextStyle(color: AppColors.error),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(ctx, false),
                child: const Text('Hủy'),
              ),
              FilledButton(
                onPressed: saving
                    ? null
                    : () async {
                        if (!form.currentState!.validate()) return;
                        update(() {
                          saving = true;
                          error = null;
                        });
                        try {
                          await (c.repository as ApiCustomerRepository)
                              .changePassword(current, next);
                          if (ctx.mounted) Navigator.pop(ctx, true);
                        } catch (e) {
                          if (ctx.mounted) {
                            update(() {
                              saving = false;
                              error = e.toString();
                            });
                          }
                        }
                      },
                child: Text(saving ? 'Đang lưu…' : 'Lưu mật khẩu'),
              ),
            ],
          ),
        ),
      ),
    );
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đổi mật khẩu thành công. Vui lòng đăng nhập lại.'),
        ),
      );
      await (c.repository as ApiCustomerRepository).session.logout();
    }
  }

  Future<void> addressDialog(Address? address) async {
    final result = await showDialog<Address>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => CustomerAddressDialog(
        address: address,
        session: c.repository is ApiCustomerRepository
            ? (c.repository as ApiCustomerRepository).session
            : null,
        isApi: c.repository is ApiCustomerRepository,
        onSave: c.saveAddress,
        saveError: () => c.error,
      ),
    );
    if (result != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Đã lưu địa chỉ')));
    }
  }

  Future<void> refundWithdrawalDialog() async {
    final repo = c.repository as ApiCustomerRepository;
    final balance = repo.refundBalance;
    if (balance <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bạn chưa có số dư để rút.')),
      );
      return;
    }
    await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => CustomerRefundWithdrawalDialog(
        balance: balance,
        session: repo.session,
        savedMethods: c.data?.methods ?? const [],
        onSuccess: () async {
          await c.refresh();
        },
      ),
    );
  }

  Future<void> customerTopUpDialog() async {
    await showDialog<void>(
      context: context,
      builder: (_) => CustomerTopUpDialog(
        session: (c.repository as ApiCustomerRepository).session,
      ),
    );
    if (mounted) await c.refresh();
  }

  Widget _bankFeatureBadge(String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: const Color(0xFFF1F5F9),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      label,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: Color(0xFF475569),
      ),
    ),
  );

  Widget _buildBankCard(PaymentMethod m) {
    final info = _ParsedBankInfo.fromDetail(m.detail);
    final isDefault = m.isDefault;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDefault
              ? const [Color(0xFF0F766E), Color(0xFF115E59), Color(0xFF042F2E)]
              : const [Color(0xFF1E293B), Color(0xFF334155), Color(0xFF0F172A)],
        ),
        boxShadow: [
          BoxShadow(
            color:
                (isDefault ? const Color(0xFF0F766E) : const Color(0xFF1E293B))
                    .withValues(alpha: 0.28),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.account_balance_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          m.name.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            letterSpacing: 0.5,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (isDefault)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD1FAE5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          size: 12,
                          color: Color(0xFF065F46),
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Mặc định',
                          style: TextStyle(
                            color: Color(0xFF065F46),
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  InkWell(
                    onTap: c.busy
                        ? null
                        : () => c.setDefaultPaymentMethod(m.id),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white30),
                      ),
                      child: const Text(
                        'Đặt mặc định',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 32,
                  height: 24,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFBBF24),
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: const Color(0xFFD97706)),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.memory,
                      size: 16,
                      color: Color(0xFF78350F),
                    ),
                  ),
                ),
                const Icon(
                  Icons.contactless_rounded,
                  color: Colors.white60,
                  size: 20,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              info.accountNumber.isNotEmpty
                  ? info.formattedAccountNumber
                  : (m.detail.isNotEmpty ? m.detail : '•••• •••• •••• ••••'),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'CHỦ TÀI KHOẢN',
                        style: TextStyle(
                          color: Colors.white60,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        info.accountHolder.isNotEmpty
                            ? info.accountHolder.toUpperCase()
                            : (info.accountNumber.isEmpty
                                  ? m.name.toUpperCase()
                                  : '---'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (info.branch.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          'CN: ${info.branch}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 10.5,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Xóa ngân hàng',
                  onPressed: () async {
                    if (await confirm(
                      'Xóa ngân hàng?',
                      'Bạn có thể thêm lại ngân hàng này sau.',
                    )) {
                      c.removePaymentMethod(m.id);
                    }
                  },
                  icon: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.delete_outline,
                      size: 16,
                      color: Colors.white,
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

  Future<void> paymentMethodDialog() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const CustomerBankDialog(),
    );
    if (result != null) {
      final bankName = result['bankName'] as String;
      final accountNumber = result['accountNumber'] as String;
      final owner = result['owner'] as String;
      final branch = result['branch'] as String;
      final isDefault = result['isDefault'] as bool;

      final detail =
          'STK: $accountNumber • ${owner.toUpperCase()}${branch.isNotEmpty ? ' • CN: $branch' : ''}';
      final saved = await c.addPaymentMethod(bankName, detail, kind: 'BANK');
      if (!mounted) return;
      if (!saved) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(c.error ?? 'Chưa lưu được tài khoản ngân hàng. Vui lòng thử lại.'),
          backgroundColor: Colors.red,
        ));
        return;
      }
      if (isDefault) {
        final added = c.data?.methods
            .where((m) => m.name == bankName && m.detail == detail)
            .firstOrNull;
        if (added != null && !added.isDefault) {
          final updated = await c.setDefaultPaymentMethod(added.id);
          if (!mounted) return;
          if (!updated) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Đã lưu ngân hàng nhưng chưa đặt được mặc định. ${c.error ?? 'Vui lòng thử lại.'}'),
            ));
            return;
          }
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã thêm tài khoản ngân hàng thành công!'),
            backgroundColor: Color(0xFF0F766E),
          ),
        );
      }
    }
  }
}

String _formatRefundCurrency(dynamic value) {
  if (value == null) return '0 đ';
  final num val = value is num ? value : (num.tryParse(value.toString()) ?? 0);
  final str = val.toInt().toString();
  final buffer = StringBuffer();
  for (int i = 0; i < str.length; i++) {
    if (i > 0 && (str.length - i) % 3 == 0) {
      buffer.write('.');
    }
    buffer.write(str[i]);
  }
  return '${buffer.toString()} đ';
}

class CustomerRefundWithdrawalDialog extends StatefulWidget {
  const CustomerRefundWithdrawalDialog({
    super.key,
    required this.balance,
    required this.session,
    required this.savedMethods,
    required this.onSuccess,
  });

  final int balance;
  final Session session;
  final List<PaymentMethod> savedMethods;
  final Future<void> Function() onSuccess;

  @override
  State<CustomerRefundWithdrawalDialog> createState() =>
      _CustomerRefundWithdrawalDialogState();
}

class _CustomerRefundWithdrawalDialogState
    extends State<CustomerRefundWithdrawalDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountCtrl;
  late final TextEditingController _ownerCtrl;
  late final TextEditingController _accountCtrl;

  late VietnameseBank _selectedBank;
  bool _submitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _amountCtrl = TextEditingController(text: '${widget.balance}');
    _ownerCtrl = TextEditingController();
    _accountCtrl = TextEditingController();
    _selectedBank = kVietnameseBanks.first;

    // Check saved payment methods to auto-populate default account
    final savedBanks = widget.savedMethods.where((m) {
      final info = _ParsedBankInfo.fromDetail(m.detail);
      return info.accountNumber.isNotEmpty;
    }).toList();

    if (savedBanks.isNotEmpty) {
      final defaultMethod = savedBanks.firstWhere(
        (m) => m.isDefault,
        orElse: () => savedBanks.first,
      );
      final info = _ParsedBankInfo.fromDetail(defaultMethod.detail);
      _selectedBank = findVietnameseBank(defaultMethod.name);
      _accountCtrl.text = info.accountNumber;
      _ownerCtrl.text = info.accountHolder.toUpperCase();
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _ownerCtrl.dispose();
    _accountCtrl.dispose();
    super.dispose();
  }

  void _onBankSelected(VietnameseBank b) {
    setState(() {
      _selectedBank = b;
      if (_accountCtrl.text.length > b.maxDigits) {
        _accountCtrl.text = _accountCtrl.text.substring(0, b.maxDigits);
      }
    });
  }

  Future<void> _openBankPicker() async {
    final chosen = await showBankPickerSheet(
      context,
      currentBank: _selectedBank,
    );
    if (chosen != null) {
      _onBankSelected(chosen);
    }
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (!_formKey.currentState!.validate()) return;

    final amount = int.tryParse(_amountCtrl.text.trim()) ?? 0;
    if (amount <= 0 || amount > widget.balance) {
      setState(() {
        _errorMessage =
            'Vui lòng nhập số tiền từ 1 đ đến ${_formatRefundCurrency(widget.balance)}';
      });
      return;
    }

    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    try {
      await widget.session.request(
        '/users/me/refund-withdrawals',
        method: 'POST',
        body: {
          'amount': amount,
          'bankName': _selectedBank.shortName,
          'accountName': _ownerCtrl.text.trim(),
          'accountNumber': _accountCtrl.text.trim(),
        },
      );
      await widget.onSuccess();
      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã gửi yêu cầu rút tiền thành công!'),
            backgroundColor: Color(0xFF059669),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _errorMessage = e is ApiFailure
              ? e.message
              : 'Không thể gửi yêu cầu rút tiền. Vui lòng thử lại.';
        });
      }
    }
  }

  Future<void> _showHistorySheet() async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _RefundWithdrawalHistorySheet(session: widget.session),
    );
  }

  InputDecoration _inputDecor({
    required String labelText,
    String? hintText,
    required IconData icon,
    Widget? suffixIcon,
    String? helperText,
  }) {
    return InputDecoration(
      isDense: true,
      labelText: labelText,
      floatingLabelBehavior: FloatingLabelBehavior.always,
      labelStyle: const TextStyle(
        fontSize: 13,
        color: Color(0xFF64748B),
        fontWeight: FontWeight.w600,
      ),
      floatingLabelStyle: const TextStyle(
        fontSize: 13,
        color: AppColors.primary,
        fontWeight: FontWeight.w700,
      ),
      hintText: hintText,
      hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
      helperText: helperText,
      helperStyle: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
      prefixIcon: Icon(icon, size: 20, color: AppColors.primary),
      prefixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 48),
      suffixIcon: suffixIcon,
      suffixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 48),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: Color(0xFFDC2626)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final savedBanks = widget.savedMethods.where((m) {
      final info = _ParsedBankInfo.fromDetail(m.detail);
      return info.accountNumber.isNotEmpty;
    }).toList();

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 480,
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFA7F3D0)),
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet_rounded,
                      color: Color(0xFF059669),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Rút tiền hoàn',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Chuyển tiền về tài khoản ngân hàng chính chủ',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, size: 20),
                    color: const Color(0xFF94A3B8),
                    tooltip: 'Đóng',
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),

            // Body
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Balance Card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFECFDF5), Color(0xFFF0FDF4)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFA7F3D0)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF059669),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.payments_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Số dư có thể rút',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF065F46),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _formatRefundCurrency(widget.balance),
                                    style: const TextStyle(
                                      fontSize: 19,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF059669),
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            InkWell(
                              onTap: () {
                                _amountCtrl.text = '${widget.balance}';
                                setState(() => _errorMessage = null);
                              },
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: const Color(0xFFA7F3D0),
                                  ),
                                ),
                                child: const Text(
                                  'Rút tất cả',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF059669),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Quick Amount Chips
                      if (widget.balance > 50000) ...[
                        const Text(
                          'Chọn nhanh số tiền',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF334155),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              for (final amt in [50000, 100000, 200000, 500000])
                                if (amt < widget.balance) ...[
                                  ActionChip(
                                    label: Text(
                                      _formatRefundCurrency(amt),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    backgroundColor: const Color(0xFFF1F5F9),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    side: const BorderSide(
                                      color: Color(0xFFE2E8F0),
                                    ),
                                    onPressed: () {
                                      _amountCtrl.text = '$amt';
                                      setState(() => _errorMessage = null);
                                    },
                                  ),
                                  const SizedBox(width: 8),
                                ],
                              ActionChip(
                                label: const Text(
                                  'Tối đa',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF059669),
                                  ),
                                ),
                                backgroundColor: const Color(0xFFECFDF5),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                side: const BorderSide(
                                  color: Color(0xFFA7F3D0),
                                ),
                                onPressed: () {
                                  _amountCtrl.text = '${widget.balance}';
                                  setState(() => _errorMessage = null);
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Amount Input Field
                      TextFormField(
                        controller: _amountCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: _inputDecor(
                          labelText: 'Số tiền muốn rút (VND) *',
                          hintText: 'Nhập số tiền muốn rút',
                          icon: Icons.price_change_outlined,
                          suffixIcon: Container(
                            alignment: Alignment.center,
                            width: 32,
                            child: const Text(
                              'đ',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF059669),
                              ),
                            ),
                          ),
                        ),
                        validator: (v) {
                          final amt = int.tryParse(v?.trim() ?? '') ?? 0;
                          if (amt <= 0) return 'Vui lòng nhập số tiền lớn hơn 0';
                          if (amt > widget.balance) {
                            return 'Số tiền vượt quá số dư hiện có (${_formatRefundCurrency(widget.balance)})';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Quick Saved Account Selector (if available)
                      if (savedBanks.isNotEmpty) ...[
                        Row(
                          children: const [
                            Icon(
                              Icons.bookmark_added_outlined,
                              size: 15,
                              color: Color(0xFF059669),
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Chọn nhanh từ tài khoản đã lưu:',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF475569),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: savedBanks.map((m) {
                            final info = _ParsedBankInfo.fromDetail(m.detail);
                            final bank = findVietnameseBank(m.name);
                            final isCur =
                                _accountCtrl.text == info.accountNumber;
                            return ChoiceChip(
                              label: Text(
                                '${bank.shortName} (${info.accountNumber})',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: isCur
                                      ? const Color(0xFF059669)
                                      : const Color(0xFF334155),
                                ),
                              ),
                              selected: isCur,
                              selectedColor: const Color(0xFFECFDF5),
                              backgroundColor: const Color(0xFFF1F5F9),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              side: BorderSide(
                                color: isCur
                                    ? const Color(0xFFA7F3D0)
                                    : const Color(0xFFE2E8F0),
                              ),
                              onSelected: (_) {
                                setState(() {
                                  _selectedBank = bank;
                                  _accountCtrl.text = info.accountNumber;
                                  _ownerCtrl.text =
                                      info.accountHolder.toUpperCase();
                                });
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 14),
                      ],

                      // Beneficiary Bank Selector Card
                      const Text(
                        'Ngân hàng thụ hưởng *',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: _openBankPicker,
                        borderRadius: BorderRadius.circular(13),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 11,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(13),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: _selectedBank.brandColor.withOpacity(
                                    0.12,
                                  ),
                                  borderRadius: BorderRadius.circular(9),
                                  border: Border.all(
                                    color: _selectedBank.brandColor.withOpacity(
                                      0.3,
                                    ),
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    _selectedBank.code,
                                    style: TextStyle(
                                      color: _selectedBank.brandColor,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _selectedBank.displayName,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _selectedBank.fullName,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF64748B),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.unfold_more_rounded,
                                color: Color(0xFF64748B),
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Account Holder Name
                      TextFormField(
                        controller: _ownerCtrl,
                        textCapitalization: TextCapitalization.characters,
                        inputFormatters: [
                          TextInputFormatter.withFunction(
                            (oldVal, newVal) => newVal.copyWith(
                              text: newVal.text.toUpperCase(),
                            ),
                          ),
                        ],
                        decoration: _inputDecor(
                          labelText: 'Tên chủ tài khoản *',
                          hintText: 'Ví dụ: NGUYEN VAN A',
                          icon: Icons.person_outline_rounded,
                          helperText:
                              'Viết in hoa không dấu (theo đăng ký tại ngân hàng)',
                        ),
                        validator: (v) => v!.trim().isEmpty
                            ? 'Vui lòng nhập tên chủ tài khoản'
                            : null,
                      ),
                      const SizedBox(height: 16),

                      // Account Number
                      TextFormField(
                        controller: _accountCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: _inputDecor(
                          labelText: 'Số tài khoản *',
                          hintText: 'Nhập số tài khoản ngân hàng',
                          icon: Icons.credit_card_rounded,
                          helperText:
                              '${_selectedBank.shortName} quy định ${_selectedBank.digitsRule}',
                        ),
                        validator: (v) {
                          final clean = v?.trim() ?? '';
                          if (clean.isEmpty) {
                            return 'Vui lòng nhập số tài khoản';
                          }
                          if (!RegExp(r'^[0-9]{6,34}$').hasMatch(clean)) {
                            return 'Số tài khoản cần từ 6 đến 34 chữ số';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Policy & Security Notice
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          children: const [
                            Row(
                              children: [
                                Icon(
                                  Icons.bolt_rounded,
                                  size: 16,
                                  color: Color(0xFF059669),
                                ),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Xử lý nhanh chóng trong 24 giờ qua Napas 24/7.',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: Color(0xFF475569),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(
                                  Icons.verified_user_outlined,
                                  size: 16,
                                  color: Color(0xFF059669),
                                ),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Miễn phí 100% — TaskLy hỗ trợ toàn bộ phí giao dịch.',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: Color(0xFF475569),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // History shortcut button
                      const SizedBox(height: 12),
                      Center(
                        child: TextButton.icon(
                          onPressed: _showHistorySheet,
                          icon: const Icon(Icons.history_rounded, size: 16),
                          label: const Text(
                            'Xem lịch sử rút tiền hoàn',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF059669),
                          ),
                        ),
                      ),

                      if (_errorMessage != null) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFFECACA)),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.error_outline_rounded,
                                size: 16,
                                color: Color(0xFFDC2626),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFFDC2626),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            // Action Buttons
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: Color(0xFFF1F5F9)),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _submitting
                          ? null
                          : () => Navigator.pop(context),
                      child: const Text(
                        'Hủy',
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF059669),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      onPressed: _submitting ? null : _submit,
                      child: _submitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(Icons.send_rounded, size: 16),
                                SizedBox(width: 6),
                                Text(
                                  'Gửi yêu cầu',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
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
}

class _RefundWithdrawalHistorySheet extends StatefulWidget {
  const _RefundWithdrawalHistorySheet({required this.session});
  final Session session;

  @override
  State<_RefundWithdrawalHistorySheet> createState() => _RefundWithdrawalHistorySheetState();
}

class _RefundWithdrawalHistorySheetState extends State<_RefundWithdrawalHistorySheet> {
  late Future<dynamic> history = widget.session.request('/users/me/refund-withdrawals');

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFCBD5E1),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                const Icon(
                  Icons.history_rounded,
                  color: Color(0xFF059669),
                  size: 22,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Lịch sử rút tiền hoàn',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Cập nhật lịch sử',
                  onPressed: () => setState(() => history = widget.session.request('/users/me/refund-withdrawals')),
                  icon: const Icon(Icons.refresh_rounded),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, size: 20),
                  color: const Color(0xFF94A3B8),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          Expanded(
            child: FutureBuilder(
              future: history,
              builder: (ctx, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return const Center(
                    child: Text('Không thể tải lịch sử rút tiền.'),
                  );
                }
                final list = (snapshot.data as List?) ?? [];
                if (list.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(
                            Icons.inbox_outlined,
                            size: 48,
                            color: Color(0xFFCBD5E1),
                          ),
                          SizedBox(height: 12),
                          Text(
                            'Chưa có yêu cầu rút tiền nào.',
                            style: TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 13.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (ctx, index) {
                    final item = list[index] as Map;
                    final status = item['status']?.toString() ?? 'PENDING';
                    final isPaid = status == 'PAID';
                    final isPending = status == 'PENDING';
                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isPaid
                                  ? const Color(0xFFECFDF5)
                                  : (isPending
                                      ? const Color(0xFFFFFBEB)
                                      : const Color(0xFFFEF2F2)),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              isPaid
                                  ? Icons.check_circle_rounded
                                  : (isPending
                                      ? Icons.hourglass_top_rounded
                                      : Icons.cancel_rounded),
                              color: isPaid
                                  ? const Color(0xFF059669)
                                  : (isPending
                                      ? const Color(0xFFD97706)
                                      : const Color(0xFFDC2626)),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _formatRefundCurrency(item['amount'] ?? 0),
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Ngân hàng: ${item['bank_name'] ?? '---'}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                                if (item['created_at'] != null)
                                  Text(
                                    DateTime.tryParse(item['created_at'].toString())?.toLocal().toString().split('.').first ?? item['created_at'].toString(),
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                  ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: isPaid
                                  ? const Color(0xFFECFDF5)
                                  : (isPending
                                      ? const Color(0xFFFFFBEB)
                                      : const Color(0xFFFEF2F2)),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isPaid
                                    ? const Color(0xFFA7F3D0)
                                    : (isPending
                                        ? const Color(0xFFFDE68A)
                                        : const Color(0xFFFECACA)),
                              ),
                            ),
                            child: Text(
                              isPaid
                                  ? 'Đã chuyển tiền'
                                  : (isPending ? 'Đang xử lý' : 'Đã từ chối'),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isPaid
                                    ? const Color(0xFF059669)
                                    : (isPending
                                        ? const Color(0xFFD97706)
                                        : const Color(0xFFDC2626)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ParsedBankInfo {
  final String accountNumber;
  final String accountHolder;
  final String branch;

  _ParsedBankInfo({
    required this.accountNumber,
    required this.accountHolder,
    required this.branch,
  });

  String get formattedAccountNumber {
    final clean = accountNumber.replaceAll(' ', '');
    return clean
        .replaceAllMapped(RegExp(r".{4}"), (match) => "${match.group(0)} ")
        .trim();
  }

  factory _ParsedBankInfo.fromDetail(String detail) {
    if (detail.isEmpty) {
      return _ParsedBankInfo(accountNumber: '', accountHolder: '', branch: '');
    }
    final parts = detail.split('•').map((s) => s.trim()).toList();
    if (parts.length >= 2) {
      final acc = parts[0].replaceAll('STK:', '').trim();
      final holder = parts[1]
          .replaceAll('CHỦ TK:', '')
          .replaceAll('Chủ TK:', '')
          .trim();
      final branch = parts.length >= 3
          ? parts[2].replaceAll('CN:', '').trim()
          : '';
      return _ParsedBankInfo(
        accountNumber: acc,
        accountHolder: holder,
        branch: branch,
      );
    }
    final altParts = detail
        .split(RegExp(r'[-|]'))
        .map((s) => s.trim())
        .toList();
    if (altParts.length >= 2) {
      return _ParsedBankInfo(
        accountNumber: altParts[0].replaceAll('STK:', '').trim(),
        accountHolder: altParts[1].replaceAll('CHỦ TK:', '').trim(),
        branch: altParts.length >= 3
            ? altParts[2].replaceAll('CN:', '').trim()
            : '',
      );
    }
    return _ParsedBankInfo(
      accountNumber: detail,
      accountHolder: '',
      branch: '',
    );
  }
}

class CustomerBankDialog extends StatefulWidget {
  const CustomerBankDialog({super.key});

  @override
  State<CustomerBankDialog> createState() => _CustomerBankDialogState();
}

class _CustomerBankDialogState extends State<CustomerBankDialog> {
  final _formKey = GlobalKey<FormState>();
  final _accountNumberController = TextEditingController();
  final _ownerController = TextEditingController();
  final _branchController = TextEditingController();

  late VietnameseBank _selectedBank;
  bool _isDefault = true;

  @override
  void initState() {
    super.initState();
    _selectedBank = kVietnameseBanks.first;
  }

  @override
  void dispose() {
    _accountNumberController.dispose();
    _ownerController.dispose();
    _branchController.dispose();
    super.dispose();
  }

  void _onBankSelected(VietnameseBank b) {
    setState(() {
      _selectedBank = b;
      if (_accountNumberController.text.length > b.maxDigits) {
        _accountNumberController.text = _accountNumberController.text.substring(
          0,
          b.maxDigits,
        );
      }
    });
  }

  Future<void> _openBankPicker() async {
    final chosen = await showBankPickerSheet(
      context,
      currentBank: _selectedBank,
    );
    if (chosen != null) {
      _onBankSelected(chosen);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accountNumber = _accountNumberController.text.trim();
    final owner = _ownerController.text.trim();
    final branch = _branchController.text.trim();

    final formattedNumber = accountNumber.isNotEmpty
        ? accountNumber
              .replaceAllMapped(
                RegExp(r".{4}"),
                (match) => "${match.group(0)} ",
              )
              .trim()
        : '•••• •••• •••• ••••';

    final brandColor = _selectedBank.brandColor;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
          maxWidth: 480,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Modal Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 14, 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.mint,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.account_balance_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Thêm tài khoản ngân hàng',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Nhập thông tin để nhận tiền hoàn & giao dịch',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    color: const Color(0xFF94A3B8),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),

            // Scrollable Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Live Card Preview
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              brandColor,
                              brandColor.withOpacity(0.85),
                              Color.alphaBlend(
                                Colors.black.withOpacity(0.35),
                                brandColor,
                              ),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: brandColor.withOpacity(0.35),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 7,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        _selectedBank.shortName,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 12,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _selectedBank.displayName,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ],
                                ),
                                const Icon(
                                  Icons.contactless_rounded,
                                  color: Colors.white70,
                                  size: 20,
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Container(
                              width: 30,
                              height: 22,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFBBF24),
                                borderRadius: BorderRadius.circular(5),
                                border: Border.all(
                                  color: const Color(0xFFD97706),
                                ),
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.memory,
                                  size: 14,
                                  color: Color(0xFF78350F),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              formattedNumber,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 2,
                                fontFamily: 'monospace',
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'CHỦ TÀI KHOẢN',
                                        style: TextStyle(
                                          color: Colors.white60,
                                          fontSize: 8.5,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        owner.isNotEmpty
                                            ? owner.toUpperCase()
                                            : 'HO VA TEN',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.5,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                if (branch.isNotEmpty)
                                  Text(
                                    'CN: $branch',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 10,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Bank Selector (Scrollable list modal, no manual typing)
                      InkWell(
                        onTap: _openBankPicker,
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: _selectedBank.brandColor.withOpacity(
                                    0.12,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: _selectedBank.brandColor.withOpacity(
                                      0.3,
                                    ),
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  _selectedBank.shortName.length > 5
                                      ? _selectedBank.shortName.substring(0, 5)
                                      : _selectedBank.shortName,
                                  style: TextStyle(
                                    color: _selectedBank.brandColor,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Ngân hàng thụ hưởng *',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${_selectedBank.shortName} - ${_selectedBank.fullName}',
                                      style: const TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF0F172A),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Độ dài STK chuẩn: ${_selectedBank.digitsRule}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: _selectedBank.brandColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Row(
                                  children: [
                                    Text(
                                      'Đổi',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF334155),
                                      ),
                                    ),
                                    Icon(
                                      Icons.keyboard_arrow_down_rounded,
                                      size: 16,
                                      color: Color(0xFF64748B),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Account Number Field with Bank Length Limits
                      TextFormField(
                        controller: _accountNumberController,
                        keyboardType: TextInputType.number,
                        maxLength: _selectedBank.maxDigits,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(
                            _selectedBank.maxDigits,
                          ),
                        ],
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          labelText: 'Số tài khoản *',
                          hintText: 'Ví dụ: 0123456789',
                          counterText: '',
                          helperText:
                              '${_selectedBank.shortName} quy định ${_selectedBank.digitsRule} (${_accountNumberController.text.length}/${_selectedBank.maxDigits} số)',
                          prefixIcon: const Icon(
                            Icons.credit_card_rounded,
                            size: 20,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                        ),
                        validator: (v) {
                          final clean = v?.trim() ?? '';
                          if (clean.isEmpty) {
                            return 'Vui lòng nhập số tài khoản';
                          }
                          if (clean.length < _selectedBank.minDigits ||
                              clean.length > _selectedBank.maxDigits) {
                            return 'STK ${_selectedBank.shortName} phải có ${_selectedBank.digitsRule} (hiện có ${clean.length} số)';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      // Account Holder Field
                      TextFormField(
                        maxLength: 150,
                        controller: _ownerController,
                        textCapitalization: TextCapitalization.characters,
                        onChanged: (v) {
                          final upper = v.toUpperCase();
                          if (v != upper) {
                            _ownerController.value = _ownerController.value
                                .copyWith(
                                  text: upper,
                                  selection: TextSelection.collapsed(
                                    offset: upper.length,
                                  ),
                                );
                          }
                          setState(() {});
                        },
                        decoration: InputDecoration(
                          labelText: 'Tên chủ tài khoản *',
                          hintText: 'Ví dụ: NGUYEN VAN A',
                          helperText: 'Viết in hoa, không dấu (theo đăng ký tại ngân hàng)',
                          prefixIcon: const Icon(
                            Icons.person_outline_rounded,
                            size: 20,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                        ),
                        validator: (v) => (v?.trim().isEmpty ?? true)
                            ? 'Vui lòng nhập tên chủ tài khoản'
                            : null,
                      ),
                      const SizedBox(height: 14),

                      // Branch Field
                      TextFormField(
                        maxLength: 150,
                        controller: _branchController,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          labelText: 'Chi nhánh / Tỉnh thành (không bắt buộc)',
                          hintText: 'Ví dụ: Hội sở, Chi nhánh Tân Bình...',
                          prefixIcon: const Icon(
                            Icons.location_on_outlined,
                            size: 20,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Set as default
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: SwitchListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                          ),
                          value: _isDefault,
                          onChanged: (v) => setState(() => _isDefault = v),
                          activeColor: AppColors.primary,
                          title: const Text(
                            'Đặt làm tài khoản mặc định',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: const Text(
                            'Tự động chọn tài khoản này khi nhận tiền hoàn',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Security Notice Card
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFBBF7D0)),
                        ),
                        child: const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.shield_outlined,
                              color: Color(0xFF16A34A),
                              size: 18,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Bảo mật an toàn: TaskLy chỉ lưu số tài khoản để nhận tiền hoàn. Tuyệt đối KHÔNG yêu cầu mã PIN, mật khẩu hay mã OTP.',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF166534),
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),

            // Action Buttons
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        'Hủy',
                        style: TextStyle(color: Color(0xFF64748B)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        if (_formKey.currentState!.validate()) {
                          Navigator.pop(context, {
                            'bankName': _selectedBank.displayName,
                            'accountNumber': _accountNumberController.text
                                .trim(),
                            'owner': _ownerController.text.trim().toUpperCase(),
                            'branch': _branchController.text.trim(),
                            'isDefault': _isDefault,
                          });
                        }
                      },
                      child: const Text(
                        'Xác nhận & Thêm',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
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
}

class CustomerAddressDialog extends StatefulWidget {
  const CustomerAddressDialog({
    required this.address,
    required this.isApi,
    this.session,
    this.onSave,
    this.saveError,
  });

  final Address? address;
  final bool isApi;
  final Session? session;
  final Future<bool> Function(Address)? onSave;
  final String? Function()? saveError;

  @override
  State<CustomerAddressDialog> createState() => CustomerAddressDialogState();
}

class CustomerAddressDialogState extends State<CustomerAddressDialog> {
  late final TextEditingController _labelCtrl;
  late final TextEditingController _detailCtrl;
  late final TextEditingController _cityCtrl;
  late final TextEditingController _noteCtrl;
  late final TextEditingController _buildingDescCtrl;
  late final TextEditingController _contactNameCtrl;
  late final TextEditingController _contactPhoneCtrl;

  bool _savingAddress = false;
  String? _saveError;
  late bool _isDefault;
  late String _buildingType;

  final _formKey = GlobalKey<FormState>();

  static const _buildingTypes = [
    ('Nhà riêng', Icons.home_rounded),
    ('Chung cư', Icons.apartment_rounded),
    ('Khác', Icons.location_on_rounded),
  ];

  static const _labelSuggestions = [
    ('Nhà riêng', Icons.home_rounded),
    ('Văn phòng', Icons.business_rounded),
    ('Căn hộ', Icons.apartment_rounded),
    ('Nhà ba mẹ', Icons.family_restroom_rounded),
    ('Khác', Icons.location_on_rounded),
  ];

  List<Map<String, dynamic>> _cityAreas = [];
  bool _loadingCities = true;
  String? _cityError;
  Future<void> _loadCities() async {
    try {
      final result = await widget.session?.request('/public/work-areas');
      if (!mounted) return;
      setState(() {
        _cityAreas = (result as List? ?? [])
            .map((a) => Map<String, dynamic>.from(a))
            .toList();
        _loadingCities = false;
      });
    } catch (_) {
      if (mounted)
        setState(() {
          _cityError = 'Không tải được khu vực. Vui lòng thử lại.';
          _loadingCities = false;
        });
    }
  }

  @override
  void initState() {
    super.initState();
    _loadCities();
    final a = widget.address;

    _labelCtrl = TextEditingController(text: a?.label ?? '');
    _detailCtrl = TextEditingController(text: a?.detail ?? '');
    _cityCtrl = TextEditingController(text: a?.city ?? '');
    _noteCtrl = TextEditingController(text: a?.note ?? '');
    _buildingDescCtrl = TextEditingController(
      text: a?.buildingDescription ?? '',
    );
    _contactNameCtrl = TextEditingController(text: a?.contactName ?? '');
    _contactPhoneCtrl = TextEditingController(text: a?.contactPhone ?? '');

    _isDefault = a?.isDefault ?? false;
    _buildingType = (a?.buildingType.isNotEmpty == true)
        ? a!.buildingType
        : (a?.label.contains('Chung cư') == true ||
                  a?.label.contains('Căn hộ') == true
              ? 'Chung cư'
              : (a?.label.contains('Văn phòng') == true
                    ? 'Khác'
                    : 'Nhà riêng'));
  }

  @override
  void dispose() {
    _labelCtrl.dispose();
    _detailCtrl.dispose();
    _cityCtrl.dispose();
    _noteCtrl.dispose();
    _buildingDescCtrl.dispose();
    _contactNameCtrl.dispose();
    _contactPhoneCtrl.dispose();
    super.dispose();
  }

  void _close([Address? result]) {
    FocusManager.instance.primaryFocus?.unfocus();
    Navigator.of(context).pop(result);
  }

  Future<void> _submit() async {
    if (_savingAddress) return;
    if (_formKey.currentState?.validate() ?? false) {
      final result = Address(
        widget.address?.id ?? '',
        _labelCtrl.text.trim(),
        _detailCtrl.text.trim(),
        _noteCtrl.text.trim(),
        isDefault: _isDefault,
        city: _cityCtrl.text.trim(),
        contactName: _contactNameCtrl.text.trim(),
        contactPhone: _contactPhoneCtrl.text.trim(),
        buildingType: _buildingType,
        buildingDescription: _buildingDescCtrl.text.trim(),
        ward: widget.address?.ward ?? '',
        district: widget.address?.district ?? '',
        latitude: widget.address?.latitude,
        longitude: widget.address?.longitude,
      );
      if (widget.onSave == null) {
        _close(result);
        return;
      }
      setState(() {
        _savingAddress = true;
        _saveError = null;
      });
      try {
        final saved = await widget.onSave!(result);
        if (!mounted) return;
        if (saved) {
          _close(result);
          return;
        }
        setState(
          () => _saveError =
              widget.saveError?.call() ??
              'Không thể lưu địa chỉ. Vui lòng kiểm tra thông tin.',
        );
      } catch (_) {
        if (mounted)
          setState(
            () => _saveError = 'Không thể lưu địa chỉ. Vui lòng thử lại.',
          );
      } finally {
        if (mounted) setState(() => _savingAddress = false);
      }
    }
  }

  InputDecoration _inputDecor({
    required String labelText,
    String? hintText,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      isDense: true,
      labelText: labelText,
      floatingLabelBehavior: FloatingLabelBehavior.always,
      labelStyle: const TextStyle(
        fontSize: 13,
        color: Color(0xFF64748B),
        fontWeight: FontWeight.w600,
      ),
      floatingLabelStyle: const TextStyle(
        fontSize: 13,
        color: AppColors.primary,
        fontWeight: FontWeight.w700,
      ),
      hintText: hintText,
      hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
      prefixIcon: Icon(icon, size: 20, color: AppColors.primary),
      prefixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 48),
      suffixIcon: suffixIcon,
      suffixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 48),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.address != null;

    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 740),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 18, 16, 14),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Color(0xFFF1F5F9), width: 1),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.mint,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(
                      isEdit
                          ? Icons.edit_location_alt_rounded
                          : Icons.add_location_alt_rounded,
                      color: AppColors.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEdit ? 'Sửa thông tin địa chỉ' : 'Thêm địa chỉ mới',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.navy,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Nhập thông tin địa chỉ để thuận tiện đặt dịch vụ',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.muted,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => _close(),
                    icon: const Icon(Icons.close_rounded),
                    color: AppColors.muted,
                    tooltip: 'Đóng',
                  ),
                ],
              ),
            ),

            // Form Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. GỢI Ý TÊN ĐỊA CHỈ (1 dòng kéo ngang mượt mà)
                      const Text(
                        'Gợi ý tên địa chỉ',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.navy,
                        ),
                      ),
                      const SizedBox(height: 6),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          children: _labelSuggestions.map((item) {
                            final label = item.$1;
                            final icon = item.$2;
                            final isSelected = _labelCtrl.text.trim() == label;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: InkWell(
                                onTap: () {
                                  setState(() {
                                    _labelCtrl.text = label;
                                    if (label == 'Nhà riêng') {
                                      _buildingType = 'Nhà riêng';
                                    } else if (label == 'Căn hộ') {
                                      _buildingType = 'Chung cư';
                                    } else {
                                      _buildingType = 'Khác';
                                    }
                                  });
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? AppColors.primary
                                        : const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSelected
                                          ? AppColors.primary
                                          : Colors.transparent,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        icon,
                                        size: 16,
                                        color: isSelected
                                            ? Colors.white
                                            : AppColors.navy,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        label,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: isSelected
                                              ? Colors.white
                                              : AppColors.navy,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // TÊN ĐỊA CHỈ (Chiều cao chuẩn 48-50px bằng icon, có nhãn viền trên giống hình mẫu)
                      TextFormField(
                        controller: _labelCtrl,
                        maxLines: 1,
                        decoration: _inputDecor(
                          labelText: 'Tên địa chỉ *',
                          hintText: 'VD: Nhà riêng, Căn hộ Sunrise...',
                          icon: Icons.bookmark_outline,
                          suffixIcon: _labelCtrl.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(
                                    Icons.clear_rounded,
                                    size: 18,
                                  ),
                                  onPressed: () =>
                                      setState(() => _labelCtrl.clear()),
                                )
                              : null,
                        ),
                        onChanged: (_) => setState(() {}),
                        validator: (v) => (v?.trim().isEmpty ?? true)
                            ? 'Vui lòng nhập tên địa chỉ'
                            : null,
                      ),
                      const SizedBox(height: 14),

                      // 2. CHỌN LOẠI NHÀ (3 nút 1 hàng)
                      const Text(
                        'Loại bất động sản',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.navy,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: _buildingTypes.map((type) {
                          final isSelected = _buildingType == type.$1;
                          return Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(
                                right: type != _buildingTypes.last ? 8 : 0,
                              ),
                              child: InkWell(
                                onTap: () =>
                                    setState(() => _buildingType = type.$1),
                                borderRadius: BorderRadius.circular(12),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? AppColors.mint
                                        : const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSelected
                                          ? AppColors.primary
                                          : const Color(0xFFE2E8F0),
                                      width: isSelected ? 1.5 : 1.0,
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        type.$2,
                                        size: 20,
                                        color: isSelected
                                            ? AppColors.primary
                                            : const Color(0xFF64748B),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        type.$1,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: isSelected
                                              ? AppColors.primary
                                              : AppColors.navy,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 14),

                      // 3. ĐỊA CHỈ CHI TIẾT (Khung cố định chuẩn 48-50px bằng icon, có nhãn viền trên)
                      TextFormField(
                        controller: _detailCtrl,
                        maxLines: 1,
                        decoration: _inputDecor(
                          labelText: 'Địa chỉ chi tiết *',
                          hintText: 'Số nhà, tên đường, phường/xã...',
                          icon: Icons.location_on_outlined,
                          suffixIcon: _detailCtrl.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(
                                    Icons.clear_rounded,
                                    size: 18,
                                  ),
                                  onPressed: () =>
                                      setState(() => _detailCtrl.clear()),
                                )
                              : null,
                        ),
                        onChanged: (_) => setState(() {}),
                        validator: (v) {
                          if (v?.trim().isEmpty ?? true) {
                            return 'Vui lòng nhập địa chỉ chi tiết';
                          }
                          if (v!.trim().length < 5) {
                            return 'Địa chỉ chi tiết cần tối thiểu 5 ký tự';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      // 4. MÔ TẢ VỊ TRÍ / TÒA NHÀ (Tầng, số phòng, block...)
                      TextFormField(
                        controller: _buildingDescCtrl,
                        maxLines: 1,
                        decoration: _inputDecor(
                          labelText: 'Mô tả vị trí',
                          hintText: 'Số tầng, phòng, tòa nhà, block...',
                          icon: Icons.apartment_outlined,
                        ),
                      ),
                      const SizedBox(height: 14),

                      DropdownButtonFormField<String>(
                        key: ValueKey(
                          _cityAreas
                              .map((a) => '${a['city']}:${a['recruiting']}')
                              .join(','),
                        ),
                        initialValue:
                            _cityAreas.any((a) => a['city'] == _cityCtrl.text)
                            ? _cityCtrl.text
                            : null,
                        isExpanded: true,
                        menuMaxHeight: 280,
                        decoration: _inputDecor(
                          labelText: 'Tỉnh / thành phố *',
                          hintText: _loadingCities
                              ? 'Đang tải khu vực…'
                              : 'Chọn tỉnh / thành phố',
                          icon: Icons.location_city_outlined,
                        ),
                        items: _cityAreas
                            .map(
                              (a) => DropdownMenuItem<String>(
                                value: a['city'].toString(),
                                child: Text(
                                  '${a['city']}${a['recruiting'] == true ? '' : ' — Bảo trì'}',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: _loadingCities
                            ? null
                            : (value) =>
                                  setState(() => _cityCtrl.text = value ?? ''),
                        validator: (_) => _cityCtrl.text.trim().isEmpty
                            ? 'Vui lòng chọn tỉnh/thành phố'
                            : null,
                      ),
                      if (_cityError != null)
                        TextButton(
                          onPressed: _loadCities,
                          child: Text(_cityError!),
                        ),
                      if (!_loadingCities &&
                          _cityCtrl.text.isNotEmpty &&
                          !_cityAreas.any(
                            (a) =>
                                a['city'] == _cityCtrl.text &&
                                a['recruiting'] == true,
                          ))
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text(
                            'Khu vực đang bảo trì hoặc chưa được mở. Vui lòng đổi khu vực khi đặt dịch vụ.',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      const SizedBox(height: 14),

                      // 6. GHI CHÚ CHO PARTNER (chuẩn 48-50px)
                      TextFormField(
                        controller: _noteCtrl,
                        maxLines: 1,
                        decoration: _inputDecor(
                          labelText: 'Ghi chú cho Partner',
                          hintText: 'VD: Bấm chuông cửa, gọi trước...',
                          icon: Icons.notes_rounded,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 7. THÔNG TIN NGƯỜI LIÊN HỆ TẠI ĐỊA CHỈ NÀY
                      Container(
                        padding: const EdgeInsets.all(14),
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
                                const Icon(
                                  Icons.contact_phone_rounded,
                                  color: AppColors.primary,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                const Expanded(
                                  child: Text(
                                    'Người liên hệ tại địa chỉ này',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.navy,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Số điện thoại riêng của từng địa chỉ (không gắn vào SĐT tài khoản cá nhân)',
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(height: 10),

                            // Tên người liên hệ
                            TextFormField(
                              controller: _contactNameCtrl,
                              maxLines: 1,
                              decoration: _inputDecor(
                                labelText: 'Tên người liên hệ',
                                hintText: 'VD: Anh Nam, Chị Lan...',
                                icon: Icons.person_outline_rounded,
                              ),
                            ),
                            const SizedBox(height: 10),

                            // SĐT người liên hệ
                            TextFormField(
                              controller: _contactPhoneCtrl,
                              maxLines: 1,
                              validator: (value) =>
                                  value != null &&
                                      value.trim().isNotEmpty &&
                                      !RegExp(r'^0[0-9]{9}$')
                                          .hasMatch(value.trim())
                                  ? 'Số điện thoại phải có 10 chữ số, bắt đầu bằng 0'
                                  : null,
                              keyboardType: TextInputType.phone,
                              decoration: _inputDecor(
                                labelText: 'Số điện thoại liên hệ',
                                hintText: 'Số điện thoại riêng của địa chỉ này',
                                icon: Icons.phone_outlined,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // 8. ĐẶT LÀM ĐỊA CHỈ MẶC ĐỊNH
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.star_rounded,
                              color: AppColors.primary,
                              size: 22,
                            ),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Text(
                                'Đặt làm địa chỉ mặc định',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.navy,
                                ),
                              ),
                            ),
                            Switch(
                              value: _isDefault,
                              activeThumbColor: AppColors.primary,
                              activeTrackColor: AppColors.mint,
                              onChanged: (val) =>
                                  setState(() => _isDefault = val),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            if (_saveError != null)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                child: Text(
                  _saveError!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            if (_savingAddress) const LinearProgressIndicator(),
            // Bottom Action Buttons
            Container(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: Color(0xFFF1F5F9), width: 1),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _close(),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 50),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Hủy',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.muted,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: _savingAddress ? null : _submit,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 50),
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.check_circle_rounded, size: 20),
                      label: Text(
                        widget.address == null ? 'Lưu địa chỉ' : 'Cập nhật',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
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
}
