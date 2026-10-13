part of 'customer_view.dart';

extension _BookingScreens on _CustomerViewState {
  List<Widget> authScreens() {
    switch (c.route.page) {
      case PageId.splash:
        return [
          const SizedBox(height: 70),
          const Icon(Icons.task_alt, color: AppColors.primary, size: 90),
          const SizedBox(height: 20),
          Center(
            child: Text(
              'TaskLy',
              style: Theme.of(context).textTheme.headlineLarge,
            ),
          ),
          const SizedBox(height: 12),
          const Text('Việc nhỏ trong tầm tay.', textAlign: TextAlign.center),
          const SizedBox(height: 48),
          PrimaryButton(
            'Bắt đầu',
            () => c.replace(PageId.onboarding),
            icon: Icons.arrow_forward,
          ),
          info('Bản Customer • Không kết nối thanh toán hay backend thật.'),
        ];
      case PageId.onboarding:
        return [
          heading(
            'Thêm thời gian\ncho điều bạn yêu thích.',
            'Kết nối với người hỗ trợ việc nhà quanh bạn.',
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Image.asset(
              data.config.sampleImages.last,
              height: 220,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 24),
          info(
            'Đặt lịch theo nhu cầu, theo dõi tiến trình và đánh giá sau khi hoàn tất.',
          ),
          detailRow(
            Icons.handshake_outlined,
            'Bạn chủ động lựa chọn',
            'Xem hồ sơ Tasker trước khi ghép việc.',
          ),
          detailRow(
            Icons.receipt_long,
            'Chi phí rõ ràng',
            'Xem chi tiết trước khi đăng và trước khi thanh toán.',
          ),
          const SizedBox(height: 20),
          PrimaryButton('Tiếp tục đăng nhập', () => c.replace(PageId.login)),
        ];
      case PageId.login:
      case PageId.register:
      case PageId.recovery:
        final registering = c.route.page == PageId.register;
        return [
          heading(
            registering
                ? 'Rất vui được gặp bạn.'
                : c.route.page == PageId.recovery
                ? 'Lấy lại quyền truy cập'
                : 'Chào bạn trở lại 👋',
            'Đăng nhập bằng số điện thoại và mã OTP. Không cần mật khẩu trong chế độ mô phỏng.',
          ),
          if (registering)
            field(
              'Họ và tên',
              c.registrationName,
              (v) => c.registrationName = v,
            ),
          field(
            'Số điện thoại',
            c.phone,
            (v) => c.phone = v,
            keyboard: TextInputType.phone,
            key: ValueKey('phone-${c.phone == data.config.phone}'),
          ),
          if (c.demoMode)
            OutlinedButton.icon(
              onPressed: () {
                c.phone = data.config.phone;
                c.changed();
              },
              icon: const Icon(Icons.science_outlined),
              label: const Text('Điền tài khoản mẫu'),
            ),
          const SizedBox(height: 16),
          PrimaryButton('Nhận mã OTP', () {
            if (registering && c.registrationName.trim().length < 2) {
              c.error = 'Nhập họ tên ít nhất 2 ký tự.';
              c.changed();
            } else {
              c.sendOtp();
            }
          }),
          if (c.route.page == PageId.login) ...[
            if (widget.onOpenTasker != null)
              OutlinedButton.icon(
                onPressed: widget.onOpenTasker,
                icon: const Icon(Icons.work_outline),
                label: const Text('Đăng nhập với vai trò Tasker'),
              ),
            TextButton(
              onPressed: () => c.open(PageId.register),
              child: const Text('Chưa có tài khoản? Đăng ký'),
            ),
            TextButton(
              onPressed: () => c.open(PageId.recovery),
              child: const Text('Quên mật khẩu / Khôi phục truy cập'),
            ),
          ],
          info(
            'OTP và tài khoản chỉ được mô phỏng trong phiên hiện tại. Không gửi SMS thật.',
            icon: Icons.lock_outline,
          ),
        ];
      case PageId.otp:
        return [
          heading(
            'Kiểm tra mã xác minh',
            'Mã được gửi mô phỏng đến ${c.phone}',
          ),
          field(
            'Mã OTP 6 số',
            c.otp,
            (v) => c.otp = v,
            keyboard: TextInputType.number,
            maxLength: 6,
          ),
          if (c.demoMode)
            info(
              'Mã OTP mẫu: ${data.config.otp}',
              icon: Icons.science_outlined,
            ),
          PrimaryButton('Xác minh & tiếp tục', c.verifyOtp),
          TextButton(
            onPressed: c.resendOtp,
            child: const Text('Gửi lại mã OTP'),
          ),
          TextButton(onPressed: c.back, child: const Text('Đổi số điện thoại')),
        ];
      default:
        return [
          heading(
            'Bạn muốn làm việc ở đâu?',
            'Bạn luôn có thể nhập địa chỉ thủ công.',
          ),
          const Icon(
            Icons.near_me_outlined,
            size: 88,
            color: AppColors.primary,
          ),
          const SizedBox(height: 28),
          info(
            'Vị trí trong mẫu lấy từ địa chỉ đã lưu; ứng dụng không truy cập GPS thiết bị.',
          ),
          PrimaryButton('Dùng địa chỉ đã lưu', () => c.root(PageId.home)),
          OutlinedButton(
            onPressed: () => c.root(PageId.home),
            child: const Text('Để sau, tôi sẽ tự nhập địa chỉ'),
          ),
        ];
    }
  }

  List<Widget> serviceList() {
    final services = data.services
        .where((s) => s.name.toLowerCase().contains(c.search.toLowerCase()))
        .toList();
    final categories = [...data.categories];
    final selected = categories
        .where((category) => category.id == c.categoryFilter)
        .firstOrNull;
    if (selected != null) {
      categories.remove(selected);
      categories.insert(0, selected);
    }
    return [
      const Padding(
        padding: EdgeInsets.only(top: 8, bottom: 16),
        child: Text(
          'Khám phá TaskLy',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
      ),
      field('Tìm dịch vụ', c.search, (value) {
        c.search = value;
        c.changed();
      }),
      if (services.isEmpty)
        const EmptyState('Chưa có dịch vụ', 'Thử tìm dịch vụ khác.'),
      for (final category in categories)
        if (services.any((s) => s.categoryId == category.id))
          categoryServices(
            category.name,
            services.where((s) => s.categoryId == category.id).toList(),
            category.id,
          ),
      if (services.any(
        (s) => !categories.any((category) => category.id == s.categoryId),
      ))
        categoryServices(
          'Dịch vụ khác',
          services
              .where(
                (s) =>
                    !categories.any((category) => category.id == s.categoryId),
              )
              .toList(),
          'other',
        ),
    ];
  }

  Widget categoryServices(String name, List<Service> services, String id) =>
      Container(
        key: ValueKey('category-section-$id'),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFEAEDEF)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x08000000),
              blurRadius: 10,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Divider(height: 1, color: Color(0xFFEAEDEF)),
            ),
            LayoutBuilder(
              builder: (context, box) => Wrap(
                spacing: 10,
                runSpacing: 14,
                children: [
                  for (final service in services)
                    SizedBox(
                      width: (box.maxWidth - 20) / 3,
                      child: InkWell(
                        key: ValueKey('category-service-${service.id}'),
                        onTap: () =>
                            c.open(PageId.serviceDetail, id: service.id),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Column(
                            children: [
                              ServiceSymbol.forService(service, size: 38),
                              const SizedBox(height: 8),
                              Text(
                                service.name,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 11,
                                  height: 1.35,
                                  fontWeight: FontWeight.w600,
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
          ],
        ),
      );

  List<Widget> serviceDetail() {
    final service = data.service(c.route.id!);
    return [
      ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child:
            c.demoMode &&
                service.iconUrl.isEmpty &&
                service.displayIconKey == 'cleaning'
            ? Image.asset(
                data.config.sampleImages.last,
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
              )
            : Container(
                height: 160,
                color: AppColors.mint,
                child: Center(
                  child: ServiceSymbol.forService(
                    service,
                    size: 110,
                    iconSize: 80,
                  ),
                ),
              ),
      ),
      heading(service.name, service.description),
      info(
        c.demoMode
            ? 'Giá tham khảo từ ${money(service.hourlyRate)}${service.priceUnit}. Xem tổng chi phí ở bước xác nhận.'
            : 'Giá tham khảo từ ${money(service.hourlyRate)}. Đây không phải báo giá cho lần đặt của bạn.',
      ),
      if (service.checklist.isNotEmpty) section('Công việc bao gồm'),
      ...service.checklist.map(
        (item) => detailRow(Icons.check_circle_outline, 'Hạng mục', item),
      ),
      const SizedBox(height: 20),
      PrimaryButton(
        'Chọn dịch vụ này',
        () => c.startCreate(serviceId: service.id),
        icon: Icons.arrow_forward,
      ),
    ];
  }

  List<Widget> createScreen() {
    final d = c.draft!;
    const steps = [
      'Chọn dịch vụ',
      'Địa điểm thực hiện',
      'Thời gian & thời lượng',
      'Mô tả & ảnh thực tế',
      'Dụng cụ & lưu ý',
      'Ngân sách & thanh toán',
      'Xác nhận & đăng việc',
    ];
    final content = <Widget>[
      Row(
        children: [
          Text(
            'BƯỚC ${c.wizardStep + 1}/${steps.length}',
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
          const Spacer(),
          Text('${((c.wizardStep + 1) / steps.length * 100).round()}%'),
        ],
      ),
      const SizedBox(height: 10),
      ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: LinearProgressIndicator(
          value: (c.wizardStep + 1) / steps.length,
          minHeight: 6,
          backgroundColor: AppColors.border,
        ),
      ),
      heading(steps[c.wizardStep]),
    ];
    switch (c.wizardStep) {
      case 0:
        content.addAll(
          data.services.map(
            (s) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                tileColor: d.serviceId == s.id ? AppColors.mint : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                leading: ServiceSymbol.forService(s),
                title: Text(
                  s.name,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(s.subtitle),
                trailing: Icon(
                  d.serviceId == s.id
                      ? Icons.check_circle
                      : Icons.circle_outlined,
                  color: AppColors.primary,
                ),
                onTap: () => c.updateDraft((draft) {
                  draft.serviceId = s.id;
                  draft.labor = null;
                }),
              ),
            ),
          ),
        );
      case 1:
        content.addAll([
          MockMap(
            d.address.detail.isEmpty
                ? data.config.mapDescription
                : d.address.detail,
          ),
          field(
            'Địa chỉ chi tiết',
            d.address.detail,
            (v) => d.address = Address(
              d.address.id,
              d.address.label,
              v,
              d.address.note,
            ),
            key: ValueKey('address-${d.address.id}'),
          ),
          field(
            'Phòng, tầng & hướng dẫn',
            d.address.note,
            (v) => d.address = Address(
              d.address.id,
              d.address.label,
              d.address.detail,
              v,
            ),
            key: ValueKey('note-${d.address.id}'),
          ),
          if ({'moving', 'delivery'}.contains(d.serviceId))
            field('Địa chỉ điểm đến', d.destination, (v) => d.destination = v),
          section(
            'Địa chỉ đã lưu',
            action: 'Quản lý',
            onTap: () => c.open(PageId.addresses),
          ),
          ...data.addresses.map(
            (a) => menu(a.label, Icons.location_on_outlined, () {
              d.address = a;
              c.changed();
            }, subtitle: a.detail),
          ),
          info(
            'Bạn có thể nhập địa chỉ thủ công. Bản đồ chỉ minh họa minh họa.',
          ),
        ]);
      case 2:
        content.addAll([
          menu(dateLabel(d.scheduledAt), Icons.calendar_month, () async {
            final day = await showDatePicker(
              context: context,
              initialDate: d.scheduledAt.isBefore(DateTime.now())
                  ? DateTime.now()
                  : d.scheduledAt,
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 365)),
            );
            if (day != null) {
              c.updateDraft(
                (draft) => draft.scheduledAt = DateTime(
                  day.year,
                  day.month,
                  day.day,
                  d.scheduledAt.hour,
                  d.scheduledAt.minute,
                ),
              );
            }
          }, subtitle: 'Ngày thực hiện'),
          menu(timeLabel(d.scheduledAt), Icons.schedule, () async {
            final time = await showTimePicker(
              context: context,
              initialTime: TimeOfDay.fromDateTime(d.scheduledAt),
            );
            if (time != null) {
              c.updateDraft(
                (draft) => draft.scheduledAt = DateTime(
                  d.scheduledAt.year,
                  d.scheduledAt.month,
                  d.scheduledAt.day,
                  time.hour,
                  time.minute,
                ),
              );
            }
          }, subtitle: 'Giờ bắt đầu'),
          section('Thời lượng dự kiến'),
          Wrap(
            spacing: 10,
            children: [1, 2, 3, 4, 6, 8]
                .map(
                  (hours) => ChoiceChip(
                    label: Text('$hours giờ'),
                    selected: d.duration == hours,
                    onSelected: (_) => c.updateDraft((draft) {
                      draft.duration = hours;
                      draft.labor = null;
                    }),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 20),
          info(
            'Dự kiến kết thúc ${timeLabel(d.scheduledAt.add(Duration(hours: d.duration)))} ngày ${dateLabel(d.scheduledAt.add(Duration(hours: d.duration)))}.',
          ),
        ]);
      case 3:
        content.addAll([
          menu(
            'Dùng gợi ý TaskLy AI',
            Icons.auto_awesome,
            () => c.open(PageId.ai),
          ),
          field(
            'Mô tả công việc',
            d.description,
            (v) => d.description = v,
            lines: 5,
            maxLength: 500,
          ),
          section('Ảnh thực tế (${d.images.length}/4)'),
          imagePicker(d.images, () => c.changed()),
          info(
            'Chọn ảnh mẫu để mô phỏng đính kèm. Không tải ảnh cá nhân lên máy chủ.',
          ),
        ]);
      case 4:
        content.addAll([
          Panel(
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Cần Tasker mang dụng cụ'),
              subtitle: Text(
                '+${money(data.config.equipmentFee)} • có thể tắt nếu nhà đã có',
              ),
              value: d.equipment,
              onChanged: (v) => c.updateDraft((draft) => draft.equipment = v),
            ),
          ),
          section('Lưu ý cho Tasker'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: data.config.requirements
                .map(
                  (note) => FilterChip(
                    label: Text(note),
                    selected: d.note.contains(note),
                    onSelected: (selected) {
                      d.note = selected
                          ? '${d.note}\n$note'.trim()
                          : d.note.replaceAll(note, '').trim();
                      c.changed();
                    },
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 20),
          field(
            'Ghi chú bổ sung',
            d.note,
            (v) => d.note = v,
            lines: 3,
            maxLength: 300,
            key: ValueKey('requirements-${d.note.hashCode}'),
          ),
        ]);
      case 5:
        final quote = c.draftQuote!;
        final suggestion = c.suggestion!;
        content.addAll([
          info(
            'Gợi ý giá AI (mô phỏng): ${money(suggestion.minimum)} – ${money(suggestion.maximum)} cho ${d.duration} giờ.',
            icon: Icons.auto_awesome,
          ),
          Wrap(
            spacing: 8,
            children:
                [suggestion.minimum, suggestion.recommended, suggestion.maximum]
                    .map(
                      (price) => ChoiceChip(
                        label: Text(money(price)),
                        selected: quote.labor == price,
                        onSelected: (_) =>
                            c.updateDraft((draft) => draft.labor = price),
                      ),
                    )
                    .toList(),
          ),
          const SizedBox(height: 16),
          Panel(
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Bảo vệ công việc'),
              subtitle: Text(
                '+${money(data.config.protectionFee)} • chính sách mẫu',
              ),
              value: d.protection,
              onChanged: (v) => c.updateDraft((draft) => draft.protection = v),
            ),
          ),
          section(
            'Ngân hàng',
            action: 'Quản lý',
            onTap: () => c.open(PageId.paymentMethods),
          ),
          ...data.methods.map(
            (m) => methodTile(
              m,
              d.paymentMethodId,
              () => c.updateDraft((draft) => draft.paymentMethodId = m.id),
            ),
          ),
          if (data.methods.isEmpty)
            const EmptyState(
              'Chưa có ngân hàng',
              'Thêm ngân hàng để tiếp tục.',
            ),
          PriceSummary(quote),
          info(
            'Chưa thu tiền khi đăng việc. Mô phỏng thanh toán một lần sau khi bạn nghiệm thu.',
          ),
        ]);
      case 6:
        content.addAll([
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                detailRow(
                  serviceIcon(data.service(d.serviceId).displayIconKey),
                  'Dịch vụ',
                  data.service(d.serviceId).name,
                  leading: ServiceSymbol.forService(
                    data.service(d.serviceId),
                    size: 22,
                  ),
                ),
                detailRow(
                  Icons.location_on_outlined,
                  'Địa điểm',
                  '${d.address.detail}\n${d.address.note}${d.destination.isEmpty ? '' : '\nĐiểm đến: ${d.destination}'}',
                ),
                detailRow(
                  Icons.calendar_month,
                  'Thời gian',
                  '${dateLabel(d.scheduledAt)} • ${timeLabel(d.scheduledAt)} • ${d.duration} giờ',
                ),
                detailRow(Icons.notes, 'Mô tả', d.description),
                if (d.note.isNotEmpty)
                  detailRow(Icons.info_outline, 'Lưu ý', d.note),
              ],
            ),
          ),
          if (d.images.isNotEmpty) imageStrip(d.images),
          PriceSummary(c.draftQuote!),
          info(
            'Thông tin và chi phí này sẽ được giữ nguyên trong chi tiết công việc. Chưa có giao dịch tiền thật.',
          ),
          Wrap(
            spacing: 8,
            children: [
              TextButton(
                onPressed: () {
                  c.wizardStep = 1;
                  c.changed();
                },
                child: const Text('Sửa địa điểm'),
              ),
              TextButton(
                onPressed: () {
                  c.wizardStep = 5;
                  c.changed();
                },
                child: const Text('Sửa chi phí'),
              ),
            ],
          ),
        ]);
    }
    content.addAll([
      const SizedBox(height: 20),
      PrimaryButton(
        c.wizardStep == 6
            ? 'Đăng công việc • ${money(c.draftQuote!.total)}'
            : 'Tiếp tục',
        c.busy
            ? null
            : c.wizardStep == 6
            ? c.post
            : c.nextStep,
        icon: Icons.arrow_forward,
      ),
      if (c.wizardStep > 0)
        OutlinedButton(
          onPressed: c.previousStep,
          child: const Text('Quay lại bước trước'),
        ),
    ]);
    return content;
  }

  Widget methodTile(PaymentMethod method, String selected, VoidCallback tap) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: ListTile(
          tileColor: selected == method.id ? AppColors.mint : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          leading: const Icon(
            Icons.account_balance_wallet_outlined,
            color: AppColors.primary,
          ),
          title: Text(method.name),
          subtitle: Text(method.detail),
          trailing: Icon(
            selected == method.id
                ? Icons.radio_button_checked
                : Icons.radio_button_off,
            color: AppColors.primary,
          ),
          onTap: tap,
        ),
      );
  Widget imageStrip(List<String> images) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Wrap(
      spacing: 10,
      runSpacing: 10,
      children: images
          .map(
            (asset) => ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(
                asset,
                width: 128,
                height: 110,
                fit: BoxFit.cover,
              ),
            ),
          )
          .toList(),
    ),
  );
  Widget imagePicker(List<String> images, VoidCallback changed) => Column(
    children: [
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: images
            .asMap()
            .entries
            .map(
              (entry) => Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      entry.value,
                      width: 130,
                      height: 120,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    right: 0,
                    top: 0,
                    child: IconButton.filled(
                      tooltip: 'Xóa ảnh',
                      onPressed: () {
                        images.removeAt(entry.key);
                        changed();
                      },
                      icon: const Icon(Icons.close, size: 18),
                    ),
                  ),
                ],
              ),
            )
            .toList(),
      ),
      const SizedBox(height: 12),
      if (images.length < 4)
        OutlinedButton.icon(
          onPressed: () async {
            final selected = await showModalBottomSheet<String>(
              context: context,
              showDragHandle: true,
              builder: (ctx) => SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Chọn ảnh mẫu minh họa',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 16,
                        children: data.config.sampleImages
                            .map(
                              (asset) => InkWell(
                                onTap: () => Navigator.pop(ctx, asset),
                                child: Image.asset(
                                  asset,
                                  width: 125,
                                  height: 115,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            );
            if (selected != null) {
              images.add(selected);
              changed();
            }
          },
          icon: const Icon(Icons.add_a_photo_outlined),
          label: const Text('Thêm ảnh mẫu'),
        ),
      const SizedBox(height: 16),
    ],
  );

  List<Widget> aiScreen() => [
    heading(
      'Bạn cần hỗ trợ điều gì?',
      'AI chỉ tạo bản nháp. Bạn luôn kiểm tra và xác nhận trước khi đăng.',
    ),
    field(
      'Mô tả yêu cầu',
      c.aiInput,
      (v) => c.aiInput = v,
      lines: 3,
      key: ValueKey('ai-${c.aiInput == data.config.aiExample}'),
    ),
    TextButton(
      onPressed: () {
        c.aiInput = data.config.aiExample;
        c.changed();
      },
      child: const Text('Dùng yêu cầu mẫu'),
    ),
    PrimaryButton('Tạo gợi ý AI', c.generateAi, icon: Icons.auto_awesome),
    if (c.aiDraft != null) ...[
      info(
        'Bản nháp mô phỏng đã sẵn sàng. Nhấn chỉnh sửa để kiểm tra ngày, giờ, địa điểm và dịch vụ.',
      ),
      Panel(
        child: Column(
          children: [
            detailRow(
              Icons.cleaning_services,
              'Dịch vụ',
              data.service(c.aiDraft!.serviceId).name,
            ),
            detailRow(
              Icons.place_outlined,
              'Địa điểm',
              c.aiDraft!.address.detail,
            ),
            detailRow(
              Icons.schedule,
              'Lịch',
              '${dateLabel(c.aiDraft!.scheduledAt)} • ${timeLabel(c.aiDraft!.scheduledAt)} • ${c.aiDraft!.duration} giờ',
            ),
            detailRow(Icons.notes, 'Mô tả', c.aiDraft!.description),
          ],
        ),
      ),
      PrimaryButton('Dùng bản nháp & chỉnh sửa', c.applyAi),
      OutlinedButton(
        onPressed: () {
          c.aiDraft = null;
          c.changed();
        },
        child: const Text('Bỏ gợi ý'),
      ),
    ],
  ];
}
