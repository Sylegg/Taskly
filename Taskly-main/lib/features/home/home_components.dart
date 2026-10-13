export 'popular_services_card.dart';

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme.dart';
import '../../domain/models.dart';
import '../../shared/service_symbol.dart';
import '../../shared/category_symbol.dart';

abstract final class HomeColors {
  static const emerald = Color(0xFF0F9D7A);
  static const dark = Color(0xFF087A60);
  static const soft = Color(0xFFDDF5EE);
  static const mint = Color(0xFFB9EFE3);
  static const background = Color(0xFFF7FBF9);
  static const ink = Color(0xFF0F172A);
  static const muted = Color(0xFF667085);
  static const border = Color(0xFFDDE7E4);
}

class HomeSurface extends StatelessWidget {
  const HomeSurface({
    super.key,
    required this.child,
    this.color = Colors.white,
    this.padding = const EdgeInsets.all(20),
    this.border = false,
  });
  final Widget child;
  final Color color;
  final EdgeInsets padding;
  final bool border;
  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(24),
      border: border ? Border.all(color: HomeColors.border) : null,
      boxShadow: const [
        BoxShadow(
          color: Color(0x060F172A),
          blurRadius: 20,
          offset: Offset(0, 6),
        ),
      ],
    ),
    child: child,
  );
}

class SoftPress extends StatefulWidget {
  const SoftPress({
    super.key,
    required this.child,
    required this.onTap,
    this.label,
  });
  final Widget child;
  final VoidCallback? onTap;
  final String? label;
  @override
  State<SoftPress> createState() => _SoftPressState();
}

class _SoftPressState extends State<SoftPress> {
  bool pressed = false;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: widget.label,
    child: GestureDetector(
      onTap: widget.onTap,
      onTapDown: widget.onTap == null
          ? null
          : (_) => setState(() => pressed = true),
      onTapUp: (_) => setState(() => pressed = false),
      onTapCancel: () => setState(() => pressed = false),
      child: AnimatedScale(
        scale: pressed ? .98 : 1,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 130),
        child: widget.child,
      ),
    ),
  );
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.action, this.onTap});
  final String title;
  final String? action;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 28, bottom: 16),
    child: Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: HomeColors.ink,
              letterSpacing: -.5,
            ),
          ),
        ),
        if (action != null)
          TextButton(
            onPressed: onTap,
            style: TextButton.styleFrom(
              foregroundColor: HomeColors.dark,
              padding: const EdgeInsets.only(left: 8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  action!,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Icon(Icons.chevron_right, size: 16),
              ],
            ),
          ),
      ],
    ),
  );
}

/// Native vector artwork: no borrowed mascot or raster dependencies.
class TaskLyRobot extends StatelessWidget {
  const TaskLyRobot({super.key, this.size = 90});
  final double size;
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Trợ lý robot TaskLy',
    image: true,
    child: TweenAnimationBuilder<double>(
      tween: Tween(begin: 4, end: 0),
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 800),
      curve: Curves.easeOutSine,
      builder: (_, offset, child) =>
          Transform.translate(offset: Offset(0, offset), child: child),
      child: CustomPaint(
        size: Size(size, size * 1.1),
        painter: _RobotPainter(),
      ),
    ),
  );
}

class _RobotPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100, size.height / 110);
    final p = Paint();
    canvas.drawOval(
      const Rect.fromLTWH(20, 96, 60, 7),
      p..color = const Color(0x13087A60),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(29, 68, 43, 29),
        const Radius.circular(15),
      ),
      p..color = Colors.white,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(36, 77, 28, 12),
        const Radius.circular(6),
      ),
      p..color = HomeColors.soft,
    );
    canvas.drawCircle(const Offset(50, 82), 3, p..color = HomeColors.emerald);
    canvas.drawLine(
      const Offset(50, 25),
      const Offset(50, 14),
      p
        ..color = HomeColors.dark
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(const Offset(50, 12), 5, p..color = HomeColors.emerald);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(11, 37, 12, 20),
        const Radius.circular(6),
      ),
      p..color = HomeColors.emerald,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(77, 37, 12, 20),
        const Radius.circular(6),
      ),
      p,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(18, 25, 64, 47),
        const Radius.circular(19),
      ),
      p..color = Colors.white,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(26, 34, 48, 29),
        const Radius.circular(12),
      ),
      p..color = HomeColors.dark,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(36, 43, 5, 9),
        const Radius.circular(3),
      ),
      p..color = HomeColors.mint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(59, 43, 5, 9),
        const Radius.circular(3),
      ),
      p,
    );
    canvas.drawArc(
      const Rect.fromLTWH(45, 47, 11, 9),
      .2,
      2.7,
      false,
      p
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    p.style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(80, 14), 3, p..color = Colors.white);
    canvas.drawCircle(
      const Offset(10, 72),
      3,
      p..color = HomeColors.emerald.withValues(alpha: .25),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class AddressSelector extends StatelessWidget {
  const AddressSelector({super.key, required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(8),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.location_on_outlined,
            size: 16,
            color: Color(0xFF00A77C),
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF43516B),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 6),
          const Icon(
            Icons.keyboard_arrow_down,
            size: 16,
            color: Color(0xFF8FA3BF),
          ),
        ],
      ),
    ),
  );
}

class TaskLySearchBar extends StatelessWidget {
  const TaskLySearchBar({super.key, required this.onSearch});
  final ValueChanged<String> onSearch;
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(19),
      color: Colors.white,
      boxShadow: const [
        BoxShadow(
          color: Color(0x09087A60),
          blurRadius: 16,
          offset: Offset(0, 4),
        ),
      ],
    ),
    child: TextField(
      onSubmitted: onSearch,
      textInputAction: TextInputAction.search,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        hintText: 'Tìm dịch vụ bạn cần...',
        hintStyle: const TextStyle(color: HomeColors.muted, fontSize: 13),
        prefixIcon: const Icon(
          Icons.search_rounded,
          color: HomeColors.dark,
          size: 22,
        ),
        filled: false,
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(19),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(19),
          borderSide: BorderSide.none,
        ),
        suffixIcon: IconButton(
          tooltip: 'Tìm dịch vụ',
          onPressed: () => onSearch(''),
          icon: const Icon(
            Icons.tune_rounded,
            size: 19,
            color: HomeColors.muted,
          ),
        ),
      ),
    ),
  );
}

class TaskLyHomeHeader extends StatefulWidget {
  const TaskLyHomeHeader({
    super.key,
    required this.name,
    required this.address,
    required this.unread,
    required this.onNotifications,
    required this.onAddress,
    required this.onSearch,
    required this.onBook,
  });
  final String name, address;
  final bool unread;
  final VoidCallback onNotifications, onAddress, onBook;
  final ValueChanged<String> onSearch;
  @override
  State<TaskLyHomeHeader> createState() => _TaskLyHomeHeaderState();
}

class _TaskLyHomeHeaderState extends State<TaskLyHomeHeader> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(
                        text: 'Xin chào, ',
                        style: TextStyle(
                          color: Color(0xFF71829C),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      TextSpan(
                        text: widget.name,
                        style: const TextStyle(
                          color: Color(0xFF121B30),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const TextSpan(text: ' 👋'),
                    ],
                  ),
                  style: const TextStyle(fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                AddressSelector(label: widget.address, onTap: widget.onAddress),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Tìm kiếm',
            onPressed: () {
              setState(() => _expanded = !_expanded);
            },
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFFF4F7FA),
              minimumSize: const Size(38, 38),
              padding: const EdgeInsets.all(9),
            ),
            icon: const Icon(
              Icons.search_rounded,
              size: 21,
              color: Color(0xFF182238),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Thông báo',
            onPressed: widget.onNotifications,
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFFF4F7FA),
              minimumSize: const Size(38, 38),
              padding: const EdgeInsets.all(9),
            ),
            icon: Badge(
              isLabelVisible: widget.unread,
              smallSize: 8,
              backgroundColor: const Color(0xFF00B884),
              child: const Icon(
                Icons.notifications_none_rounded,
                size: 21,
                color: Color(0xFF182238),
              ),
            ),
          ),
        ],
      ),
      if (_expanded) ...[
        const SizedBox(height: 10),
        TextField(
          onSubmitted: widget.onSearch,
          textInputAction: TextInputAction.search,
          autofocus: true,
          style: const TextStyle(fontSize: 13, color: Color(0xFF43516B)),
          decoration: InputDecoration(
            hintText: 'Tìm dịch vụ (vd: dọn nhà, sửa vòi nước)...',
            hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF91A5BF)),
            filled: true,
            fillColor: const Color(0xFFF4F7FA),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 10,
            ),
            prefixIcon: const Icon(
              Icons.search_rounded,
              size: 20,
              color: Color(0xFF91A5BF),
            ),
            prefixIconConstraints: const BoxConstraints(minWidth: 38),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ] else
        SizedBox(
          height: 0,
          width: 0,
          child: Opacity(
            opacity: 0,
            child: TextField(
              onSubmitted: widget.onSearch,
              textInputAction: TextInputAction.search,
            ),
          ),
        ),
    ],
  );
}

const homeServiceIds = [
  'cleaning',
  'deep-cleaning',
  'assembly',
  'moving',
  'aircon',
  'shopping',
  'pets',
  'it-support',
];
const homeServiceLabels = [
  'Dọn nhà',
  'Tổng vệ sinh',
  'Sửa chữa',
  'Chuyển nhà',
  'Vệ sinh\nmáy lạnh',
  'Đi chợ hộ',
  'Chăm\nthú cưng',
  'IT Support',
];
const homeServiceIcons = [
  Icons.cleaning_services_outlined,
  Icons.auto_awesome_outlined,
  Icons.handyman_outlined,
  Icons.local_shipping_outlined,
  Icons.ac_unit_rounded,
  Icons.shopping_basket_outlined,
  Icons.pets_outlined,
  Icons.computer_rounded,
];
const homePastels = [
  Color(0xFFDDF5EE),
  Color(0xFFE7EEFC),
  Color(0xFFFFF2D5),
  Color(0xFFEDE9FB),
  Color(0xFFE5F4FA),
  Color(0xFFFFEBDD),
  Color(0xFFF1E8F7),
  Color(0xFFE2F1EB),
];

class Store3DIcon extends StatelessWidget {
  const Store3DIcon({super.key, this.size = 38});
  final double size;

  @override
  Widget build(BuildContext context) => Transform.rotate(
    angle: -0.06,
    child: Container(
      width: size * 0.95,
      height: size * 0.95,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F9D7A), Color(0xFF087A60)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(size * 0.22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x300F9D7A),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Center(
        child: Icon(
          Icons.storefront_rounded,
          color: Colors.white,
          size: size * 0.58,
        ),
      ),
    ),
  );
}

class News3DIcon extends StatelessWidget {
  const News3DIcon({super.key, this.size = 38});
  final double size;

  @override
  Widget build(BuildContext context) => Transform.rotate(
    angle: -0.05,
    child: Container(
      width: size * 1.05,
      height: size * 0.9,
      decoration: BoxDecoration(
        color: const Color(0xFFF7FBF9),
        borderRadius: BorderRadius.circular(size * 0.18),
        border: Border.all(color: const Color(0xFFBCEBDD), width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x350F9D7A),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      padding: EdgeInsets.all(size * 0.12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: size * 0.18,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F9D7A), Color(0xFF10B981)],
              ),
              borderRadius: BorderRadius.circular(size * 0.08),
            ),
          ),
          SizedBox(height: size * 0.08),
          Row(
            children: [
              Container(
                width: size * 0.28,
                height: size * 0.24,
                decoration: BoxDecoration(
                  color: const Color(0xFFDDF5EE),
                  borderRadius: BorderRadius.circular(size * 0.06),
                ),
                child: const Icon(
                  Icons.image_rounded,
                  size: 8,
                  color: Color(0xFF0F9D7A),
                ),
              ),
              SizedBox(width: size * 0.08),
              Expanded(
                child: Column(
                  children: [
                    Container(height: 2, color: const Color(0xFF087A60)),
                    const SizedBox(height: 3),
                    Container(height: 2, color: const Color(0xFF94A3B8)),
                    const SizedBox(height: 3),
                    Container(height: 2, color: const Color(0xFFCBD5E1)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class Utilities3DIcon extends StatelessWidget {
  const Utilities3DIcon({super.key, this.size = 38});
  final double size;

  @override
  Widget build(BuildContext context) {
    final b = size * 0.42;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 2,
            top: 2,
            child: Container(
              width: b,
              height: b,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0F9D7A), Color(0xFF10B981)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(size * 0.12),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x280F9D7A),
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            right: 2,
            top: 2,
            child: Container(
              width: b,
              height: b,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6EE7B7), Color(0xFFA7F3D0)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(size * 0.12),
              ),
              child: const Icon(Icons.add, size: 10, color: Colors.white),
            ),
          ),
          Positioned(
            left: 2,
            bottom: 2,
            child: Container(
              width: b,
              height: b,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF087A60), Color(0xFF0F9D7A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(size * 0.12),
              ),
            ),
          ),
          Positioned(
            right: 2,
            bottom: 2,
            child: Container(
              width: b,
              height: b,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF34D399), Color(0xFF6EE7B7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(size * 0.12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class Payment3DIcon extends StatelessWidget {
  const Payment3DIcon({super.key, this.size = 38});
  final double size;

  @override
  Widget build(BuildContext context) => Transform.rotate(
    angle: 0.08,
    child: Container(
      width: size * 1.05,
      height: size * 0.85,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F9D7A), Color(0xFF087A60)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(size * 0.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x350F9D7A),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Container(
          width: size * 0.44,
          height: size * 0.44,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.24),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.6),
              width: 1.2,
            ),
          ),
          child: const Center(
            child: Text(
              'đ',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w900,
                height: 1.1,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class Delivery3DIcon extends StatelessWidget {
  const Delivery3DIcon({super.key, this.size = 38});
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size * 0.95,
    height: size * 0.95,
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF0F9D7A), Color(0xFF087A60)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(size * 0.2),
      boxShadow: const [
        BoxShadow(
          color: Color(0x300F9D7A),
          blurRadius: 8,
          offset: Offset(0, 3),
        ),
      ],
    ),
    child: Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 3.5,
          height: size * 0.95,
          color: Colors.white.withValues(alpha: 0.6),
        ),
        Container(
          height: 3.5,
          width: size * 0.95,
          color: Colors.white.withValues(alpha: 0.6),
        ),
        Positioned(
          top: 4,
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.9),
              shape: BoxShape.circle,
            ),
          ),
        ),
      ],
    ),
  );
}

class Lifestyle3DIcon extends StatelessWidget {
  const Lifestyle3DIcon({super.key, this.size = 38});
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size * 0.95,
    height: size * 0.95,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(size * 0.2),
      border: Border.all(color: const Color(0xFFBCEBDD), width: 1.2),
      boxShadow: const [
        BoxShadow(
          color: Color(0x280F9D7A),
          blurRadius: 8,
          offset: Offset(0, 3),
        ),
      ],
    ),
    child: Column(
      children: [
        Container(
          height: size * 0.28,
          decoration: const BoxDecoration(
            color: Color(0xFF0F9D7A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(6)),
          ),
          child: const Center(
            child: Text(
              '12',
              style: TextStyle(
                color: Colors.white,
                fontSize: 8,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
        const Expanded(
          child: Center(
            child: Icon(
              Icons.health_and_safety_rounded,
              color: Color(0xFF0F9D7A),
              size: 15,
            ),
          ),
        ),
      ],
    ),
  );
}

class Cleaning3DIcon extends StatelessWidget {
  const Cleaning3DIcon({super.key, this.size = 38});
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size * 0.95,
    height: size * 0.95,
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF0F9D7A), Color(0xFF10B981)],
      ),
      borderRadius: BorderRadius.circular(size * 0.22),
    ),
    child: Center(
      child: Icon(
        Icons.cleaning_services_rounded,
        color: Colors.white,
        size: size * 0.52,
      ),
    ),
  );
}

class Repair3DIcon extends StatelessWidget {
  const Repair3DIcon({super.key, this.size = 38});
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size * 0.95,
    height: size * 0.95,
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF0F9D7A), Color(0xFF34D399)],
      ),
      borderRadius: BorderRadius.circular(size * 0.22),
    ),
    child: Center(
      child: Icon(
        Icons.handyman_rounded,
        color: Colors.white,
        size: size * 0.52,
      ),
    ),
  );
}

class Aircon3DIcon extends StatelessWidget {
  const Aircon3DIcon({super.key, this.size = 38});
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size * 0.95,
    height: size * 0.95,
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF0F9D7A), Color(0xFF6EE7B7)],
      ),
      borderRadius: BorderRadius.circular(size * 0.22),
    ),
    child: Center(
      child: Icon(
        Icons.ac_unit_rounded,
        color: Colors.white,
        size: size * 0.52,
      ),
    ),
  );
}

class MoveQuickIcon extends StatelessWidget {
  const MoveQuickIcon({super.key, this.size = 28});
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size * 0.86,
    child: CustomPaint(painter: _CarQuickPainter()),
  );
}

class _CarQuickPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = const Color(0xFF1E293B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final accentStroke = Paint()
      ..color = const Color(0xFF0F9D7A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;

    // Roof rack line
    canvas.drawLine(
      Offset(size.width * 0.28, size.height * 0.12),
      Offset(size.width * 0.72, size.height * 0.12),
      stroke,
    );

    // Car cabin (windshield)
    final cabin = Path()
      ..moveTo(size.width * 0.22, size.height * 0.44)
      ..lineTo(size.width * 0.32, size.height * 0.18)
      ..lineTo(size.width * 0.68, size.height * 0.18)
      ..lineTo(size.width * 0.78, size.height * 0.44);
    canvas.drawPath(cabin, stroke);

    // Car body
    final body = Path()
      ..moveTo(size.width * 0.12, size.height * 0.44)
      ..lineTo(size.width * 0.88, size.height * 0.44)
      ..quadraticBezierTo(
        size.width * 0.94,
        size.height * 0.44,
        size.width * 0.94,
        size.height * 0.58,
      )
      ..lineTo(size.width * 0.94, size.height * 0.82)
      ..quadraticBezierTo(
        size.width * 0.94,
        size.height * 0.88,
        size.width * 0.86,
        size.height * 0.88,
      )
      ..lineTo(size.width * 0.14, size.height * 0.88)
      ..quadraticBezierTo(
        size.width * 0.06,
        size.height * 0.88,
        size.width * 0.06,
        size.height * 0.82,
      )
      ..lineTo(size.width * 0.06, size.height * 0.58)
      ..quadraticBezierTo(
        size.width * 0.06,
        size.height * 0.44,
        size.width * 0.12,
        size.height * 0.44,
      )
      ..close();
    canvas.drawPath(body, stroke);

    // Headlights
    canvas.drawCircle(
      Offset(size.width * 0.24, size.height * 0.62),
      2.2,
      accentStroke,
    );
    canvas.drawCircle(
      Offset(size.width * 0.76, size.height * 0.62),
      2.2,
      accentStroke,
    );

    // Lower bumper line
    canvas.drawLine(
      Offset(size.width * 0.38, size.height * 0.74),
      Offset(size.width * 0.62, size.height * 0.74),
      stroke,
    );

    // Wheels at bottom
    canvas.drawLine(
      Offset(size.width * 0.16, size.height * 0.95),
      Offset(size.width * 0.26, size.height * 0.95),
      stroke,
    );
    canvas.drawLine(
      Offset(size.width * 0.74, size.height * 0.95),
      Offset(size.width * 0.84, size.height * 0.95),
      stroke,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class MedicineQuickIcon extends StatelessWidget {
  const MedicineQuickIcon({super.key});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 28,
    height: 24,
    child: CustomPaint(painter: _MedicineQuickPainter()),
  );
}

class _MedicineQuickPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // 3 speed lines on the left
    final speedPaint = Paint()
      ..color = const Color(0xFF0F9D7A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(size.width * 0.04, size.height * 0.36),
      Offset(size.width * 0.24, size.height * 0.36),
      speedPaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.08, size.height * 0.52),
      Offset(size.width * 0.28, size.height * 0.52),
      speedPaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.02, size.height * 0.68),
      Offset(size.width * 0.20, size.height * 0.68),
      speedPaint,
    );

    // Tilted capsule pill
    canvas.save();
    canvas.translate(size.width * 0.62, size.height * 0.50);
    canvas.rotate(-0.65); // ~ -37 deg

    const pillW = 20.0;
    const pillH = 10.5;
    const radius = pillH / 2;

    final pillRect = Rect.fromCenter(
      center: Offset.zero,
      width: pillW,
      height: pillH,
    );
    final pillRRect = RRect.fromRectAndRadius(
      pillRect,
      const Radius.circular(radius),
    );

    // Green half (left)
    canvas.save();
    canvas.clipRect(
      const Rect.fromLTWH(-pillW / 2, -pillH / 2, pillW / 2, pillH),
    );
    final fillGreen = Paint()..color = const Color(0xFF0F9D7A);
    canvas.drawRRect(pillRRect, fillGreen);
    canvas.restore();

    // White half (right)
    canvas.save();
    canvas.clipRect(const Rect.fromLTWH(0, -pillH / 2, pillW / 2, pillH));
    final fillWhite = Paint()..color = Colors.white;
    canvas.drawRRect(pillRRect, fillWhite);
    canvas.restore();

    // Border & seam
    final borderPaint = Paint()
      ..color = const Color(0xFF0F9D7A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    canvas.drawRRect(pillRRect, borderPaint);
    canvas.drawLine(
      const Offset(0, -pillH / 2),
      const Offset(0, pillH / 2),
      borderPaint,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class FlightQuickIcon extends StatelessWidget {
  final double size;
  const FlightQuickIcon({super.key, this.size = 28});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size * (24.0 / 28.0),
    child: CustomPaint(painter: _FlightQuickPainter()),
  );
}

class _FlightQuickPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = const Color(0xFF1E293B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final rect = Rect.fromLTWH(
      size.width * 0.08,
      size.height * 0.18,
      size.width * 0.84,
      size.height * 0.64,
    );
    final path = Path()
      ..moveTo(rect.left + 5, rect.top)
      ..lineTo(rect.right - 5, rect.top)
      ..quadraticBezierTo(rect.right, rect.top, rect.right, rect.top + 5)
      ..lineTo(rect.right, rect.center.dy - 3)
      ..arcToPoint(
        Offset(rect.right, rect.center.dy + 3),
        radius: const Radius.circular(3),
        clockwise: false,
      )
      ..lineTo(rect.right, rect.bottom - 5)
      ..quadraticBezierTo(rect.right, rect.bottom, rect.right - 5, rect.bottom)
      ..lineTo(rect.left + 5, rect.bottom)
      ..quadraticBezierTo(rect.left, rect.bottom, rect.left, rect.bottom - 5)
      ..lineTo(rect.left, rect.center.dy + 3)
      ..arcToPoint(
        Offset(rect.left, rect.center.dy - 3),
        radius: const Radius.circular(3),
        clockwise: false,
      )
      ..lineTo(rect.left, rect.top + 5)
      ..quadraticBezierTo(rect.left, rect.top, rect.left + 5, rect.top)
      ..close();

    canvas.drawPath(path, stroke);

    // Airplane silhouette inside
    final planeStroke = Paint()
      ..color = const Color(0xFF0F9D7A)
      ..style = PaintingStyle.fill;

    canvas.save();
    canvas.translate(size.width * 0.48, size.height * 0.50);
    canvas.rotate(-0.55);
    final plane = Path()
      ..moveTo(0, -6)
      ..lineTo(1.8, -2)
      ..lineTo(6, 1)
      ..lineTo(5.5, 2.5)
      ..lineTo(1.8, 1.2)
      ..lineTo(1.5, 5)
      ..lineTo(3.5, 6.2)
      ..lineTo(3.2, 7.2)
      ..lineTo(0, 6.2)
      ..lineTo(-3.2, 7.2)
      ..lineTo(-3.5, 6.2)
      ..lineTo(-1.5, 5)
      ..lineTo(-1.8, 1.2)
      ..lineTo(-5.5, 2.5)
      ..lineTo(-6, 1)
      ..lineTo(-1.8, -2)
      ..close();
    canvas.drawPath(plane, planeStroke);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class ClinicQuickIcon extends StatelessWidget {
  const ClinicQuickIcon({super.key});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 28,
    height: 24,
    child: CustomPaint(painter: _ClinicQuickPainter()),
  );
}

class _ClinicQuickPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = const Color(0xFF1E293B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final calRect = Rect.fromLTWH(
      size.width * 0.14,
      size.height * 0.16,
      size.width * 0.72,
      size.height * 0.72,
    );
    final calRRect = RRect.fromRectAndRadius(calRect, const Radius.circular(5));
    canvas.drawRRect(calRRect, stroke);

    // Top spiral rings
    canvas.drawLine(
      Offset(size.width * 0.32, size.height * 0.08),
      Offset(size.width * 0.32, size.height * 0.22),
      stroke,
    );
    canvas.drawLine(
      Offset(size.width * 0.68, size.height * 0.08),
      Offset(size.width * 0.68, size.height * 0.22),
      stroke,
    );

    // Top separator
    canvas.drawLine(
      Offset(calRect.left, size.height * 0.38),
      Offset(calRect.right, size.height * 0.38),
      stroke,
    );

    // Dots on calendar
    final dotPaint = Paint()..color = const Color(0xFF64748B);
    canvas.drawCircle(
      Offset(size.width * 0.32, size.height * 0.52),
      1.2,
      dotPaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.50, size.height * 0.52),
      1.2,
      dotPaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.68, size.height * 0.52),
      1.2,
      dotPaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.32, size.height * 0.68),
      1.2,
      dotPaint,
    );

    // Medical cross badge at bottom right
    final crossPaint = Paint()
      ..color = const Color(0xFF0F9D7A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(size.width * 0.62, size.height * 0.68),
      Offset(size.width * 0.76, size.height * 0.68),
      crossPaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.69, size.height * 0.61),
      Offset(size.width * 0.69, size.height * 0.75),
      crossPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _QuickActionItem extends StatelessWidget {
  const _QuickActionItem({
    required this.id,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String id;
  final String label;
  final Widget icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Expanded(
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: 34, child: Center(child: icon)),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E2530),
                height: 1.25,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class SmartWatchesGraphic extends StatelessWidget {
  const SmartWatchesGraphic({super.key, this.size = 38});
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size * 1.6,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 0,
            child: _SingleWatch(
              size: size * 0.92,
              bodyColor: const Color(0xFF1E293B),
              bezelColor: const Color(0xFF0F172A),
              screenColor: const Color(0xFF020617),
              strapColor: const Color(0xFF334155),
              accentColor: const Color(0xFF38BDF8),
            ),
          ),
          Positioned(
            right: 0,
            child: _SingleWatch(
              size: size * 0.92,
              bodyColor: const Color(0xFF9D174D),
              bezelColor: const Color(0xFF831843),
              screenColor: const Color(0xFF500724),
              strapColor: const Color(0xFFBE185D),
              accentColor: const Color(0xFFF472B6),
            ),
          ),
        ],
      ),
    );
  }
}

class _SingleWatch extends StatelessWidget {
  const _SingleWatch({
    required this.size,
    required this.bodyColor,
    required this.bezelColor,
    required this.screenColor,
    required this.strapColor,
    required this.accentColor,
  });

  final double size;
  final Color bodyColor;
  final Color bezelColor;
  final Color screenColor;
  final Color strapColor;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final w = size * 0.72;
    final h = size * 0.88;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: w * 0.58,
          height: 3,
          decoration: BoxDecoration(
            color: strapColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
          ),
        ),
        Container(
          width: w,
          height: h,
          decoration: BoxDecoration(
            color: bodyColor,
            borderRadius: BorderRadius.circular(w * 0.32),
            border: Border.all(color: bezelColor, width: 1.5),
            boxShadow: const [
              BoxShadow(
                color: Color(0x30000000),
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.all(2.5),
          child: Container(
            decoration: BoxDecoration(
              color: screenColor,
              borderRadius: BorderRadius.circular(w * 0.22),
            ),
            child: Center(
              child: Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  color: accentColor,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ),
        Container(
          width: w * 0.58,
          height: 3,
          decoration: BoxDecoration(
            color: strapColor,
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(2),
            ),
          ),
        ),
      ],
    );
  }
}

class SecurityCameraGraphic extends StatelessWidget {
  const SecurityCameraGraphic({super.key, this.size = 38});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(size * 0.28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x18000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: size * 0.58,
              height: size * 0.58,
              decoration: const BoxDecoration(
                color: Color(0xFF1E293B),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Container(
                  width: size * 0.26,
                  height: size * 0.26,
                  decoration: const BoxDecoration(
                    color: Color(0xFF0F172A),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
            Positioned(
              top: 5,
              right: 6,
              child: Container(
                width: 4,
                height: 4,
                decoration: const BoxDecoration(
                  color: Color(0xFF10B981),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: Color(0x8010B981), blurRadius: 3),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class Laundry3DIcon extends StatelessWidget {
  const Laundry3DIcon({super.key, this.size = 38});
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size * 0.95,
    height: size * 0.95,
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF0F9D7A), Color(0xFF14B8A6)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(size * 0.22),
      boxShadow: const [
        BoxShadow(
          color: Color(0x300F9D7A),
          blurRadius: 6,
          offset: Offset(0, 2),
        ),
      ],
    ),
    child: Center(
      child: Icon(
        Icons.local_laundry_service_rounded,
        color: Colors.white,
        size: size * 0.52,
      ),
    ),
  );
}

class Furniture3DIcon extends StatelessWidget {
  const Furniture3DIcon({super.key, this.size = 38});
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size * 0.95,
    height: size * 0.95,
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF0F9D7A), Color(0xFF059669)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(size * 0.22),
      boxShadow: const [
        BoxShadow(
          color: Color(0x300F9D7A),
          blurRadius: 6,
          offset: Offset(0, 2),
        ),
      ],
    ),
    child: Center(
      child: Icon(Icons.chair_rounded, color: Colors.white, size: size * 0.52),
    ),
  );
}

class Tech3DIcon extends StatelessWidget {
  const Tech3DIcon({super.key, this.size = 38});
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size * 0.95,
    height: size * 0.95,
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF0F9D7A), Color(0xFF0D9488)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(size * 0.22),
      boxShadow: const [
        BoxShadow(
          color: Color(0x300F9D7A),
          blurRadius: 6,
          offset: Offset(0, 2),
        ),
      ],
    ),
    child: Center(
      child: Icon(
        Icons.laptop_chromebook_rounded,
        color: Colors.white,
        size: size * 0.52,
      ),
    ),
  );
}

class Sofa3DIcon extends StatelessWidget {
  const Sofa3DIcon({super.key, this.size = 38});
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size * 0.95,
    height: size * 0.95,
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF0F9D7A), Color(0xFF10B981)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(size * 0.22),
      boxShadow: const [
        BoxShadow(
          color: Color(0x300F9D7A),
          blurRadius: 6,
          offset: Offset(0, 2),
        ),
      ],
    ),
    child: Center(
      child: Icon(
        Icons.weekend_rounded,
        color: Colors.white,
        size: size * 0.52,
      ),
    ),
  );
}

class Mattress3DIcon extends StatelessWidget {
  const Mattress3DIcon({super.key, this.size = 38});
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size * 0.95,
    height: size * 0.95,
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF0F9D7A), Color(0xFF14B8A6)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(size * 0.22),
      boxShadow: const [
        BoxShadow(
          color: Color(0x300F9D7A),
          blurRadius: 6,
          offset: Offset(0, 2),
        ),
      ],
    ),
    child: Center(
      child: Icon(Icons.bed_rounded, color: Colors.white, size: size * 0.52),
    ),
  );
}

class DeepClean3DIcon extends StatelessWidget {
  const DeepClean3DIcon({super.key, this.size = 38});
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size * 0.95,
    height: size * 0.95,
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF0F9D7A), Color(0xFF10B981)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(size * 0.22),
      boxShadow: const [
        BoxShadow(
          color: Color(0x300F9D7A),
          blurRadius: 6,
          offset: Offset(0, 2),
        ),
      ],
    ),
    child: Center(
      child: Icon(
        Icons.auto_awesome_rounded,
        color: Colors.white,
        size: size * 0.52,
      ),
    ),
  );
}

class ArcDomePainter extends CustomPainter {
  const ArcDomePainter({this.drawBackground = true});
  final bool drawBackground;

  @override
  void paint(Canvas canvas, Size size) {
    if (drawBackground) {
      // Taskly emerald green gradient background with rounded top corners
      final bgRRect = RRect.fromRectAndCorners(
        Rect.fromLTWH(0, 0, size.width, size.height),
        topLeft: const Radius.circular(24),
        topRight: const Radius.circular(24),
      );

      final greenPaint = Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0F9D7A), Color(0xFF087A60)],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

      canvas.drawRRect(bgRRect, greenPaint);

      // Subtle radial highlight on top center
      final glowPaint = Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, -0.6),
          radius: 0.85,
          colors: [
            Colors.white.withValues(alpha: 0.22),
            Colors.white.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
      canvas.drawRRect(bgRRect, glowPaint);
    }

    // White curved dome at bottom, raised higher so it doesn't obscure the category folders
    final domePath = Path();
    domePath.moveTo(0, size.height);
    domePath.lineTo(0, size.height * 0.44);
    domePath.quadraticBezierTo(
      size.width * 0.5,
      size.height * 0.15,
      size.width,
      size.height * 0.44,
    );
    domePath.lineTo(size.width, size.height);
    domePath.close();

    // Soft drop shadow behind dome
    canvas.drawShadow(domePath, const Color(0x35087A60), 16, false);

    // Fill white dome completely to the bottom edge
    final whitePaint = Paint()..color = Colors.white;
    canvas.drawPath(domePath, whitePaint);
  }

  @override
  bool shouldRepaint(covariant ArcDomePainter oldDelegate) =>
      oldDelegate.drawBackground != drawBackground;
}

class CategoryBadge extends StatelessWidget {
  const CategoryBadge({super.key, required this.child, this.selected = false});
  final Widget child;
  final bool selected;
  @override
  Widget build(BuildContext context) => Container(
    width: selected ? 64 : 42,
    height: selected ? 64 : 42,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFFDEEA), Color(0xFFFFF2F6)],
      ),
      border: Border.all(
        color: const Color(0xFFF7BBD1),
        width: selected ? 2 : 1,
      ),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFFE76D9A).withValues(alpha: selected ? .23 : .1),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Center(child: child),
  );
}

class ArcServiceCarouselItem {
  const ArcServiceCarouselItem({
    required this.id,
    required this.label,
    required this.icon,
    this.isCenter = false,
  });

  final String id;
  final String label;
  final Widget icon;
  final bool isCenter;
}

class ArcServiceCarousel extends StatefulWidget {
  const ArcServiceCarousel({
    super.key,
    required this.onService,
    this.onAllServices,
    this.services,
    this.categories,
    this.isEmbedded = false,
  });

  final ValueChanged<String> onService;
  final VoidCallback? onAllServices;
  final List<Service>? services;
  final List<ServiceCategory>? categories;
  final bool isEmbedded;

  @override
  State<ArcServiceCarousel> createState() => _ArcServiceCarouselState();
}

class _ArcServiceCarouselState extends State<ArcServiceCarousel> {
  static const int _kLoopFactor = 100;
  late PageController _pageController;
  int _initialPage = 0;

  static const List<ArcServiceCarouselItem> _defaultItems = [
    ArcServiceCarouselItem(
      id: 'cleaning',
      label: 'Dọn nhà\ntheo giờ',
      icon: Cleaning3DIcon(),
    ),
    ArcServiceCarouselItem(
      id: 'deep-cleaning',
      label: 'Tổng vệ sinh\nnhà',
      icon: DeepClean3DIcon(),
    ),
    ArcServiceCarouselItem(
      id: 'sofa',
      label: 'Vệ sinh\nsofa',
      icon: Sofa3DIcon(),
      isCenter: true,
    ),
    ArcServiceCarouselItem(
      id: 'mattress',
      label: 'Vệ sinh nệm\ntại nhà',
      icon: Mattress3DIcon(),
    ),
    ArcServiceCarouselItem(
      id: 'aircon',
      label: 'Vệ sinh\nmáy lạnh',
      icon: Aircon3DIcon(),
    ),
    ArcServiceCarouselItem(
      id: 'moving',
      label: 'Chuyển trọ\nbê đồ',
      icon: MoveQuickIcon(),
    ),
    ArcServiceCarouselItem(
      id: 'assembly',
      label: 'Lắp ráp\nnội thất',
      icon: Furniture3DIcon(),
    ),
    ArcServiceCarouselItem(
      id: 'repair',
      label: 'Sửa chữa\ngia dụng',
      icon: Repair3DIcon(),
    ),
    ArcServiceCarouselItem(
      id: 'shopping',
      label: 'Đi chợ\nsiêu thị',
      icon: Store3DIcon(),
    ),
    ArcServiceCarouselItem(
      id: 'laundry',
      label: 'Giặt sấy\nủi đồ',
      icon: Laundry3DIcon(),
    ),
  ];

  static Widget _iconForService(Service s, {double size = 30}) =>
      ServiceSymbol.forService(s, size: size);
  static String _labelForService(Service s) => s.name.trim();

  List<ArcServiceCarouselItem> get _items {
    if (widget.categories != null) {
      return widget.categories!
          .map(
            (category) => ArcServiceCarouselItem(
              id: category.id,
              label: category.name,
              icon: CategorySymbol(category: category),
            ),
          )
          .toList();
    }
    if (widget.services != null) {
      final seen = <String>{};
      final list = <ArcServiceCarouselItem>[];
      for (final s in widget.services!) {
        final label = _labelForService(s);
        if (seen.add(s.id)) {
          list.add(
            ArcServiceCarouselItem(
              id: s.id,
              label: label,
              icon: _iconForService(s),
            ),
          );
        }
      }
      return list;
    }
    return _defaultItems;
  }

  @override
  void initState() {
    super.initState();
    _initController();
  }

  void _initController() {
    final itemsCount = _items.length;
    final initialOffset = itemsCount > 2 ? 2 : 0;
    _initialPage = itemsCount > 0
        ? (_kLoopFactor ~/ 2) * itemsCount + initialOffset
        : 0;
    // Five services fit across the arc, with the selected item emphasized.
    _pageController = PageController(
      viewportFraction: 0.20,
      initialPage: _initialPage,
    );
  }

  @override
  void didUpdateWidget(covariant ArcServiceCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.services?.length != widget.services?.length ||
        oldWidget.categories?.length != widget.categories?.length) {
      final itemsCount = _items.length;
      final initialOffset = itemsCount > 2 ? 2 : 0;
      _initialPage = itemsCount > 0
          ? (_kLoopFactor ~/ 2) * itemsCount + initialOffset
          : 0;
      if (_pageController.hasClients) {
        _pageController.jumpToPage(_initialPage);
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    final totalCount = items.isEmpty ? 0 : items.length * _kLoopFactor;

    if (items.isEmpty) {
      return SizedBox(
        height: 160,
        child: Center(
          child: Text(
            widget.categories != null
                ? 'Chưa có danh mục đang hoạt động.'
                : 'Chưa có dịch vụ đang hoạt động.',
          ),
        ),
      );
    }

    return SizedBox(
      height: 210,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: ArcDomePainter(drawBackground: !widget.isEmbedded),
            ),
          ),
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _pageController,
              builder: (context, _) {
                double page = _initialPage.toDouble();
                if (_pageController.hasClients &&
                    _pageController.position.haveDimensions) {
                  page = _pageController.page ?? _initialPage.toDouble();
                }
                return PageView.builder(
                  controller: _pageController,
                  physics: const BouncingScrollPhysics(),
                  itemCount: totalCount,
                  itemBuilder: (context, globalIndex) {
                    final i = globalIndex % items.length;
                    final item = items[i];
                    final diff = (globalIndex - page).abs();
                    final factor = (1.0 - (diff * 0.50).clamp(0.0, 1.0));
                    final scale = 0.85 + 0.30 * factor;
                    final opacity = (1.0 - diff * 0.16).clamp(0.68, 1.0);
                    // Parabolic trajectory: center item is at apex, edges slope downward onto dome
                    final yOffset =
                        -20.0 + (diff * diff * 7.5).clamp(0.0, 32.0);
                    final isNearCenter = diff < 0.45;

                    return Center(
                      child: Opacity(
                        opacity: opacity,
                        child: Transform.translate(
                          offset: Offset(0, yOffset),
                          child: Transform.scale(
                            scale: scale,
                            child: GestureDetector(
                              onTap: () {
                                if (diff > 0.4) {
                                  _pageController.animateToPage(
                                    globalIndex,
                                    duration: const Duration(milliseconds: 320),
                                    curve: Curves.easeOutCubic,
                                  );
                                }
                                widget.onService(item.id);
                              },
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (widget.categories != null)
                                    CategoryBadge(
                                      key: ValueKey('home-category-${item.id}'),
                                      selected: isNearCenter,
                                      child: item.icon,
                                    )
                                  else if (isNearCenter)
                                    Container(
                                      width: 72,
                                      height: 72,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.white,
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(
                                              0xFF0F9D7A,
                                            ).withValues(alpha: 0.28 * factor),
                                            blurRadius: 16,
                                            spreadRadius: 1,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                        border: Border.all(
                                          color: Colors.white,
                                          width: 2.5,
                                        ),
                                      ),
                                      child: Center(
                                        child: ServiceIcon(
                                          key: ValueKey('home-service-$i'),
                                          index: i,
                                          size: 34,
                                          customIcon: item.icon,
                                        ),
                                      ),
                                    )
                                  else
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF0FDF8),
                                        borderRadius: BorderRadius.circular(15),
                                        border: Border.all(
                                          color: const Color(0xFFD1FAE5),
                                          width: 1.2,
                                        ),
                                        boxShadow: const [
                                          BoxShadow(
                                            color: Color(0x10087A60),
                                            blurRadius: 6,
                                            offset: Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Center(
                                        child: ServiceIcon(
                                          key: ValueKey('home-service-$i'),
                                          index: i,
                                          size: 30,
                                          customIcon: item.icon,
                                        ),
                                      ),
                                    ),
                                  const SizedBox(height: 7),
                                  SizedBox(
                                    width: isNearCenter ? 78 : 70,
                                    child: Text(
                                      item.label,
                                      textAlign: TextAlign.center,
                                      maxLines: 3,
                                      softWrap: true,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: isNearCenter ? 10.5 : 9,
                                        height: 1.25,
                                        fontWeight: isNearCenter
                                            ? FontWeight.w800
                                            : FontWeight.w600,
                                        color: isNearCenter
                                            ? const Color(0xFF0F172A)
                                            : const Color(0xFF334155),
                                        letterSpacing: -0.2,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          if (widget.categories != null)
            Positioned(
              bottom: 6,
              left: 0,
              right: 0,
              child: Center(
                child: OutlinedButton.icon(
                  key: const ValueKey('home-all-categories'),
                  onPressed: widget.onAllServices,
                  icon: const Icon(Icons.folder_open_rounded, size: 16),
                  label: const Text('Danh mục'),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFF2F6),
                    foregroundColor: const Color(0xFFCA497A),
                    side: const BorderSide(color: Color(0xFFF7BBD1)),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    minimumSize: const Size(108, 36),
                    textStyle: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                    shape: const StadiumBorder(),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class QuickServicesCard extends StatelessWidget {
  const QuickServicesCard({super.key, required this.onAction});
  final ValueChanged<String> onAction;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(16, 6, 16, 12),
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFF7FDFB), Colors.white],
      ),
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: const Color(0xFFE2F4EE), width: 1.2),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0A000000),
          blurRadius: 18,
          offset: Offset(0, 4),
        ),
      ],
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _QuickActionItem(
          id: 'moving',
          label: 'Di chuyển',
          icon: const MoveQuickIcon(),
          onTap: () => onAction('moving'),
        ),
        _QuickActionItem(
          id: 'pharmacy',
          label: 'Đặt thuốc 24/7',
          icon: const MedicineQuickIcon(),
          onTap: () => onAction('pharmacy'),
        ),
        _QuickActionItem(
          id: 'flight',
          label: 'Vé máy bay',
          icon: const FlightQuickIcon(),
          onTap: () => onAction('flight'),
        ),
        _QuickActionItem(
          id: 'clinic',
          label: 'Đặt lịch khám',
          icon: const ClinicQuickIcon(),
          onTap: () => onAction('clinic'),
        ),
      ],
    ),
  );
}

class HomePromoSection extends StatefulWidget {
  const HomePromoSection({super.key, required this.banners});
  final List<HomeBanner> banners;
  @override
  State<HomePromoSection> createState() => _HomePromoSectionState();
}

class _HomePromoSectionState extends State<HomePromoSection> {
  final PageController _pages = PageController(viewportFraction: .92);
  int _selected = 0;
  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.banners.isEmpty) return const SizedBox.shrink();
    final current = _selected.clamp(0, widget.banners.length - 1);
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 18),
      child: Column(
        children: [
          LayoutBuilder(
            builder: (context, constraints) => SizedBox(
              height: constraints.maxWidth * .92 / 3,
              child: PageView.builder(
                controller: _pages,
                itemCount: widget.banners.length,
                onPageChanged: (index) => setState(() => _selected = index),
                itemBuilder: (context, index) {
                  final banner = widget.banners[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: ColoredBox(
                        color: HomeColors.soft,
                        child: Image.network(
                          banner.imageUrl,
                          key: ValueKey('home-banner-${banner.id}'),
                          semanticLabel: banner.title,
                          fit: BoxFit.contain,
                          loadingBuilder: (context, child, progress) =>
                              progress == null
                              ? child
                              : const Center(
                                  child: SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                ),
                          errorBuilder: (context, error, stack) => const Center(
                            child: Icon(
                              Icons.broken_image_outlined,
                              color: HomeColors.muted,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          if (widget.banners.length > 1) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < widget.banners.length; i++)
                  Semantics(
                    label: 'Banner ${i + 1} trên ${widget.banners.length}',
                    selected: i == current,
                    button: true,
                    child: GestureDetector(
                      onTap: () => _pages.animateToPage(
                        i,
                        duration: MediaQuery.disableAnimationsOf(context)
                            ? Duration.zero
                            : const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 8,
                        ),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: i == current ? 18 : 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: i == current
                                ? HomeColors.emerald
                                : const Color(0xFFD8E8E2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class ServiceIcon extends StatelessWidget {
  const ServiceIcon({
    super.key,
    required this.index,
    this.size = 54,
    this.customIcon,
    this.customColor,
    this.serviceKey,
    this.iconUrl = '',
  });

  final int index;
  final double size;
  final Widget? customIcon;
  final Color? customColor;
  final String? serviceKey;
  final String iconUrl;

  @override
  Widget build(BuildContext context) {
    if (customIcon != null) {
      return SizedBox(
        width: size,
        height: size,
        child: Center(child: customIcon),
      );
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: customColor ?? homePastels[index % 8],
        borderRadius: BorderRadius.circular(18),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            right: 7,
            top: 7,
            child: Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .8),
                shape: BoxShape.circle,
              ),
            ),
          ),
          ServiceSymbol(
            iconKey: serviceKey ?? '',
            iconUrl: iconUrl,
            fallbackIcon: serviceKey == null
                ? homeServiceIcons[index % 8]
                : null,
            size: size * .76,
            iconSize: size * .5,
            color: HomeColors.dark,
          ),
        ],
      ),
    );
  }
}

class ServiceGrid extends StatelessWidget {
  const ServiceGrid({super.key, required this.onService, this.services});
  final ValueChanged<String> onService;
  final List<Service>? services;
  @override
  Widget build(BuildContext context) => GridView.builder(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    padding: EdgeInsets.zero,
    itemCount: services?.length ?? 8,
    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 4,
      crossAxisSpacing: 7,
      mainAxisSpacing: 12,
      mainAxisExtent: 102 * MediaQuery.textScalerOf(context).scale(1),
    ),
    itemBuilder: (_, i) => SoftPress(
      onTap: () => onService(services?[i].id ?? homeServiceIds[i]),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ServiceIcon(
            key: ValueKey('home-service-$i'),
            index: i % 8,
            serviceKey: services?[i].displayIconKey,
            iconUrl: services?[i].iconUrl ?? '',
          ),
          const SizedBox(height: 9),
          Text(
            services?[i].name ?? homeServiceLabels[i],
            maxLines: 2,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              height: 1.35,
              fontWeight: FontWeight.w600,
              color: HomeColors.ink,
            ),
          ),
        ],
      ),
    ),
  );
}

class ActiveTaskCard extends StatelessWidget {
  const ActiveTaskCard({
    super.key,
    required this.task,
    required this.service,
    this.partner,
    required this.onDetails,
    required this.onTrack,
    required this.onMessage,
    this.eta,
  });
  final CustomerTask task;
  final Service service;
  final Tasker? partner;
  final VoidCallback onDetails, onTrack, onMessage;
  final String? eta;
  @override
  Widget build(BuildContext context) {
    final step = switch (task.status) {
      TaskStatus.onTheWay || TaskStatus.arrived => 1,
      TaskStatus.inProgress => 2,
      TaskStatus.completed || TaskStatus.paid => 3,
      TaskStatus.posted || TaskStatus.matching => -1,
      _ => 0,
    };
    final status = switch (task.status) {
      TaskStatus.onTheWay => 'Partner đang trên đường',
      TaskStatus.accepted => 'Partner đã nhận việc',
      TaskStatus.arrived => 'Partner đã đến nơi',
      TaskStatus.inProgress => 'Partner đang làm việc',
      TaskStatus.completed => 'Chờ bạn nghiệm thu',
      TaskStatus.matching || TaskStatus.posted => 'Đang tìm Partner phù hợp',
      _ => taskStatusStyles[task.status]!.label,
    };
    return HomeSurface(
      border: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ServiceIcon(
                index: 0,
                size: 44,
                serviceKey: service.displayIconKey,
                iconUrl: service.iconUrl,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      service.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      status,
                      style: const TextStyle(
                        fontSize: 12,
                        color: HomeColors.dark,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onDetails,
                tooltip: 'Xem chi tiết công việc',
                icon: const Icon(Icons.chevron_right, color: HomeColors.muted),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: List.generate(
              4,
              (i) => Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 2,
                            color: i == 0
                                ? Colors.transparent
                                : i <= step
                                ? HomeColors.emerald
                                : HomeColors.border,
                          ),
                        ),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: i <= step
                                ? HomeColors.emerald
                                : Colors.white,
                            border: Border.all(
                              color: i <= step
                                  ? HomeColors.emerald
                                  : HomeColors.border,
                              width: 2,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Container(
                            height: 2,
                            color: i == 3
                                ? Colors.transparent
                                : i < step
                                ? HomeColors.emerald
                                : HomeColors.border,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      ['Đã nhận', 'Đang đến', 'Làm việc', 'Hoàn thành'][i],
                      style: TextStyle(
                        fontSize: 10,
                        color: i == step ? HomeColors.dark : HomeColors.muted,
                        fontWeight: i == step
                            ? FontWeight.w700
                            : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 19),
          if (partner != null) ...[
            Row(
              children: [
                _PartnerAvatar(partner!),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        partner!.name,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '★ ${partner!.rating} · ${partner!.jobs} công việc',
                        style: const TextStyle(
                          fontSize: 11,
                          color: HomeColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                if (eta != null)
                  Flexible(
                    child: Text(
                      eta!,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 11,
                        color: HomeColors.dark,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onMessage,
                    icon: const Icon(Icons.chat_bubble_outline, size: 16),
                    label: const Text('Nhắn tin'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 42),
                      padding: const EdgeInsets.symmetric(horizontal: 8),

                      side: const BorderSide(color: HomeColors.border),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: onTrack,
                    style: FilledButton.styleFrom(
                      backgroundColor: HomeColors.dark,
                      minimumSize: const Size(0, 42),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    child: Text(
                      task.status == TaskStatus.completed
                          ? 'Nghiệm thu'
                          : 'Theo dõi',
                    ),
                  ),
                ),
              ],
            ),
          ] else
            TextButton(onPressed: onDetails, child: const Text('Xem chi tiết')),
        ],
      ),
    );
  }
}

class _PartnerAvatar extends StatelessWidget {
  const _PartnerAvatar(this.partner);
  final Tasker partner;
  @override
  Widget build(BuildContext context) => CircleAvatar(
    radius: 21,
    backgroundColor: HomeColors.soft,
    backgroundImage: partner.avatar.isNotEmpty
        ? AssetImage(partner.avatar)
        : null,
    child: partner.avatar.isEmpty
        ? Text(
            partner.name.isEmpty ? 'P' : partner.name.characters.first,
            style: const TextStyle(color: HomeColors.dark),
          )
        : null,
  );
}

class UpcomingTaskCard extends StatelessWidget {
  const UpcomingTaskCard({
    super.key,
    required this.task,
    required this.service,
    required this.onTap,
  });
  final CustomerTask task;
  final Service service;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => SoftPress(
    onTap: onTap,
    child: HomeSurface(
      border: true,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: HomeColors.soft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.calendar_month_outlined,
              color: HomeColors.dark,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  service.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '${dateLabel(task.draft.scheduledAt)} · ${timeLabel(task.draft.scheduledAt)}',
                  style: const TextStyle(fontSize: 12, color: HomeColors.muted),
                ),
                Text(
                  task.taskerId == null
                      ? 'Đang tìm Partner'
                      : 'Partner đã nhận lịch',
                  style: const TextStyle(fontSize: 11, color: HomeColors.dark),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: HomeColors.muted),
        ],
      ),
    ),
  );
}

class TaskLyAssistantCard extends StatelessWidget {
  const TaskLyAssistantCard({
    super.key,
    required this.name,
    required this.service,
    required this.onBook,
    required this.onDismiss,
  });
  final String name, service;
  final VoidCallback onBook, onDismiss;
  @override
  Widget build(BuildContext context) => HomeSurface(
    color: HomeColors.soft,
    padding: const EdgeInsets.all(18),
    child: Row(
      children: [
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.auto_awesome, size: 14, color: HomeColors.dark),
                  SizedBox(width: 6),
                  Text(
                    'TASKLY ASSISTANT',
                    style: TextStyle(
                      fontSize: 10,
                      letterSpacing: 1,
                      fontWeight: FontWeight.w800,
                      color: HomeColors.dark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 9),
              Text(
                'Chào $name! Đặt lại dịch vụ\n$service lần trước nhé?',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  height: 1.5,
                ),
              ),
              Row(
                children: [
                  TextButton(
                    onPressed: onBook,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      foregroundColor: HomeColors.dark,
                    ),
                    child: const Text(
                      'Đặt lại',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: onDismiss,
                    child: const Text(
                      'Để sau',
                      style: TextStyle(fontSize: 12, color: HomeColors.muted),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const TaskLyRobot(size: 65),
      ],
    ),
  );
}

class RecommendedServiceCard extends StatelessWidget {
  const RecommendedServiceCard({
    super.key,
    required this.service,
    required this.onTap,
    this.rating,
    this.image = 'assets/images/room_after.png',
  });
  final Service service;
  final VoidCallback onTap;
  final double? rating;
  final String? image;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 178,
    child: SoftPress(
      onTap: onTap,
      child: HomeSurface(
        padding: EdgeInsets.zero,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              child: image == null || service.iconUrl.isNotEmpty
                  ? Container(
                      height: 110,
                      width: 178,
                      color: HomeColors.soft,
                      child: Center(
                        child: ServiceIcon(
                          index: homeServiceIds.indexOf(service.id).clamp(0, 7),
                          size: 76,
                          serviceKey: service.displayIconKey,
                          iconUrl: service.iconUrl,
                        ),
                      ),
                    )
                  : Image.asset(
                      image!,
                      height: 110,
                      width: 178,
                      fit: BoxFit.cover,
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    service.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Từ ${money(service.hourlyRate)}${service.priceUnit}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: HomeColors.dark,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          rating == null ? 'Xem dịch vụ' : '★ $rating',
                          style: const TextStyle(
                            fontSize: 11,
                            color: HomeColors.muted,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        size: 17,
                        color: HomeColors.dark,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class BookAgainCard extends StatelessWidget {
  const BookAgainCard({
    super.key,
    required this.task,
    required this.service,
    this.partner,
    required this.onBook,
  });
  final CustomerTask task;
  final Service service;
  final Tasker? partner;
  final VoidCallback onBook;
  @override
  Widget build(BuildContext context) => HomeSurface(
    padding: const EdgeInsets.all(16),
    border: true,
    child: Row(
      children: [
        if (partner != null)
          _PartnerAvatar(partner!)
        else
          ServiceIcon(
            index: 0,
            size: 44,
            serviceKey: service.displayIconKey,
            iconUrl: service.iconUrl,
          ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                service.name,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (partner != null)
                Text(
                  '${partner!.name} · ★ ${partner!.rating}',
                  style: const TextStyle(fontSize: 11, color: HomeColors.muted),
                ),
              const SizedBox(height: 4),
              Text(
                'Lần gần nhất: ${dateLabel(task.completedAt ?? task.draft.scheduledAt).substring(0, 5)}',
                style: const TextStyle(fontSize: 10, color: HomeColors.muted),
              ),
            ],
          ),
        ),
        TextButton(
          onPressed: onBook,
          child: const Text(
            'Đặt lại',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: HomeColors.dark,
            ),
          ),
        ),
      ],
    ),
  );
}

class FavoritePartnerCard extends StatelessWidget {
  const FavoritePartnerCard({
    super.key,
    required this.partner,
    required this.skill,
    required this.onBook,
  });
  final Tasker partner;
  final String skill;
  final VoidCallback onBook;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 170,
    child: HomeSurface(
      border: true,
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _PartnerAvatar(partner),
              const Spacer(),
              const Icon(
                Icons.favorite_rounded,
                size: 17,
                color: HomeColors.emerald,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            partner.name,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            '★ ${partner.rating} · ${partner.jobs} việc',
            style: const TextStyle(fontSize: 11, color: HomeColors.muted),
          ),
          const SizedBox(height: 5),
          Text(
            skill,
            style: const TextStyle(fontSize: 11, color: HomeColors.dark),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onBook,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 36),
                padding: EdgeInsets.zero,
                side: const BorderSide(color: HomeColors.border),
              ),
              child: const Text('Đặt lịch', style: TextStyle(fontSize: 12)),
            ),
          ),
        ],
      ),
    ),
  );
}

class RewardsProgressCard extends StatelessWidget {
  const RewardsProgressCard({
    super.key,
    required this.points,
    required this.target,
    required this.onTap,
  });
  final int points, target;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => HomeSurface(
    border: true,
    padding: const EdgeInsets.all(18),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF2D5),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.card_giftcard_outlined,
                color: HomeColors.dark,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bạn có $points TaskPoints',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    points >= target
                        ? 'Bạn đã đạt mốc nhận Voucher 30K'
                        : 'Còn ${target - points} điểm để nhận Voucher 30K',
                    style: const TextStyle(
                      fontSize: 11,
                      color: HomeColors.muted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 15),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: target > 0 ? (points / target).clamp(0, 1) : 0,
            minHeight: 6,
            color: HomeColors.emerald,
            backgroundColor: HomeColors.soft,
          ),
        ),
        TextButton(
          onPressed: onTap,
          child: const Text(
            'Xem phần thưởng',
            style: TextStyle(fontSize: 12, color: HomeColors.dark),
          ),
        ),
      ],
    ),
  );
}

class TaskLyBottomNav extends StatelessWidget {
  const TaskLyBottomNav({
    super.key,
    required this.selected,
    required this.onSelected,
    this.isVisible = true,
    this.isDark = false,
  });

  final int selected;
  final ValueChanged<int> onSelected;
  final bool isVisible;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final activeColor =
        isDark ? const Color(0xFF00E5A3) : const Color(0xFF0F9D7A);
    final inactiveColor =
        isDark ? Colors.white.withValues(alpha: 0.72) : const Color(0xFF64748B);

    final isServiceActive = selected == 0;
    final isActivityActive = selected == 1;
    final isCommunityActive = selected == 3;
    final isAccountActive = selected == 4;

    const navIndices = [0, 1, 3, 4];
    final activeIndex = navIndices.indexOf(selected);

    return SafeArea(
      top: false,
      bottom: true,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeInOutCubic,
        offset: isVisible ? Offset.zero : const Offset(0, 1.4),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: isVisible ? 1.0 : 0.0,
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF0F172A).withValues(alpha: 0.85)
                  : Colors.white.withValues(alpha: 0.94),
              borderRadius: BorderRadius.circular(38),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.16)
                    : Colors.white.withValues(alpha: 0.95),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? Colors.black.withValues(alpha: 0.45)
                      : const Color(0x12000000),
                  blurRadius: 28,
                  offset: const Offset(0, 8),
                  spreadRadius: 0,
                ),
                BoxShadow(
                  color: isDark
                      ? const Color(0x3300E5A3)
                      : const Color(0x1A087A60),
                  blurRadius: 18,
                  offset: const Offset(0, 4),
                  spreadRadius: 0,
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: SizedBox(
                height: 66,
                child: Stack(
                  children: [
                    // Fluid sliding capsule highlight
                    Positioned.fill(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final tabWidth = constraints.maxWidth / 4;
                            return Stack(
                              children: [
                                if (activeIndex != -1)
                                  AnimatedPositioned(
                                    duration: const Duration(milliseconds: 320),
                                    curve: Curves.easeOutCubic,
                                    left: activeIndex * tabWidth + 3,
                                    top: 2,
                                    width: tabWidth - 6,
                                    height: constraints.maxHeight - 4,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: isDark
                                              ? [
                                                  const Color(0xFF00E5A3).withValues(alpha: 0.22),
                                                  const Color(0xFF00E5A3).withValues(alpha: 0.08),
                                                ]
                                              : [
                                                  const Color(0xFFECFDF5),
                                                  const Color(0xFFD1FAE5),
                                                ],
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                        ),
                                        borderRadius: BorderRadius.circular(22),
                                        border: Border.all(
                                          color: isDark
                                              ? const Color(0xFF00E5A3).withValues(alpha: 0.35)
                                              : const Color(0xFFA7F3D0),
                                          width: 1.0,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: isDark
                                                ? const Color(0xFF00E5A3).withValues(alpha: 0.18)
                                                : const Color(0x14059669),
                                            blurRadius: 10,
                                            offset: const Offset(0, 3),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),

                    // Interactive items row
                    Positioned.fill(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                        child: Row(
                          children: [
                            // Chức năng 1: Dịch vụ (key: customer-nav-0)
                            _buildNavItem(
                              key: const ValueKey('customer-nav-0'),
                              label: 'Dịch vụ',
                              icon: isServiceActive
                                  ? Icons.grid_view_rounded
                                  : Icons.grid_view_outlined,
                              isActive: isServiceActive,
                              activeColor: activeColor,
                              inactiveColor: inactiveColor,
                              onTap: () {
                                HapticFeedback.selectionClick();
                                onSelected(0);
                              },
                            ),

                            // Chức năng 2: Hoạt động (key: customer-nav-1)
                            _buildNavItem(
                              key: const ValueKey('customer-nav-1'),
                              label: 'Hoạt động',
                              icon: isActivityActive
                                  ? Icons.receipt_long_rounded
                                  : Icons.receipt_long_outlined,
                              isActive: isActivityActive,
                              activeColor: activeColor,
                              inactiveColor: inactiveColor,
                              onTap: () {
                                HapticFeedback.selectionClick();
                                onSelected(1);
                              },
                            ),

                            // Chức năng 3: Cộng đồng (key: customer-nav-3)
                            _buildNavItem(
                              key: const ValueKey('customer-nav-3'),
                              label: 'Cộng đồng',
                              icon: isCommunityActive
                                  ? Icons.groups_rounded
                                  : Icons.groups_outlined,
                              isActive: isCommunityActive,
                              activeColor: activeColor,
                              inactiveColor: inactiveColor,
                              onTap: () {
                                HapticFeedback.selectionClick();
                                onSelected(3);
                              },
                            ),

                            // Chức năng 4: Tài khoản (key: customer-nav-4)
                            _buildNavItem(
                              key: const ValueKey('customer-nav-4'),
                              label: 'Tài khoản',
                              icon: isAccountActive
                                  ? Icons.person_rounded
                                  : Icons.person_outline_rounded,
                              isActive: isAccountActive,
                              activeColor: activeColor,
                              inactiveColor: inactiveColor,
                              onTap: () {
                                HapticFeedback.selectionClick();
                                onSelected(4);
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required Key key,
    required String label,
    required IconData icon,
    required bool isActive,
    required Color activeColor,
    required Color inactiveColor,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Semantics(
        button: true,
        selected: isActive,
        child: InkWell(
          key: key,
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          splashColor: activeColor.withValues(alpha: 0.12),
          highlightColor: Colors.transparent,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedScale(
                    scale: isActive ? 1.15 : 1.0,
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOutBack,
                    child: Icon(
                      icon,
                      size: 22,
                      color: isActive ? activeColor : inactiveColor,
                    ),
                  ),
                  const SizedBox(height: 3),
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 200),
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                      color: isActive ? activeColor : inactiveColor,
                      letterSpacing: -0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    child: Text(label),
                  ),
                  const SizedBox(height: 2),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 240),
                    curve: Curves.easeOutCubic,
                    width: 0,
                    height: 0,
                    decoration: BoxDecoration(
                      color: activeColor,
                      shape: BoxShape.circle,
                      boxShadow: isActive
                          ? [
                              BoxShadow(
                                color: activeColor.withValues(alpha: 0.6),
                                blurRadius: 4,
                                spreadRadius: 0.5,
                              ),
                            ]
                          : [],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class HomeSkeleton extends StatelessWidget {
  const HomeSkeleton({super.key});
  Widget block(double height, {double? width}) => Container(
    height: height,
    width: width,
    decoration: BoxDecoration(
      color: const Color(0xFFE6EEEA),
      borderRadius: BorderRadius.circular(16),
    ),
  );
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Đang tải trang chủ',
    child: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        block(300),
        const SizedBox(height: 28),
        block(20, width: 150),
        const SizedBox(height: 20),
        GridView.count(
          crossAxisCount: 4,
          childAspectRatio: .8,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 14,
          crossAxisSpacing: 18,
          children: List.generate(
            8,
            (_) => Column(
              children: [
                block(54, width: 54),
                const SizedBox(height: 8),
                block(10),
              ],
            ),
          ),
        ),
        const SizedBox(height: 28),
        block(180),
        const SizedBox(height: 28),
        Row(
          children: [
            Expanded(child: block(190)),
            const SizedBox(width: 14),
            Expanded(child: block(190)),
          ],
        ),
      ],
    ),
  );
}
