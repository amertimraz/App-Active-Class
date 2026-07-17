// lib/widgets/app_toast.dart
// نظام توست/هنت موحد وجميل للتطبيق

import 'dart:ui';
import 'package:flutter/material.dart';

// ══════════════════════════════════════════════════════════════════
//  AppToast  —  استخدام: AppToast.show(context, ...)
// ══════════════════════════════════════════════════════════════════
enum ToastType { success, error, info, warning }

class AppToast {
  // ───────────────── Public API ─────────────────
  static void success(BuildContext context, String message, {String? subtitle}) =>
      _show(context, message, subtitle: subtitle, type: ToastType.success);

  static void error(BuildContext context, String message, {String? subtitle}) =>
      _show(context, message, subtitle: subtitle, type: ToastType.error);

  static void info(BuildContext context, String message, {String? subtitle}) =>
      _show(context, message, subtitle: subtitle, type: ToastType.info);

  static void warning(BuildContext context, String message, {String? subtitle}) =>
      _show(context, message, subtitle: subtitle, type: ToastType.warning);

  // ───────────────── Core ────────────────────────
  static OverlayEntry? _current;

  static void _show(
    BuildContext context,
    String message, {
    String? subtitle,
    required ToastType type,
    Duration duration = const Duration(milliseconds: 2400),
  }) {
    final overlay = Overlay.of(context, rootOverlay: true);

    // أغلق الحالي لو موجود
    _current?.remove();
    _current = null;

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _ToastWidget(
        message: message,
        subtitle: subtitle,
        type: type,
        duration: duration,
        onDismiss: () {
          entry.remove();
          if (_current == entry) _current = null;
        },
      ),
    );

    _current = entry;
    overlay.insert(entry);
  }
}

// ══════════════════════════════════════════════════════════════════
//  _ToastWidget  —  الـ widget الفعلي مع الأنيميشن
// ══════════════════════════════════════════════════════════════════
class _ToastWidget extends StatefulWidget {
  const _ToastWidget({
    required this.message,
    required this.subtitle,
    required this.type,
    required this.duration,
    required this.onDismiss,
  });

  final String message;
  final String? subtitle;
  final ToastType type;
  final Duration duration;
  final VoidCallback onDismiss;

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _opacity;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

    _ctrl.forward();

    Future.delayed(widget.duration, _dismiss);
  }

  void _dismiss() async {
    if (!mounted) return;
    await _ctrl.reverse();
    widget.onDismiss();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  // ── Theme data per type ──
  static const _icons = {
    ToastType.success: Icons.check_circle_rounded,
    ToastType.error: Icons.error_rounded,
    ToastType.info: Icons.info_rounded,
    ToastType.warning: Icons.warning_rounded,
  };

  static const _colors = {
    ToastType.success: Color(0xFF2E7D32),
    ToastType.error: Color(0xFFC62828),
    ToastType.info: Color(0xFF0277BD),
    ToastType.warning: Color(0xFFE65100),
  };

  @override
  Widget build(BuildContext context) {
    final color = _colors[widget.type]!;
    final icon = _icons[widget.type]!;
    final isDark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1E2530) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1A1A2E);

    return Positioned(
      bottom: MediaQuery.of(context).padding.bottom + 24,
      left: 20,
      right: 20,
      child: FadeTransition(
        opacity: _opacity,
        child: SlideTransition(
          position: _slide,
          child: Material(
            color: Colors.transparent,
            child: GestureDetector(
              onTap: _dismiss,
              child: Container(
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: color.withValues(alpha: 0.25),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: isDark ? 0.25 : 0.15),
                      blurRadius: 20,
                      spreadRadius: 1,
                      offset: const Offset(0, 4),
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      child: Row(
                        children: [
                          // ── Icon ──
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(icon, color: color, size: 22),
                          ),
                          const SizedBox(width: 12),
                          // ── Text ──
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  widget.message,
                                  style: TextStyle(
                                    color: textColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    fontFamily: 'Cairo',
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (widget.subtitle != null &&
                                    widget.subtitle!.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    widget.subtitle!,
                                    style: TextStyle(
                                      color: textColor.withValues(alpha: 0.55),
                                      fontSize: 12,
                                      fontFamily: 'Cairo',
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          // ── Accent bar ──
                          const SizedBox(width: 8),
                          Container(
                            width: 3,
                            height: 36,
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(2),
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
      ),
    );
  }
}
