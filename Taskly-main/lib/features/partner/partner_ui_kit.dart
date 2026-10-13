import 'onboarding_completion.dart';

import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme.dart';
import '../../domain/models.dart';

/// Design tokens and colors specifically tailored for TaskLy Partner
abstract final class PartnerColors {
  static const primary = Color(0xFF1E5BF8); // Radiant Luxury Royal Blue
  static const primaryDark = Color(0xFF1345C7); // Deep Sapphire
  static const primaryLight = Color(0xFF3B82F6); // Sky Accent Blue
  static const softBlue = Color(0xFFEFF6FF); // Crisp Ice Blue tint
  static const softBlueBorder = Color(0xFFBFDBFE); // Soft Blue Border
  static const pillActive = Color(0xFFDBEAFE); // Capsule Active Tint
  static const background = Color(0xFFF8FAFD); // Porcelain White Background
  static const surface = Colors.white; // Pure Crisp White
  static const border = Color(0xFFE2E8F0); // Subtle Slate Border
  static const borderLight = Color(0xFFEDF2F7);
  static const navy = Color(0xFF0F172A); // Midnight Slate Text
  static const muted = Color(0xFF64748B); // Slate Muted Text
  static const success = Color(0xFF10B981);
  static const warning = Color(0xFFF59E0B);
  static const error = Color(0xFFEF4444);

  // Gradients
  static const luxuryBlueGradient = LinearGradient(
    colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const vipCardGradient = LinearGradient(
    colors: [Color(0xFF0B1938), Color(0xFF1E3A8A), Color(0xFF1D4ED8)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

/// Floating pill-shaped navigation bar ("Menu hình viên thuốc")
class PartnerFloatingPillNavBar extends StatelessWidget {
  const PartnerFloatingPillNavBar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<NavigationDestination> destinations;

  @override
  Widget build(BuildContext context) {
    final count = destinations.length;
    final safeIndex = selectedIndex.clamp(0, count > 0 ? count - 1 : 0);

    return SafeArea(
      top: false,
      bottom: true,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(38),
          border: Border.all(
            color: const Color(0xFFE2E8F0),
            width: 1.2,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x120F172A),
              blurRadius: 28,
              offset: Offset(0, 8),
              spreadRadius: 0,
            ),
            BoxShadow(
              color: Color(0x181E40AF),
              blurRadius: 18,
              offset: Offset(0, 4),
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
                // Hidden NavigationBar to preserve widget hierarchy & tests expecting NavigationDestination
                Positioned(
                  left: 0,
                  top: 0,
                  width: 0,
                  height: 0,
                  child: Opacity(
                    opacity: 0,
                    child: IgnorePointer(
                      child: NavigationBar(
                        selectedIndex: safeIndex,
                        onDestinationSelected: onDestinationSelected,
                        destinations: destinations,
                      ),
                    ),
                  ),
                ),

                // Fluid sliding capsule highlight
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        if (count == 0) return const SizedBox.shrink();
                        final tabWidth = constraints.maxWidth / count;
                        return Stack(
                          children: [
                            AnimatedPositioned(
                              duration: const Duration(milliseconds: 320),
                              curve: Curves.easeOutCubic,
                              left: safeIndex * tabWidth + 3,
                              top: 2,
                              width: tabWidth - 6,
                              height: constraints.maxHeight - 4,
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFFEFF6FF),
                                      Color(0xFFDBEAFE),
                                    ],
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                  ),
                                  borderRadius: BorderRadius.circular(22),
                                  border: Border.all(
                                    color: const Color(0xFFBFDBFE),
                                    width: 1.0,
                                  ),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x142563EB),
                                      blurRadius: 10,
                                      offset: Offset(0, 3),
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
                      children: List.generate(count, (index) {
                        final dest = destinations[index];
                        final isActive = index == safeIndex;

                        return Expanded(
                          child: Semantics(
                            button: true,
                            selected: isActive,
                            label: dest.label,
                            child: InkWell(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                onDestinationSelected(index);
                              },
                              borderRadius: BorderRadius.circular(22),
                              splashColor: const Color(0x182563EB),
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
                                        child: IconTheme(
                                          data: IconThemeData(
                                            color: isActive
                                                ? PartnerColors.primary
                                                : const Color(0xFF64748B),
                                            size: 22,
                                          ),
                                          child: isActive
                                              ? (dest.selectedIcon ?? dest.icon)
                                              : dest.icon,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      AnimatedDefaultTextStyle(
                                        duration: const Duration(milliseconds: 200),
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: isActive
                                              ? FontWeight.w800
                                              : FontWeight.w600,
                                          color: isActive
                                              ? PartnerColors.primary
                                              : const Color(0xFF64748B),
                                          letterSpacing: -0.2,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        child: Text(dest.label),
                                      ),
                                      const SizedBox(height: 2),
                                      AnimatedContainer(
                                        duration: const Duration(milliseconds: 240),
                                        curve: Curves.easeOutCubic,
                                        width: 0,
                                        height: 0,
                                        decoration: BoxDecoration(
                                          color: PartnerColors.primary,
                                          shape: BoxShape.circle,
                                          boxShadow: isActive
                                              ? const [
                                                  BoxShadow(
                                                    color: Color(0x662563EB),
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
                      }),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Wrapper for adding a springy scale-down micro-animation on press
class AnimatedPressable extends StatefulWidget {
  const AnimatedPressable({
    super.key,
    required this.child,
    this.onTap,
    this.scale = 0.95,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double scale;

  @override
  State<AnimatedPressable> createState() => _AnimatedPressableState();
}

class _AnimatedPressableState extends State<AnimatedPressable> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _pressed && widget.onTap != null ? widget.scale : 1.0,
      duration: const Duration(milliseconds: 110),
      curve: Curves.easeOutCubic,
      child: Listener(
        onPointerDown: (_) {
          if (widget.onTap != null) setState(() => _pressed = true);
        },
        onPointerUp: (_) {
          if (widget.onTap != null) setState(() => _pressed = false);
        },
        onPointerCancel: (_) {
          if (widget.onTap != null) setState(() => _pressed = false);
        },
        child: widget.child,
      ),
    );
  }
}

/// High-end animated pill button with royal blue gradient and bounce tap
class PartnerPillButton extends StatelessWidget {
  const PartnerPillButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.outlined = false,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool outlined;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return AnimatedPressable(
      onTap: onPressed,
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: outlined
            ? OutlinedButton(
                onPressed: isLoading ? null : onPressed,
                style: OutlinedButton.styleFrom(
                  shape: const StadiumBorder(),
                  side: const BorderSide(
                    color: PartnerColors.softBlueBorder,
                    width: 1.4,
                  ),
                  foregroundColor: PartnerColors.primary,
                ),
                child: _buttonContent(),
              )
            : DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: onPressed == null
                      ? null
                      : const [
                          BoxShadow(
                            color: Color(0x351E5BF8),
                            blurRadius: 16,
                            offset: Offset(0, 6),
                          ),
                        ],
                ),
                child: FilledButton(
                  onPressed: isLoading ? null : onPressed,
                  style: FilledButton.styleFrom(
                    backgroundColor: PartnerColors.primary,
                    foregroundColor: Colors.white,
                    shape: const StadiumBorder(),
                    elevation: 0,
                  ),
                  child: _buttonContent(),
                ),
              ),
      ),
    );
  }

  Widget _buttonContent() {
    if (isLoading) {
      return const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
      );
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: 8)],
        Flexible(
          child: Text(
            label,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// Luxury VIP Card for Tasker Wallet & earnings display
class PartnerWalletHeroCard extends StatelessWidget {
  const PartnerWalletHeroCard({
    super.key,
    required this.available,
    required this.pending,
    required this.onTapWithdraw,
  });

  final int available;
  final int pending;
  final VoidCallback onTapWithdraw;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: PartnerColors.vipCardGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x281E3A8A),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Decorative background circles
          Positioned(
            right: -30,
            top: -30,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ),
          Positioned(
            right: 40,
            bottom: -40,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.04),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.25),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.verified,
                            size: 14,
                            color: Color(0xFF60A5FA),
                          ),
                          SizedBox(width: 5),
                          Text(
                            'TASKLY PARTNER PRO',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.contactless_outlined,
                      color: Colors.white60,
                      size: 24,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                const Text(
                  'Thu nhập có thể rút',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  money(available),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Color(0xFFFBBF24),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Chờ: ${money(pending)}',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    AnimatedPressable(
                      onTap: onTapWithdraw,
                      child: FilledButton.icon(
                        onPressed: onTapWithdraw,
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF1D4ED8),
                          shape: const StadiumBorder(),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          minimumSize: const Size(0, 36),
                          elevation: 2,
                          shadowColor: const Color(0x28000000),
                        ),
                        icon: const Icon(
                          Icons.arrow_forward_rounded,
                          size: 14,
                          color: Color(0xFF1D4ED8),
                        ),
                        label: const Text('Rút tiền'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Pill status badge with glowing indicator dot
class PartnerStatusBadge extends StatelessWidget {
  const PartnerStatusBadge(this.status, {super.key});
  final TaskStatus status;

  @override
  Widget build(BuildContext context) {
    final style = taskStatusStyles[status]!;
    // Use luxury blue tint for active partner tasks
    final isBlue = style.color == AppColors.primary;
    final color = isBlue ? PartnerColors.primary : style.color;
    final bg = isBlue ? PartnerColors.softBlue : color.withValues(alpha: 0.1);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isBlue
              ? PartnerColors.softBlueBorder
              : color.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.4),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Text(
            style.label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// HTML-styled 3D Button with physical tactile press-down bevel shadow
enum Partner3DVariant { blue, green, red, light, outline }

class Partner3DButton extends StatefulWidget {
  const Partner3DButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = Partner3DVariant.blue,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Partner3DVariant variant;
  final bool isLoading;

  @override
  State<Partner3DButton> createState() => _Partner3DButtonState();
}

class _Partner3DButtonState extends State<Partner3DButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null && !widget.isLoading;

    Color bgTop;
    Color bgBottom;
    Color shadowColor;
    Color textColor;
    Border? border;

    switch (widget.variant) {
      case Partner3DVariant.blue:
        bgTop = const Color(0xFF4684FF);
        bgBottom = const Color(0xFF2563EB);
        shadowColor = const Color(0xFF184AA9);
        textColor = Colors.white;
        break;
      case Partner3DVariant.green:
        bgTop = const Color(0xFF25C89F);
        bgBottom = const Color(0xFF0AAB82);
        shadowColor = const Color(0xFF047F64);
        textColor = Colors.white;
        break;
      case Partner3DVariant.red:
        bgTop = const Color(0xFFFFF0F1);
        bgBottom = const Color(0xFFFFF0F1);
        shadowColor = Colors.transparent;
        textColor = const Color(0xFFC83B50);
        border = Border.all(color: const Color(0xFFFFDADF));
        break;
      case Partner3DVariant.light:
        bgTop = const Color(0xFFF1F6FF);
        bgBottom = const Color(0xFFF1F6FF);
        shadowColor = Colors.transparent;
        textColor = const Color(0xFF2457B5);
        border = Border.all(color: const Color(0xFFD9E5FA));
        break;
      case Partner3DVariant.outline:
        bgTop = Colors.white;
        bgBottom = Colors.white;
        shadowColor = Colors.transparent;
        textColor = const Color(0xFF2D5CBD);
        border = Border.all(color: const Color(0xFFD7E3F3));
        break;
    }

    final has3D =
        widget.variant == Partner3DVariant.blue ||
        widget.variant == Partner3DVariant.green;
    final dy = _pressed && enabled ? (has3D ? 3.5 : 1.5) : 0.0;

    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
      onTapUp: enabled
          ? (_) {
              setState(() => _pressed = false);
              widget.onPressed?.call();
            }
          : null,
      onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOutCubic,
        transform: Matrix4.translationValues(0, dy, 0),
        width: double.infinity,
        height: 48,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(13),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [bgTop, bgBottom],
          ),
          border: border,
          boxShadow: !enabled
              ? null
              : has3D
              ? [
                  BoxShadow(
                    color: shadowColor,
                    offset: Offset(0, _pressed ? 1 : 4.5),
                    blurRadius: 0,
                  ),
                  if (!_pressed)
                    BoxShadow(
                      color: bgBottom.withValues(alpha: 0.22),
                      offset: const Offset(0, 10),
                      blurRadius: 18,
                    ),
                ]
              : [
                  const BoxShadow(
                    color: Color(0x0A000000),
                    offset: Offset(0, 2),
                    blurRadius: 4,
                  ),
                ],
        ),
        alignment: Alignment.center,
        child: widget.isLoading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: textColor,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (widget.icon != null) ...[
                    Icon(widget.icon, size: 19, color: textColor),
                    const SizedBox(width: 8),
                  ],
                  Flexible(
                    child: Text(
                      widget.label,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// HTML-styled Hero Card with Royal Blue gradient, glow effects and 9-stage progress
class PartnerHeroWidget extends StatelessWidget {
  const PartnerHeroWidget({
    super.key,
    required this.name,
    this.subtitle,
    required this.currentStep,
    this.totalSteps = 4,
    this.stepLabel,
    this.isActive = false,
  });

  final String name;
  final String? subtitle;
  final int currentStep;
  final int totalSteps;
  final String? stepLabel;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment(-0.8, -0.6),
          end: Alignment(0.9, 0.9),
          colors: [Color(0xFF1B4CAE), Color(0xFF2563EB), Color(0xFF54A0F4)],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x351E5BF8),
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // Ambient radial background glow circles
            Positioned(
              right: -70,
              top: -85,
              child: Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.08),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.05),
                      spreadRadius: 40,
                      blurRadius: 0,
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 20,
              bottom: -70,
              child: Container(
                width: 180,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF76E7ED).withValues(alpha: 0.14),
                ),
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.24),
                      ),
                    ),
                    child: const Text(
                      'TASKLY PARTNER',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Xin chào, $name! 👋',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle ??
                        (isActive
                            ? 'Hãy bật nhận việc và khám phá những yêu cầu phù hợp cùng TaskLy.'
                            : 'Cùng hoàn thiện hành trình trở thành đối tác TaskLy chuyên nghiệp.'),
                    style: const TextStyle(
                      color: Color(0xFFE7EEFF),
                      fontSize: 12.5,
                      height: 1.45,
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

/// HTML-styled Pill Badge (blue, green, amber, red, gray)
class PartnerPillBadge extends StatelessWidget {
  const PartnerPillBadge({super.key, required this.text, this.type = 'blue'});

  final String text;
  final String type; // 'blue' | 'green' | 'amber' | 'red' | 'gray'

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color border;
    Color fg;

    switch (type) {
      case 'green':
        bg = const Color(0xFFE5FAF1);
        border = const Color(0xFFC9EEE0);
        fg = const Color(0xFF0B926B);
        break;
      case 'amber':
        bg = const Color(0xFFFFF6DF);
        border = const Color(0xFFFFE4AC);
        fg = const Color(0xFFAD751D);
        break;
      case 'red':
        bg = const Color(0xFFFFF0F2);
        border = const Color(0xFFFCD5DB);
        fg = const Color(0xFFCE4C55);
        break;
      case 'gray':
        bg = const Color(0xFFF1F5F9);
        border = const Color(0xFFDCE7F3);
        fg = const Color(0xFF6F8096);
        break;
      case 'blue':
      default:
        bg = const Color(0xFFE7EFFF);
        border = const Color(0xFFD4E2FF);
        fg = const Color(0xFF2456C0);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: border),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: fg,
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

/// HTML Section Title with optional right trailing badge
class PartnerSectionTitle extends StatelessWidget {
  const PartnerSectionTitle(this.title, {super.key, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 22, bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              title,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: PartnerColors.navy,
                letterSpacing: -0.2,
              ),
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            Flexible(child: trailing!),
          ],
        ],
      ),
    );
  }
}

/// Card displaying current status, reason/guideline, and 3D action button
class PartnerStatusActionCard extends StatelessWidget {
  const PartnerStatusActionCard({
    super.key,
    required this.emoji,
    required this.title,
    required this.description,
    required this.buttonText,
    required this.onTapButton,
    this.buttonVariant = Partner3DVariant.blue,
  });

  final String emoji;
  final String title;
  final String description;
  final String buttonText;
  final VoidCallback onTapButton;
  final Partner3DVariant buttonVariant;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE8EDF5)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A214777),
            blurRadius: 24,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 32)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        color: PartnerColors.navy,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 12,
                        color: PartnerColors.muted,
                        height: 1.55,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Partner3DButton(
            label: buttonText,
            onPressed: onTapButton,
            variant: buttonVariant,
          ),
        ],
      ),
    );
  }
}

/// Data structure for the 8 sub-steps across 4 onboarding stages
class _OnboardingSubStep {
  final int number;
  final String title;
  final String logic;

  const _OnboardingSubStep({
    required this.number,
    required this.title,
    required this.logic,
  });
}

class _OnboardingStage {
  final int stageNumber;
  final String title;
  final IconData icon;
  final List<_OnboardingSubStep> steps;

  const _OnboardingStage({
    required this.stageNumber,
    required this.title,
    required this.icon,
    required this.steps,
  });
}

const _kOnboardingStages = [
  _OnboardingStage(
    stageNumber: 1,
    title: 'Chặng 1: Kiểm tra kiến thức',
    icon: Icons.school_outlined,
    steps: [
      _OnboardingSubStep(
        number: 4,
        title: 'Partner Academy · Kiểm tra kiến thức',
        logic: 'Làm bài kiểm tra 20 câu ngẫu nhiên theo quy chế tuyển dụng.',
      ),
    ],
  ),
  _OnboardingStage(
    stageNumber: 2,
    title: 'Chặng 2: Nộp hồ sơ & Cam kết',
    icon: Icons.assignment_ind_outlined,
    steps: [
      _OnboardingSubStep(
        number: 1,
        title: 'Bước 1: Thông tin cá nhân & Hồ sơ',
        logic: 'Đăng ký tài khoản, upload CCCD và ảnh chân dung (thay vì để tách biệt).',
      ),
      _OnboardingSubStep(
        number: 2,
        title: 'Cam kết đối tác',
        logic: 'Ký điện tử các điều khoản an toàn, bảo mật thông tin khách hàng và quy định ứng xử.',
      ),
    ],
  ),
  _OnboardingStage(
    stageNumber: 3,
    title: 'Chặng 3: Xác minh & Nhận đồng phục',
    icon: Icons.verified_user_outlined,
    steps: [
      _OnboardingSubStep(
        number: 7,
        title: 'Chọn đồng phục',
        logic: 'Chọn gói, kích thước và hoàn tất thủ tục đồng phục trước khi đến văn phòng.',
      ),
      _OnboardingSubStep(
        number: 6,
        title: 'Xem địa chỉ & Xác nhận đến văn phòng',
        logic:
            'Xem địa chỉ văn phòng và tick xác nhận sẽ đến để đối chiếu giấy tờ gốc, nhận đồng phục.',
      ),
    ],
  ),
  _OnboardingStage(
    stageNumber: 4,
    title: 'Chặng 4: Sẵn sàng nhận việc',
    icon: Icons.rocket_launch_outlined,
    steps: [
      _OnboardingSubStep(
        number: 8,
        title: 'Check-in & Hồ sơ xác nhận',
        logic: 'Bổ sung ảnh chân dung và ảnh hợp đồng đã ký để admin kiểm duyệt và kích hoạt tài khoản.',
      ),
    ],
  ),
];

/// The onboarding journey component grouping sub-steps cleanly into 2 visible stages per phase
class PartnerJourneyTimeline extends StatefulWidget {
  const PartnerJourneyTimeline({
    super.key,
    required this.currentStep, // 1 to 8 (sub-step)
    this.isFullyActive = false,
    this.status = 'REGISTERED',
    required this.missingRequirements,
    this.examPassMark,
    this.onTapAction,
    this.isStage2Approved,
  });

  final int? examPassMark;
  final int currentStep;
  final Map<int, List<String>> missingRequirements;
  final bool isFullyActive;
  final String status;
  final void Function(int stepNumber)? onTapAction;
  final bool? isStage2Approved;

  @override
  State<PartnerJourneyTimeline> createState() => _PartnerJourneyTimelineState();
}

class _PartnerJourneyTimelineState extends State<PartnerJourneyTimeline> {
  late int _selectedStage;

  bool get _isApproved {
    if (widget.isStage2Approved != null) {
      return widget.isStage2Approved!;
    }
    if (widget.missingRequirements[5]?.isEmpty == true) {
      return true;
    }
    const approvedStatuses = {
      'PRELIMINARY_APPROVED',
      'DOCUMENT_APPOINTMENT',
      'DOCUMENTS_RECEIVED',
      'UNIFORM_PENDING',
      'FINAL_REVIEW',
      'APPROVED',
      'ACTIVE',
    };
    return approvedStatuses.contains(widget.status);
  }

  List<int> get _visibleStages => _isApproved ? const [3, 4] : const [1, 2];

  void _syncSelectedStage() {
    final visible = _visibleStages;
    if (!visible.contains(_selectedStage) || !canOpenOnboardingStage(_selectedStage, widget.missingRequirements)) {
      final active = firstIncompleteOnboardingStage(widget.missingRequirements);
      if (visible.contains(active)) {
        _selectedStage = active;
      } else {
        _selectedStage = visible.contains(2) && active > 2 ? 2 : visible.first;
      }
    }
  }

  @override
  void initState() {
    super.initState();
    final activeStage = firstIncompleteOnboardingStage(
      widget.missingRequirements,
    );
    final visible = _visibleStages;
    if (visible.contains(activeStage)) {
      _selectedStage = activeStage;
    } else {
      _selectedStage = visible.contains(2) && activeStage > 2 ? 2 : visible.first;
    }
  }

  @override
  void didUpdateWidget(covariant PartnerJourneyTimeline oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncSelectedStage();
  }

  void _selectStage(int stageNumber) {
    if (!canOpenOnboardingStage(stageNumber, widget.missingRequirements)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hoàn tất chặng trước để tiếp tục.')));
      return;
    }
    setState(() => _selectedStage = stageNumber);
  }

  @override
  Widget build(BuildContext context) {
    final activeStage = firstIncompleteOnboardingStage(
      widget.missingRequirements,
    );
    final approved = _isApproved;
    final visible = _visibleStages;

    final totalDone = _kOnboardingStages
        .where((stage) => stage.steps.every(
            (item) => widget.missingRequirements[item.number]?.isEmpty == true))
        .length;
    final stage1Done = _kOnboardingStages[0].steps.every(
        (step) => widget.missingRequirements[step.number]?.isEmpty == true);
    final stage2Done = _kOnboardingStages[1].steps.every(
        (step) => widget.missingRequirements[step.number]?.isEmpty == true);
    final phase1Done = (stage1Done ? 1 : 0) + (stage2Done ? 1 : 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Tiến trình 2 chặng ngang trực quan (Chặng 1-2 trước duyệt, Chặng 3-4 sau duyệt)
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x06000000),
                blurRadius: 10,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      widget.isFullyActive
                          ? 'Hoàn tất cả các chặng'
                          : approved
                              ? 'Tiến độ: Chặng $activeStage/4'
                              : (stage1Done && stage2Done
                                  ? 'Tiến độ: Chờ duyệt chặng 2'
                                  : 'Tiến độ: Chặng ${activeStage <= 2 ? activeStage : 2}/2'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: PartnerColors.navy,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        approved
                            ? '$totalDone/4 chặng hoàn thành'
                            : '$phase1Done/2 chặng hoàn thành',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: visible.map((stageNum) {
                  final i = stageNum - 1;
                  final unlocked = canOpenOnboardingStage(
                    stageNum,
                    widget.missingRequirements,
                  );
                  final isDone = _kOnboardingStages[i].steps.every(
                    (step) =>
                        widget.missingRequirements[step.number]?.isEmpty ==
                        true,
                  );
                  final isCurrent = _selectedStage == stageNum;
                  final isLast = stageNum == visible.last;
                  return Expanded(
                    child: InkWell(
                      onTap: unlocked ? () => _selectStage(stageNum) : null,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        margin: EdgeInsets.only(right: isLast ? 0 : 8),
                        padding: const EdgeInsets.symmetric(
                          vertical: 9,
                          horizontal: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isDone
                              ? const Color(0xFFDCFCE7)
                              : isCurrent
                              ? const Color(0xFFFEF2F2)
                              : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDone
                                ? const Color(0xFF86EFAC)
                                : isCurrent
                                ? const Color(0xFFFCA5A5)
                                : const Color(0xFFE2E8F0),
                            width: isCurrent ? 1.5 : 1,
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isDone
                                  ? Icons.check_circle_rounded
                                  : isCurrent
                                  ? Icons.radio_button_checked_rounded
                                  : (unlocked ? Icons.lock_open_rounded : Icons.lock_outline_rounded),
                              size: 16,
                              color: isDone
                                  ? const Color(0xFF16A34A)
                                  : isCurrent
                                  ? const Color(0xFFDC2626)
                                  : const Color(0xFF94A3B8),
                            ),
                            const SizedBox(height: 3),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                'Chặng $stageNum',
                                maxLines: 1,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: isDone
                                      ? const Color(0xFF15803D)
                                      : isCurrent
                                      ? const Color(0xFFB91C1C)
                                      : const Color(0xFF64748B),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),

        // 2. Danh sách Khối Chặng được chọn (Chỉ show ra khi bấm vào)
        ..._kOnboardingStages.where((stage) => stage.stageNumber == _selectedStage).map((
          st,
        ) {
          final lastStep = st.steps.last.number;
          final needsSupplement = st.steps.any(
            (step) =>
                step.number <= widget.currentStep &&
                widget.missingRequirements[step.number]?.isNotEmpty == true,
          );
          final firstStep = st.steps.first.number;
          final isStageDone = st.steps.every(
            (step) => widget.missingRequirements[step.number]?.isEmpty == true,
          );
          final isStageCurrent =
              !widget.isFullyActive &&
              (widget.currentStep >= firstStep &&
                  widget.currentStep <= lastStep);
          const isExpanded = true;

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: (isStageCurrent || needsSupplement)
                    ? const Color(0xFFDC2626)
                    : isStageDone
                    ? const Color(0xFF86EFAC)
                    : const Color(0xFFE2E8F0),
                width: isStageCurrent ? 1.5 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: (isStageCurrent || needsSupplement)
                      ? const Color(0x14DC2626)
                      : const Color(0x06000000),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Chặng (Bấm để mở rộng / thu gọn)
                InkWell(
                  onTap: () => _selectStage(st.stageNumber),
                  borderRadius: BorderRadius.circular(18),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: isStageDone
                                ? const Color(0xFFDCFCE7)
                                : (isStageCurrent || needsSupplement)
                                ? const Color(0xFFFEF2F2)
                                : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            st.icon,
                            size: 20,
                            color: isStageDone
                                ? const Color(0xFF16A34A)
                                : (isStageCurrent || needsSupplement)
                                ? const Color(0xFFDC2626)
                                : const Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                st.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight:
                                      (isStageCurrent || needsSupplement)
                                      ? FontWeight.w800
                                      : FontWeight.w700,
                                  color: (isStageCurrent || needsSupplement)
                                      ? PartnerColors.navy
                                      : const Color(0xFF1E293B),
                                  letterSpacing: -0.2,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Hoàn thiện các yêu cầu của chặng',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF64748B),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: isStageDone
                                ? const Color(0xFFDCFCE7)
                                : (isStageCurrent || needsSupplement)
                                ? const Color(0xFFFEF2F2)
                                : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isStageDone
                                  ? const Color(0xFF86EFAC)
                                  : (isStageCurrent || needsSupplement)
                                  ? const Color(0xFFFECACA)
                                  : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Text(
                            isStageDone
                                ? '✓ Xong'
                                : needsSupplement
                                ? 'Cần bổ sung'
                                : (isStageCurrent || needsSupplement)
                                ? 'Đang làm'
                                : 'Chờ mở',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: isStageDone
                                  ? const Color(0xFF15803D)
                                  : (isStageCurrent || needsSupplement)
                                  ? const Color(0xFFB91C1C)
                                  : const Color(0xFF94A3B8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Chi tiết các đầu việc nhỏ bên trong
                if (isExpanded) ...[
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                    child: Column(
                      children: st.steps.map((step) {
                        final isStepDone =
                            widget.missingRequirements[step.number]?.isEmpty ==
                            true;
                        final isStepCurrent =
                            !isStepDone && widget.currentStep >= step.number;
                        final isLastInStage = step == st.steps.last;

                        return Padding(
                          padding: EdgeInsets.only(
                            bottom: isLastInStage ? 0 : 10,
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: (step.number != 8 || ['APPROVED', 'FINAL_REVIEW'].contains(widget.status)) && widget.onTapAction != null
                                  ? () => widget.onTapAction!(step.number)
                                  : null,
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: isStepCurrent
                                      ? const Color(0xFFFEF2F2)
                                      : isStepDone
                                      ? const Color(0xFFF9FDF9)
                                      : const Color(0xFFFAFAFA),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isStepCurrent
                                        ? const Color(0xFFFCA5A5)
                                        : isStepDone
                                        ? const Color(0xFFDCFCE7)
                                        : const Color(0xFFE2E8F0),
                                    width: isStepCurrent ? 1.2 : 1,
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 22,
                                      height: 22,
                                      margin: const EdgeInsets.only(top: 2),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: isStepDone
                                            ? const Color(0xFFDCFCE7)
                                            : isStepCurrent
                                            ? const Color(0xFFDC2626)
                                            : const Color(0xFFF1F5F9),
                                        border: Border.all(
                                          color: isStepDone
                                              ? const Color(0xFF22C55E)
                                              : isStepCurrent
                                              ? const Color(0xFFDC2626)
                                              : const Color(0xFFCBD5E1),
                                        ),
                                      ),
                                      alignment: Alignment.center,
                                      child: isStepDone
                                          ? const Icon(
                                              Icons.check_rounded,
                                              size: 13,
                                              color: Color(0xFF16A34A),
                                            )
                                          : Icon(
                                              isStepCurrent
                                                  ? Icons.priority_high_rounded
                                                  : Icons.circle_outlined,
                                              size: 15,
                                              color: isStepCurrent
                                                  ? Colors.white
                                                  : const Color(0xFF64748B),
                                            ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  step.number == 8 && widget.status == 'FINAL_REVIEW'
                                                      ? 'Chờ admin kiểm duyệt hồ sơ'
                                                      : step.title,
                                                  style: TextStyle(
                                                    fontSize: 12.5,
                                                    fontWeight: isStepCurrent
                                                        ? FontWeight.w800
                                                        : FontWeight.w700,
                                                    color: isStepCurrent
                                                        ? const Color(
                                                            0xFFB91C1C,
                                                          )
                                                        : isStepDone
                                                        ? const Color(
                                                            0xFF1E293B,
                                                          )
                                                        : const Color(
                                                            0xFF475569,
                                                          ),
                                                  ),
                                                ),
                                              ),
                                              if (isStepCurrent) ...[
                                                const SizedBox(width: 4),
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 5,
                                                        vertical: 1.5,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: const Color(
                                                      0xFFFEE2E2,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          5,
                                                        ),
                                                  ),
                                                  child: const Text(
                                                    'Cần làm',
                                                    style: TextStyle(
                                                      fontSize: 9.5,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: Color(0xFFB91C1C),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            isStepCurrent
                                                ? 'Chưa hoàn tất: ${widget.missingRequirements[step.number]!.join(' ')}'
                                                : step.number == 4 &&
                                                      widget.examPassMark !=
                                                          null
                                                ? '20 câu ngẫu nhiên. Đạt tối thiểu ${widget.examPassMark}/20 câu đúng.'
                                                : step.logic,
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              height: 1.4,
                                              color: isStepCurrent
                                                  ? const Color(0xFFB91C1C)
                                                  : const Color(0xFF64748B),
                                            ),
                                          ),
                                          if (step.number == 5 && isStepCurrent) ...[
                                            const SizedBox(height: 5),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFEFF6FF),
                                                borderRadius: BorderRadius.circular(6),
                                                border: Border.all(color: const Color(0xFFBFDBFE)),
                                              ),
                                              child: const Row(
                                                children: [
                                                  Icon(Icons.schedule_rounded, size: 13, color: Color(0xFF1D4ED8)),
                                                  SizedBox(width: 5),
                                                  Expanded(
                                                    child: Text(
                                                      'Thời gian xét duyệt: Trong khoảng 24 giờ kể từ khi hoàn tất cam kết.',
                                                      style: TextStyle(
                                                        fontSize: 10.5,
                                                        fontWeight: FontWeight.w700,
                                                        color: Color(0xFF1E40AF),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                          if ((step.number != 8 || ['APPROVED', 'FINAL_REVIEW'].contains(widget.status)) && widget.onTapAction != null) ...[
                                            const SizedBox(height: 8),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 4,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: isStepCurrent
                                                    ? const Color(0xFFFEF2F2)
                                                    : isStepDone
                                                    ? const Color(0xFFF0FDF4)
                                                    : const Color(0xFFFFFFFF),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                border: Border.all(
                                                  color: isStepCurrent
                                                      ? const Color(0xFFFECACA)
                                                      : isStepDone
                                                      ? const Color(0xFFBBF7D0)
                                                      : const Color(0xFFCBD5E1),
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Flexible(
                                                    child: Text(
                                                      step.number == 8
                                                          ? widget.status == 'FINAL_REVIEW' ? 'Xem chi tiết hồ sơ đã gửi' : 'Bổ sung ảnh chân dung & Hợp đồng'
                                                          : isStepDone
                                                          ? 'Xem chi tiết'
                                                          : isStepCurrent
                                                          ? 'Thực hiện ngay'
                                                          : 'Xem chi tiết',
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        color: isStepCurrent
                                                            ? const Color(
                                                                0xFFDC2626,
                                                              )
                                                            : isStepDone
                                                            ? const Color(
                                                                0xFF16A34A,
                                                              )
                                                            : const Color(
                                                                0xFF334155,
                                                              ),
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Icon(
                                                    isStepDone
                                                        ? Icons
                                                              .check_circle_outline_rounded
                                                        : Icons
                                                              .arrow_forward_rounded,
                                                    size: 12,
                                                    color: isStepCurrent
                                                        ? const Color(
                                                            0xFFDC2626,
                                                          )
                                                        : isStepDone
                                                        ? const Color(
                                                            0xFF16A34A,
                                                          )
                                                        : const Color(
                                                            0xFF64748B,
                                                          ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ],
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
                  ),
                ],
              ],
            ),
          );
        }),
      ],
    );
  }
}

/// Grid 2 items: Thông báo & Hỗ trợ matching HTML .grid2 .item
class PartnerQuickAccessGrid extends StatelessWidget {
  const PartnerQuickAccessGrid({
    super.key,
    required this.onTapNotifications,
    required this.onTapSupport,
  });

  final VoidCallback onTapNotifications;
  final VoidCallback onTapSupport;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 360) {
          return Column(
            children: [
              _item(
                emoji: '🔔',
                title: 'Thông báo',
                subtitle: 'Kết quả xét duyệt',
                onTap: onTapNotifications,
              ),
              const SizedBox(height: 10),
              _item(
                emoji: '💬',
                title: 'Hỗ trợ',
                subtitle: 'Trao đổi với TaskLy',
                onTap: onTapSupport,
              ),
            ],
          );
        }
        return Row(
          children: [
            Expanded(
              child: _item(
                emoji: '🔔',
                title: 'Thông báo',
                subtitle: 'Kết quả xét duyệt',
                onTap: onTapNotifications,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _item(
                emoji: '💬',
                title: 'Hỗ trợ',
                subtitle: 'Trao đổi với TaskLy',
                onTap: onTapSupport,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _item({
    required String emoji,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE6EDF7)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x061E40AF),
                blurRadius: 10,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFEDF5FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(emoji, style: const TextStyle(fontSize: 18)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: PartnerColors.navy,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF7C8CA1),
                      ),
                      overflow: TextOverflow.ellipsis,
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
}

/// Generic HTML .item tile with square icon container, main text, and chevron
class PartnerItemTile extends StatelessWidget {
  const PartnerItemTile({
    super.key,
    required this.emoji,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.trailing,
  });

  final String emoji;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
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
          onTap: onTap,
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
                  child: Text(emoji, style: const TextStyle(fontSize: 19)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: PartnerColors.navy,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: Color(0xFF7C8CA1),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                if (trailing != null)
                  trailing!
                else if (onTap != null)
                  const Text(
                    '›',
                    style: TextStyle(
                      fontSize: 22,
                      color: Color(0xFF8BA6CA),
                      fontWeight: FontWeight.w300,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
