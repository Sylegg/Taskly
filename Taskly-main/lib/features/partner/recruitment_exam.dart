import 'dart:async';

import 'package:flutter/material.dart';

import '../../auth/api.dart';
import 'partner_ui_kit.dart';

class RecruitmentExam extends StatefulWidget {
  const RecruitmentExam({super.key, required this.session});
  final Session session;

  @override
  State<RecruitmentExam> createState() => _RecruitmentExamState();
}

class _RecruitmentExamState extends State<RecruitmentExam> {
  Map<String, dynamic>? config, attempt;
  Map<String, int> answers = {};
  int index = 0;
  bool busy = false;
  String? error;
  Timer? timer;
  DateTime? nextAutomaticSubmit;

  @override
  void initState() {
    super.initState();
    load();
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});
      if (attempt?['status'] == 'IN_PROGRESS' &&
          seconds <= 0 &&
          !busy &&
          (nextAutomaticSubmit == null ||
              DateTime.now().isAfter(nextAutomaticSubmit!))) {
        nextAutomaticSubmit = DateTime.now().add(const Duration(seconds: 30));
        submit(confirm: false);
      }
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  int get seconds => attempt == null
      ? 0
      : DateTime.parse(attempt!['expiresAt'])
            .difference(DateTime.now())
            .inSeconds
            .clamp(0, 7200);

  Future<void> load() async {
    setState(() => busy = true);
    try {
      final c = await widget.session.request('/partner/exam');
      final previous =
          await widget.session.request('/partner/exam/results') as List;
      if (!mounted) return;
      setState(() {
        config = Map<String, dynamic>.from(c);
        if (previous.isNotEmpty) {
          attempt = Map<String, dynamic>.from(previous.first);
          answers = Map<String, int>.from(attempt!['answers'] ?? {});
        }
      });
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> start() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final a = await widget.session.request(
        '/partner/exam/attempts',
        method: 'POST',
      );
      if (mounted) {
        setState(() {
          attempt = Map<String, dynamic>.from(a);
          answers = Map<String, int>.from(a['answers'] ?? {});
          index = 0;
        });
      }
      final c = await widget.session.request('/partner/exam');
      if (mounted) setState(() => config = Map<String, dynamic>.from(c));
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> choose(String id, int answer) async {
    setState(() {
      answers[id] = answer;
      busy = true;
      error = null;
    });
    try {
      final a = await widget.session.request(
        '/partner/exam/attempts/${attempt!['id']}/answers',
        method: 'PUT',
        body: {'answers': answers},
      );
      if (mounted) setState(() => attempt = Map<String, dynamic>.from(a));
    } catch (e) {
      if (mounted) setState(() => error = 'Chưa lưu được đáp án: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> submit({bool confirm = true}) async {
    if (confirm) {
      final questions = (attempt?['questions'] ?? []) as List;
      final total = questions.length;
      final answered = answers.length;
      final unanswered = total - answered;

      final yes = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              Icon(
                Icons.assignment_turned_in_rounded,
                color: PartnerColors.primary,
              ),
              SizedBox(width: 8),
              Text(
                'Nộp bài thi?',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Đã trả lời $answered/$total câu. Kết quả sẽ được máy chủ chấm.',
                style: const TextStyle(fontSize: 14, height: 1.4),
              ),
              if (unanswered > 0) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: Color(0xFFD97706),
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Còn $unanswered câu chưa chọn đáp án',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFFB45309),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Kiểm tra lại'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: PartnerColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Nộp bài'),
            ),
          ],
        ),
      );
      if (yes != true) return;
    }
    if (!mounted) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final a = await widget.session.request(
        '/partner/exam/attempts/${attempt!['id']}/submit',
        method: 'POST',
        body: {'answers': answers},
      );
      if (mounted) setState(() => attempt = Map<String, dynamic>.from(a));
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final questions = (attempt?['questions'] ?? []) as List;
    final running = attempt?['status'] == 'IN_PROGRESS';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFD),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        title: Text(
          running ? 'Đang làm bài thi' : 'Bài thi đầu vào',
          style: const TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Color(0xFF0F172A),
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (running)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: seconds < 120
                        ? const Color(0xFFFEE2E2)
                        : const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: seconds < 120
                          ? const Color(0xFFFCA5A5)
                          : PartnerColors.softBlueBorder,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.timer_outlined,
                        size: 14,
                        color: seconds < 120
                            ? const Color(0xFFDC2626)
                            : PartnerColors.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: seconds < 120
                              ? const Color(0xFFDC2626)
                              : PartnerColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (busy)
              const LinearProgressIndicator(
                minHeight: 3,
                color: PartnerColors.primary,
                backgroundColor: Color(0xFFDBEAFE),
              ),
            if (error != null)
              Container(
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFCA5A5)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Color(0xFFDC2626),
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        error!,
                        style: const TextStyle(
                          color: Color(0xFFB91C1C),
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: running && questions.isNotEmpty
                  ? _buildExamTakingView(questions)
                  : _buildExamIntroView(),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateTimeHM(dynamic value) {
    final date = DateTime.parse(value.toString()).toLocal();
    String pad(int n) => n.toString().padLeft(2, '0');
    return '${pad(date.hour)}:${pad(date.minute)} ${pad(date.day)}/${pad(date.month)}/${date.year}';
  }

  Widget _buildExamIntroView() {
    final status = attempt?['status'];
    final isPassed = status == 'PASSED';
    final isFailed = status == 'FAILED' || status == 'EXPIRED';
    final remainingAttempts =
        config?['remaining_attempts'] ?? config?['attempts_per_day'] ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
            children: [
              // Hero Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: isPassed
                      ? const LinearGradient(
                          colors: [Color(0xFF059669), Color(0xFF10B981)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : PartnerColors.luxuryBlueGradient,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x181E40AF),
                      blurRadius: 16,
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
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            isPassed
                                ? Icons.emoji_events_rounded
                                : Icons.assignment_turned_in_rounded,
                            color: Colors.white,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Sát hạch nghiệp vụ TaskLy',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Kiểm tra tiêu chuẩn đầu vào đối tác',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFFDBEAFE),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      '20 câu • 4 lựa chọn mỗi câu',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (config != null)
                      Text(
                        'Thời gian: ${config!['exam_minutes']} phút\nĐiểm đạt: ${config!['pass_mark']}/20\nCòn ${config!['remaining_attempts'] ?? config!['attempts_per_day']} lượt hôm nay (UTC)',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFFF1F5F9),
                          height: 1.45,
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Review topics if provided
              if ((config?['review_topics'] as List?)?.isNotEmpty == true)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.menu_book_rounded,
                        color: Color(0xFF2563EB),
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Nội dung cần ôn: ${(config!['review_topics'] as List).join(', ')}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF334155),
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              if (config?['remaining_attempts'] == 0 &&
                  config?['retry_available_at'] != null)
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Text(
                    'Có thể thi lại từ: ${_formatDateTimeHM(config!['retry_available_at'])}',
                    style: const TextStyle(
                      color: Color(0xFFB45309),
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),

              const SizedBox(height: 16),

              // Previous Attempt Result Card
              if (attempt != null)
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: isPassed
                        ? const Color(0xFFECFDF5)
                        : isFailed
                        ? const Color(0xFFFFF1F2)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isPassed
                          ? const Color(0xFFA7F3D0)
                          : isFailed
                          ? const Color(0xFFFECDD3)
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            isPassed
                                ? Icons.check_circle_rounded
                                : isFailed
                                ? Icons.cancel_rounded
                                : Icons.info_outline_rounded,
                            color: isPassed
                                ? const Color(0xFF10B981)
                                : isFailed
                                ? const Color(0xFFE11D48)
                                : PartnerColors.primary,
                            size: 22,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isPassed
                                ? 'KẾT QUẢ: ĐẠT YÊU CẦU'
                                : isFailed
                                ? 'KẾT QUẢ: CHƯA ĐẠT'
                                : 'KẾT QUẢ BÀI THI',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: isPassed
                                  ? const Color(0xFF065F46)
                                  : isFailed
                                  ? const Color(0xFF9F1239)
                                  : const Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Kết quả: ${attempt!['status']} • ${attempt!['score'] ?? 0}/20',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: isPassed
                              ? const Color(0xFF047857)
                              : isFailed
                              ? const Color(0xFFBE123C)
                              : const Color(0xFF334155),
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 16),

              // Exam Instructions Card
              _buildExamInstructionsCard(),
            ],
          ),
        ),

        // Pinned Bottom Action Bar (Nút luôn full-width và nằm ở đáy màn hình)
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, -3),
              ),
            ],
            border: const Border(
              top: BorderSide(color: Color(0xFFE2E8F0), width: 1),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: SafeArea(
            top: false,
            child: attempt?['status'] == 'PASSED'
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () => Navigator.pop(context, true),
                          icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                          label: const Text(
                            'Tiếp tục đào tạo',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                      if (remainingAttempts > 0) ...[
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: TextButton.icon(
                            onPressed: busy ? null : start,
                            icon: const Icon(Icons.refresh, size: 16),
                            label: const Text(
                              'Thi lại để cải thiện điểm',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  )
                : SizedBox(
                    width: double.infinity,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: (busy || remainingAttempts == 0)
                            ? null
                            : PartnerColors.luxuryBlueGradient,
                        color: (busy || remainingAttempts == 0)
                            ? const Color(0xFFCBD5E1)
                            : null,
                        boxShadow: (busy || remainingAttempts == 0)
                            ? null
                            : const [
                                BoxShadow(
                                  color: Color(0x331E40AF),
                                  blurRadius: 10,
                                  offset: Offset(0, 4),
                                ),
                              ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: (busy || remainingAttempts == 0)
                              ? null
                              : start,
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (busy)
                                  const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                else
                                  const Icon(
                                    Icons.play_arrow_rounded,
                                    color: Colors.white,
                                    size: 22,
                                  ),
                                const SizedBox(width: 8),
                                const Flexible(
                                  child: Text(
                                    'Bắt đầu / thi lại',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                      letterSpacing: 0.2,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildExamInstructionsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x04000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.lightbulb_outline_rounded,
                color: Color(0xFFF59E0B),
                size: 20,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Quy định & Hướng dẫn thi',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInstructionItem(
            '1',
            'Đề thi gồm 20 câu trắc nghiệm ngẫu nhiên từ ngân hàng câu hỏi chuẩn.',
          ),
          const SizedBox(height: 8),
          _buildInstructionItem(
            '2',
            'Mỗi câu hỏi có 4 lựa chọn và duy nhất 01 đáp án chính xác.',
          ),
          const SizedBox(height: 8),
          _buildInstructionItem(
            '3',
            'Đồng hồ đếm ngược tự động; hệ thống tự nộp bài khi hết giờ.',
          ),
          const SizedBox(height: 8),
          _buildInstructionItem(
            '4',
            'Bạn có thể nhảy nhanh giữa các câu hỏi hoặc quay lại sửa đáp án trước khi nộp.',
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionItem(String number, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: const BoxDecoration(
            color: Color(0xFFEFF6FF),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: PartnerColors.primary,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 12.5,
              color: Color(0xFF475569),
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildExamTakingView(List questions) {
    final currentQ = questions[index];
    final questionId = currentQ['id'].toString();
    final questionOptions = (currentQ['options'] as List?) ?? [];
    final selectedAnswer = answers[questionId];

    return Column(
      children: [
        // Question number indicator carousel
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Câu ${index + 1} / ${questions.length}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${answers.length}/${questions.length} đã làm',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: PartnerColors.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 38,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: questions.length,
                  separatorBuilder: (context, i) => const SizedBox(width: 6),
                  itemBuilder: (context, i) {
                    final qid = questions[i]['id'].toString();
                    final isAnswered = answers.containsKey(qid);
                    final isCurrent = index == i;

                    return GestureDetector(
                      onTap: busy ? null : () => setState(() => index = i),
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: isCurrent
                              ? PartnerColors.primary
                              : isAnswered
                              ? const Color(0xFFEFF6FF)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isCurrent
                                ? PartnerColors.primary
                                : isAnswered
                                ? PartnerColors.softBlueBorder
                                : const Color(0xFFCBD5E1),
                            width: isCurrent ? 2 : 1,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            '${i + 1}${isAnswered && !isCurrent ? ' ✓' : ''}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: isCurrent
                                  ? Colors.white
                                  : isAnswered
                                  ? PartnerColors.primaryDark
                                  : const Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),

        const Divider(height: 1, color: Color(0xFFE2E8F0)),

        // Question & Options scroll view
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Exact string expected if any: "Câu ${index + 1}: ${questions[index]['text']}"
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x04000000),
                      blurRadius: 8,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'CÂU HỎI ${index + 1}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: PartnerColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Câu ${index + 1}: ${currentQ['text']}',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Options
              ...List.generate(questionOptions.length, (i) {
                final isSelected = selectedAnswer == i;
                final optionLetter = String.fromCharCode(65 + i);

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFFEFF6FF) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected
                          ? PartnerColors.primary
                          : const Color(0xFFE2E8F0),
                      width: isSelected ? 1.8 : 1,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x04000000),
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: busy ? null : () => choose(questionId, i),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? PartnerColors.primary
                                    : const Color(0xFFF1F5F9),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  optionLetter,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: isSelected
                                        ? Colors.white
                                        : const Color(0xFF475569),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                questionOptions[i].toString(),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: const Color(0xFF0F172A),
                                  height: 1.3,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              isSelected
                                  ? Icons.radio_button_checked_rounded
                                  : Icons.radio_button_off_rounded,
                              color: isSelected
                                  ? PartnerColors.primary
                                  : const Color(0xFF94A3B8),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),

        // Bottom Actions Bar
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: busy || index == 0
                      ? null
                      : () => setState(() => index--),
                  icon: const Icon(Icons.arrow_back_rounded, size: 16),
                  label: const Text('Trước'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: busy || index == questions.length - 1
                      ? null
                      : () => setState(() => index++),
                  icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                  label: const Text('Tiếp'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: busy ? null : submit,
                  icon: const Icon(Icons.check_circle_rounded, size: 18),
                  label: const Text(
                    'Nộp bài',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: PartnerColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
