import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../auth/api.dart';
import 'partner_ui_kit.dart';

class RecruitmentFinalDocuments extends StatefulWidget {
  const RecruitmentFinalDocuments({
    super.key,
    required this.session,
    this.initialPortrait,
    this.initialContract,
    this.readOnly = false,
  });

  final Session session;
  final String? initialPortrait;
  final String? initialContract;
  final bool readOnly;

  @override
  State<RecruitmentFinalDocuments> createState() => _FinalDocumentsState();
}

class _FinalDocumentsState extends State<RecruitmentFinalDocuments> {
  String? portrait;
  String? contract;
  String? submittedAt;
  String? error;
  bool busy = false;
  bool loadingInitial = false;
  bool hasAgreedPolicy = false;
  bool serverReadOnly = false;
  bool approved = false;
  bool documentsLoaded = false;
  bool get readOnly => widget.readOnly || serverReadOnly;

  StreamSubscription<void>? _liveSubscription;
  @override
  void initState() {
    super.initState();
    _liveSubscription = widget.session.liveChanges.listen((_) { if (mounted) _loadExistingDocuments(background: true); });
    portrait = widget.initialPortrait;
    contract = widget.initialContract;
    if (portrait != null && contract != null) {
      hasAgreedPolicy = true;
    }
    _loadExistingDocuments();
  }

  @override
  void dispose() { _liveSubscription?.cancel(); super.dispose(); }

  bool _fetching = false;
  Future<void> _loadExistingDocuments({bool background = false}) async {
    if (_fetching || busy) return;
    _fetching = true;
    if (!background) setState(() => loadingInitial = true);
    try {
      final res = await widget.session.request('/partner/final-documents');
      if (!mounted) return;
      documentsLoaded = true;
      if (res is List && res.isNotEmpty) {
        final doc = Map<String, dynamic>.from(res.first as Map);
        setState(() {
          serverReadOnly = doc['read_only'] == true;
          approved = doc['approved'] == true;
          portrait ??= doc['portrait'] as String?;
          contract ??= doc['contract'] as String?;
          submittedAt = doc['submitted_at']?.toString();
          if (portrait != null && contract != null) {
            hasAgreedPolicy = true;
          }
        });
      }
    } catch (_) {
      if (mounted) setState(() => error = 'Không thể tải hồ sơ đã gửi. Vui lòng mở lại để thử lại.');
    } finally {
      _fetching = false;
      if (mounted) setState(() => loadingInitial = false);
    }
  }

  Uint8List? _decodeBytes(String? dataUri) {
    if (dataUri == null || dataUri.isEmpty) return null;
    try {
      final commaIndex = dataUri.indexOf(',');
      final base64Str = commaIndex >= 0
          ? dataUri.substring(commaIndex + 1)
          : dataUri;
      return base64Decode(base64Str.trim());
    } catch (_) {
      return null;
    }
  }

  Future<void> pick(bool face) async {
    if (readOnly || !documentsLoaded || loadingInitial || busy) return;
    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png'],
      );
      if (file == null || !mounted || readOnly) return;
      final bytes = await file.readAsBytes();
      if (bytes.length > 2000000) {
        setState(
          () => error =
              'Dung lượng ảnh vượt quá 2 MB. Vui lòng chọn ảnh nhẹ hơn.',
        );
        return;
      }
      final png = bytes.length > 4 && bytes[0] == 0x89 && bytes[1] == 0x50;
      final mime = png ? 'image/png' : 'image/jpeg';
      final image = 'data:$mime;base64,${base64Encode(bytes)}';
      setState(() {
        if (face) {
          portrait = image;
        } else {
          contract = image;
        }
        error = null;
      });
      HapticFeedback.selectionClick();
    } catch (e) {
      if (mounted) {
        setState(() => error = 'Không thể chọn ảnh: $e');
      }
    }
  }

  void _removeImage(bool face) {
    if (readOnly || !documentsLoaded || loadingInitial || busy) return;
    setState(() {
      if (face) {
        portrait = null;
      } else {
        contract = null;
      }
      error = null;
    });
    HapticFeedback.lightImpact();
  }

  Future<void> submit() async {
    if (readOnly || !documentsLoaded || loadingInitial || busy) return;
    if (portrait == null || contract == null) {
      setState(
        () =>
            error = 'Vui lòng cung cấp đủ cả ảnh chân dung và hợp đồng đã ký.',
      );
      return;
    }
    if (!hasAgreedPolicy) {
      setState(
        () => error = 'Vui lòng xác nhận cam kết ảnh chụp tại văn phòng và mặc đồng phục.',
      );
      return;
    }

    setState(() {
      busy = true;
      error = null;
    });

    try {
      await widget.session.request(
        '/partner/final-documents',
        method: 'POST',
        body: {'portrait': portrait, 'contract': contract},
      );
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Gửi hồ sơ chặng 4 thành công! Admin sẽ duyệt trong 2-4 giờ.',
                ),
              ),
            ],
          ),
          backgroundColor: Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => error = 'Không thể gửi hồ sơ: $e');
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final portraitBytes = _decodeBytes(portrait);
    final contractBytes = _decodeBytes(contract);
    if (readOnly) {
      Widget photo(String title, Uint8List? bytes) => Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w700)), const SizedBox(height: 12), if (bytes != null) GestureDetector(onTap: () => showDialog<void>(context: context, builder: (context) => Dialog(child: InteractiveViewer(child: Image.memory(bytes)))), child: Image.memory(bytes, height: 240, width: double.infinity, fit: BoxFit.contain)) else const Text('Chưa có ảnh.'), if (bytes != null) const Text('Bấm ảnh để phóng to')])));
      return Scaffold(appBar: AppBar(title: const Text('Chi tiết hồ sơ chặng 4')), body: loadingInitial ? const Center(child: CircularProgressIndicator()) : ListView(padding: const EdgeInsets.all(16), children: [Text(approved ? 'Đã duyệt chính thức · Hồ sơ chỉ được xem' : 'Đã gửi · Chờ admin kiểm duyệt', style: const TextStyle(fontWeight: FontWeight.w700)), if (submittedAt != null) Text('Thời gian gửi: ${DateTime.tryParse(submittedAt!)?.toLocal().toString().split('.').first ?? submittedAt}'), if (error != null) Text(error!, style: const TextStyle(color: Colors.red)), photo('Ảnh chân dung', portraitBytes), photo('Hợp đồng đã ký', contractBytes)]));
    }
    final canSubmit =
        documentsLoaded && !busy && !loadingInitial && portrait != null && contract != null && hasAgreedPolicy;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFD),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0.5,
        centerTitle: false,
        title: const Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          children: [
            Text(
              'CHẶNG 4/4',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: PartnerColors.primary,
                letterSpacing: 0.5,
              ),
            ),
            Text(
              '• Hồ sơ & Hợp đồng',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: PartnerColors.navy,
              ),
            ),
          ],
        ),
      ),
      body: loadingInitial
          ? const Center(
              child: CircularProgressIndicator(color: PartnerColors.primary),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              children: [
                // Hero Header Banner
                _buildHeroBanner(),
                const SizedBox(height: 16),

                // Notice: Previously submitted
                if (submittedAt != null) ...[
                  _buildSubmittedBanner(submittedAt!),
                  const SizedBox(height: 16),
                ],

                // Error alert
                if (error != null) ...[
                  _buildErrorAlert(error!),
                  const SizedBox(height: 16),
                ],

                // MANDATORY PHOTO REQUIREMENTS CARD
                _buildMandatoryRequirementsCard(),
                const SizedBox(height: 20),

                // DOCUMENT 1: PORTRAIT PHOTO
                _buildPortraitUploadCard(portraitBytes),
                const SizedBox(height: 20),

                // DOCUMENT 2: SIGNED CONTRACT
                _buildContractUploadCard(contractBytes),
                const SizedBox(height: 20),

                // COMMITMENT CHECKBOX
                _buildCommitmentCard(),
              ],
            ),
      bottomSheet: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  onPressed: canSubmit ? submit : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: PartnerColors.primary,
                    disabledBackgroundColor: const Color(0xFFCBD5E1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: canSubmit ? 2 : 0,
                  ),
                  child: busy
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(width: 10),
                            Text(
                              'Đang gửi…',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        )
                      : const Text(
                          'Gửi admin kiểm duyệt',
                          style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Tài khoản sẽ được kích hoạt chính thức sau khi Admin phê duyệt',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11.5,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E3A8A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1E1E3A8A),
            blurRadius: 18,
            offset: Offset(0, 6),
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
                  color: Colors.white.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.verified_user_rounded,
                  color: Color(0xFF60A5FA),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Xác thực & Hoàn tất thủ tục',
                      style: TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Chặng 4: Bước cuối để chính thức nhận việc',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF93C5FD),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'Sau khi bạn đã hoàn tất kiểm tra chuyên môn và nhận đồng phục tại văn phòng, vui lòng gửi ảnh chân dung và ảnh hợp đồng đã ký để hoàn thành hồ sơ.',
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFFE2E8F0),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _buildFeatureBadge(Icons.business_rounded, 'Chụp tại văn phòng'),
              _buildFeatureBadge(Icons.checkroom_rounded, 'Mặc áo đồng phục'),
              _buildFeatureBadge(Icons.draw_rounded, 'Hợp đồng đã ký'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureBadge(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: const Color(0xFF93C5FD)),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmittedBanner(String time) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.task_alt_rounded,
            color: Color(0xFF16A34A),
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Hồ sơ đã được gửi lên hệ thống',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF15803D),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Thời gian gửi: $time. Bạn có thể chọn tải lại ảnh mới nếu cần cập nhật.',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: Color(0xFF166534),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorAlert(String message) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: Color(0xFFDC2626),
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Thông báo lỗi',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFB91C1C),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: Color(0xFF991B1B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// QUY ĐỊNH BẮT BUỘC VỀ ẢNH CHÂN DUNG (VĂN PHÒNG & ĐỒNG PHỤC)
  Widget _buildMandatoryRequirementsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFCD34D), width: 1.4),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0CF59E0B),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFF59E0B)),
                ),
                child: const Icon(
                  Icons.campaign_rounded,
                  color: Color(0xFFB45309),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'QUY ĐỊNH ẢNH CHÂN DUNG BẮT BUỘC',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF92400E),
                        letterSpacing: 0.3,
                      ),
                    ),
                    Text(
                      'Vui lòng đọc kỹ để tránh bị từ chối duyệt',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFFB45309),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildRuleItem(
            icon: Icons.storefront_rounded,
            iconColor: const Color(0xFFB45309),
            title: 'Bắt buộc chụp tại Văn phòng TaskLy',
            desc: 'Ảnh chân dung BẮT BUỘC phải chụp trực tiếp tại văn phòng đại diện TaskLy (tại quầy lễ tân hoặc khu vực backdrop của TaskLy). Ảnh chụp tại nhà riêng, ngoài đường hay quán xá sẽ bị từ chối 100%.',
          ),
          const SizedBox(height: 10),
          _buildRuleItem(
            icon: Icons.checkroom_rounded,
            iconColor: const Color(0xFFB45309),
            title: 'Bắt buộc mặc Áo đồng phục TaskLy',
            desc: 'Bạn bắt buộc phải mặc áo đồng phục chính thức của TaskLy (vừa được phát ở chặng 3). Cổ áo chỉnh tề, logo TaskLy rõ ràng.',
          ),
          const SizedBox(height: 10),
          _buildRuleItem(
            icon: Icons.face_retouching_natural_rounded,
            iconColor: const Color(0xFFB45309),
            title: 'Góc chụp chính diện, rõ nét',
            desc: 'Chụp từ ngực trở lên, thấy rõ khuôn mặt, ánh sáng đầy đủ. Tuyệt đối không đội nón, không đeo kính râm hay khẩu trang.',
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 16,
                  color: Color(0xFF92400E),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Admin sẽ đối chiếu vị trí văn phòng và đồng phục trước khi kích hoạt tài khoản.',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF92400E),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRuleItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String desc,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 18, color: iconColor),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text.rich(
            TextSpan(
              style: const TextStyle(
                fontSize: 12.5,
                color: Color(0xFF78350F),
                height: 1.4,
              ),
              children: [
                TextSpan(
                  text: '$title: ',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                TextSpan(text: desc),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// KHỐI TẢI ẢNH CHÂN DUNG VĂN PHÒNG (MẶC ĐỒNG PHỤC)
  Widget _buildPortraitUploadCard(Uint8List? bytes) {
    final hasImage = bytes != null;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: hasImage ? const Color(0xFF10B981) : const Color(0xFFE2E8F0),
          width: hasImage ? 1.5 : 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x080F172A),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: hasImage
                      ? const Color(0xFFECFDF5)
                      : PartnerColors.softBlue,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  hasImage ? Icons.check_circle_rounded : Icons.badge_rounded,
                  color: hasImage
                      ? const Color(0xFF10B981)
                      : PartnerColors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '1. Ảnh chân dung tại văn phòng',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: PartnerColors.navy,
                      ),
                    ),
                    Text(
                      'Bắt buộc mặc đồng phục & chụp tại VP TaskLy',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: hasImage
                      ? const Color(0xFFECFDF5)
                      : const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: hasImage
                        ? const Color(0xFFA7F3D0)
                        : const Color(0xFFFECACA),
                  ),
                ),
                child: Text(
                  hasImage ? 'ĐÃ CÓ ẢNH' : 'BẮT BUỘC',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: hasImage
                        ? const Color(0xFF059669)
                        : const Color(0xFFDC2626),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // PREVIEW OR PLACEHOLDER
          if (hasImage) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Stack(
                children: [
                  Container(
                    width: double.infinity,
                    height: 220,
                    color: const Color(0xFFF1F5F9),
                    child: Image.memory(
                      bytes,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          const Center(child: Text('Lỗi tải ảnh')),
                    ),
                  ),
                  Positioned(
                    bottom: 8,
                    left: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.check_circle_rounded,
                            size: 14,
                            color: Color(0xFF34D399),
                          ),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Ảnh chân dung văn phòng TaskLy',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
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
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              alignment: WrapAlignment.spaceBetween,
              children: [
                OutlinedButton.icon(
                  onPressed: busy ? null : () => pick(true),
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Chọn ảnh chân dung'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: PartnerColors.primary,
                    side: const BorderSide(color: PartnerColors.softBlueBorder),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: busy ? null : () => _removeImage(true),
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    size: 18,
                    color: Color(0xFFEF4444),
                  ),
                  label: const Text(
                    'Xoá ảnh',
                    style: TextStyle(color: Color(0xFFEF4444)),
                  ),
                ),
              ],
            ),
          ] else ...[
            GestureDetector(
              onTap: busy ? null : () => pick(true),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 24,
                  horizontal: 16,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xFFCBD5E1),
                    style: BorderStyle.solid,
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        color: Color(0xFFEFF6FF),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.add_a_photo_rounded,
                        color: PartnerColors.primary,
                        size: 28,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Tải ảnh chân dung chụp tại Văn phòng TaskLy',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: PartnerColors.navy,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Mặc áo polo TaskLy, rõ mặt chính diện • Tối đa 2 MB (JPG, PNG)',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 14),
                    OutlinedButton(
                      onPressed: busy ? null : () => pick(true),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: PartnerColors.primary,
                        side: const BorderSide(color: PartnerColors.primary),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('Chọn ảnh chân dung'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// KHỐI TẢI ẢNH HỢP ĐỒNG ĐÃ KÝ
  void _viewContractImage(Uint8List bytes) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  tooltip: 'Đóng ảnh hợp đồng',
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ),
              Expanded(
                child: InteractiveViewer(
                  minScale: 1,
                  maxScale: 5,
                  child: Center(
                    child: Image.memory(
                      bytes,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => const Text(
                        'Lỗi tải ảnh',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContractUploadCard(Uint8List? bytes) {
    final hasImage = bytes != null;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: hasImage ? const Color(0xFF10B981) : const Color(0xFFE2E8F0),
          width: hasImage ? 1.5 : 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x080F172A),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: hasImage
                      ? const Color(0xFFECFDF5)
                      : PartnerColors.softBlue,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  hasImage
                      ? Icons.check_circle_rounded
                      : Icons.description_rounded,
                  color: hasImage
                      ? const Color(0xFF10B981)
                      : PartnerColors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '2. Hợp đồng đối tác TaskLy',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: PartnerColors.navy,
                      ),
                    ),
                    Text(
                      'Chụp trang có chữ ký xác nhận của bạn',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: hasImage
                      ? const Color(0xFFECFDF5)
                      : const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: hasImage
                        ? const Color(0xFFA7F3D0)
                        : const Color(0xFFFECACA),
                  ),
                ),
                child: Text(
                  hasImage ? 'ĐÃ CÓ ẢNH' : 'BẮT BUỘC',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: hasImage
                        ? const Color(0xFF059669)
                        : const Color(0xFFDC2626),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // PREVIEW OR PLACEHOLDER
          if (hasImage) ...[
            GestureDetector(
              onTap: () => _viewContractImage(bytes),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Stack(
                  children: [
                    Container(
                      width: double.infinity,
                      height: 220,
                      color: const Color(0xFFF1F5F9),
                      child: Image.memory(
                        bytes,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            const Center(child: Text('Lỗi tải ảnh')),
                      ),
                    ),
                    Positioned(
                      bottom: 8,
                      left: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.check_circle_rounded,
                              size: 14,
                              color: Color(0xFF34D399),
                            ),
                            SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Trang hợp đồng đã ký tên',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
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
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: busy ? null : () => pick(false),
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('Chọn ảnh hợp đồng đã ký', maxLines: 1),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      foregroundColor: PartnerColors.primary,
                      side: const BorderSide(
                        color: PartnerColors.softBlueBorder,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  onPressed: busy ? null : () => _removeImage(false),
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    size: 18,
                    color: Color(0xFFEF4444),
                  ),
                  label: const Text(
                    'Xoá ảnh',
                    style: TextStyle(color: Color(0xFFEF4444)),
                  ),
                ),
              ],
            ),
          ] else ...[
            GestureDetector(
              onTap: busy ? null : () => pick(false),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 24,
                  horizontal: 16,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xFFCBD5E1),
                    style: BorderStyle.solid,
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        color: Color(0xFFEFF6FF),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.note_add_rounded,
                        color: PartnerColors.primary,
                        size: 28,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Tải ảnh Hợp đồng đã ký tên',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: PartnerColors.navy,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Chụp rõ nét trang có chữ ký xác nhận của bạn • Tối đa 2 MB',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 14),
                    OutlinedButton(
                      onPressed: busy ? null : () => pick(false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: PartnerColors.primary,
                        side: const BorderSide(color: PartnerColors.primary),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('Chọn ảnh hợp đồng đã ký'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// CAM KẾT VÀ XÁC NHẬN ĐIỀU KHOẢN
  Widget _buildCommitmentCard() {
    return Container(
      decoration: BoxDecoration(
        color: hasAgreedPolicy
            ? const Color(0xFFF0FDF4)
            : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasAgreedPolicy
              ? const Color(0xFF86EFAC)
              : const Color(0xFFE2E8F0),
          width: 1.2,
        ),
      ),
      padding: const EdgeInsets.all(14),
      child: InkWell(
        onTap: () {
          setState(() => hasAgreedPolicy = !hasAgreedPolicy);
          HapticFeedback.selectionClick();
        },
        borderRadius: BorderRadius.circular(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: hasAgreedPolicy,
              activeColor: PartnerColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(5),
              ),
              onChanged: (val) {
                setState(() => hasAgreedPolicy = val ?? false);
                HapticFeedback.selectionClick();
              },
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Tôi cam kết ảnh chân dung được chụp trực tiếp tại Văn phòng đại diện TaskLy, tôi đang mặc đúng áo đồng phục TaskLy chính hãng và Hợp đồng đã được ký tên bởi chính tôi. Tôi chịu trách nhiệm hoàn toàn về tính trung thực của hồ sơ.',
                style: TextStyle(
                  fontSize: 12.5,
                  color: Color(0xFF334155),
                  height: 1.45,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
