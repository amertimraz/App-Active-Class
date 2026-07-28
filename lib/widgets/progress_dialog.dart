// lib/widgets/progress_dialog.dart
// حوار تقدّم سلس بشريط متحرك — بديل عن LoadingDialog البسيط لعمليات
// زي الحذف/النسخ الاحتياطي، عشان تحس إن فيه حاجة فعلاً بتحصل.
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:active_class/config/theme.dart';

class ProgressDialog {
  /// يشغّل [task] مع عرض حوار بشريط تقدّم متحرك بلون [color].
  /// الشريط بيتحرك بسلاسة لحد 85% خلال [minDuration]، وبيفضل واقف
  /// هناك (مش بيختفي فجأة) لو العملية الحقيقية أبطأ، وبمجرد ما
  /// [task] يخلص بيكمل لـ100% ويقفل الحوار تلقائياً.
  static Future<T> run<T>(
    BuildContext context, {
    required String title,
    required Future<T> Function() task,
    IconData icon = Icons.hourglass_top_rounded,
    Color? color,
    Duration minDuration = const Duration(milliseconds: 900),
  }) async {
    final key = GlobalKey<_ProgressDialogContentState>();

    unawaited(showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ProgressDialogContent(
        key: key,
        title: title,
        icon: icon,
        color: color ?? AppTheme.primaryColor,
        minDuration: minDuration,
      ),
    ));
    // اضمن إن الحوار اتبنى فعلاً (State جاهزة) قبل ما نبدأ العملية،
    // عشان completeAndClose() تلاقي key.currentState موجود حتى لو
    // العملية خلصت بسرعة شديدة (أسرع من فريم واحد).
    await Future.delayed(Duration.zero);

    Object? error;
    T? value;
    try {
      value = await task();
    } catch (e) {
      error = e;
    }

    // استنى الأنيميشن يوصل لحد أدنى معقول قبل ما نقفل، عشان الحوار
    // ميختفيش فجأة لو العملية خلصت بسرعة جداً.
    await key.currentState?.completeAndClose();

    if (error != null) throw error;
    return value as T;
  }
}

class _ProgressDialogContent extends StatefulWidget {
  final String title;
  final IconData icon;
  final Color color;
  final Duration minDuration;
  const _ProgressDialogContent({
    super.key,
    required this.title,
    required this.icon,
    required this.color,
    required this.minDuration,
  });

  @override
  State<_ProgressDialogContent> createState() => _ProgressDialogContentState();
}

class _ProgressDialogContentState extends State<_ProgressDialogContent>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.minDuration)
      ..animateTo(0.85, curve: Curves.easeOutCubic);
  }

  Future<void> completeAndClose() async {
    // اضمن إن الأنيميشن الأولانية (لحد 85%) خلصت الأول
    while (_controller.isAnimating) {
      await Future.delayed(const Duration(milliseconds: 30));
    }
    if (!mounted) return;
    setState(() => _done = true);
    await _controller.animateTo(1, duration: const Duration(milliseconds: 220));
    await Future.delayed(const Duration(milliseconds: 200));
    if (mounted) Navigator.of(context, rootNavigator: true).pop();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return PopScope(
      canPop: false,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        backgroundColor: isDark ? const Color(0xFF131D31) : Colors.white,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                transitionBuilder: (child, anim) =>
                    ScaleTransition(scale: anim, child: child),
                child: _done
                    ? Icon(Icons.check_circle_rounded,
                        key: const ValueKey('done'),
                        size: 46, color: Colors.green)
                    : Icon(widget.icon,
                        key: const ValueKey('busy'),
                        size: 46, color: widget.color),
              ),
              const SizedBox(height: 16),
              Text(widget.title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: isDark ? Colors.white : const Color(0xFF111827))),
              const SizedBox(height: 18),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (_, __) => LinearProgressIndicator(
                    value: _controller.value,
                    minHeight: 8,
                    backgroundColor:
                        widget.color.withValues(alpha: isDark ? 0.15 : 0.12),
                    valueColor: AlwaysStoppedAnimation(
                        _done ? Colors.green : widget.color),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
