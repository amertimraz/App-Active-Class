// lib/widgets/update_dialog.dart
import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:active_class/config/theme.dart';
import 'package:active_class/services/install_source_service.dart';
import 'package:active_class/services/update_service.dart';
import 'package:active_class/utils/helpers.dart';

const String _kSkippedVersionKey = 'update_skipped_version';

/// يعرض ديالوج تحديث لو فيه إصدار جديد على GitHub. لو [silent] كانت true
/// (الفحص التلقائي عند فتح التطبيق)، بيتجاهل الإصدار اللي المعلم اختار
/// "لاحقًا" عليه قبل كده عشان ميضايقوش كل مرة بنفس التحديث.
///
/// بيتجاهل الفحص تمامًا لو التطبيق متثبّت من Google Play — تحديث ذاتي
/// خارج آلية المتجر مخالف صريح لسياسات Google Play وممكن يعرّض الحساب
/// للحظر؛ في الحالة دي المتجر نفسه هو اللي بيتولى التحديثات.
Future<void> checkAndShowUpdateDialog(
  BuildContext context, {
  bool silent = true,
}) async {
  if (await InstallSourceService.isInstalledFromPlayStore()) {
    if (!silent && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('التحديثات بتوصلك تلقائيًا من متجر Google Play',
            style: TextStyle(fontFamily: 'Cairo')),
        behavior: SnackBarBehavior.floating,
      ));
    }
    return;
  }

  final info = await UpdateService().checkForUpdate();
  if (info == null) {
    if (!silent && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('التطبيق محدّث لآخر إصدار ✓',
            style: TextStyle(fontFamily: 'Cairo')),
        behavior: SnackBarBehavior.floating,
      ));
    }
    return;
  }
  if (!context.mounted) return;

  if (silent) {
    final prefs = await SharedPreferences.getInstance();
    final skipped = prefs.getString(_kSkippedVersionKey);
    if (skipped == info.version) return;
    if (!context.mounted) return;
  }

  await showDialog(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => _UpdateDialog(info: info),
  );
}

class _UpdateDialog extends StatelessWidget {
  final UpdateInfo info;
  const _UpdateDialog({required this.info});

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).colorScheme.onSurface;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          const Icon(Icons.system_update_rounded, color: AppTheme.primaryColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text('تحديث جديد متاح: ${info.version}',
                style: const TextStyle(
                    fontFamily: 'Cairo', fontWeight: FontWeight.w800)),
          ),
        ],
      ),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (info.releaseNotes.isNotEmpty) ...[
                Text('ما الجديد:',
                    style: TextStyle(
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: Colors.grey.shade700)),
                const SizedBox(height: 6),
                ..._renderMarkdownLite(info.releaseNotes, textColor: textColor),
              ] else
                const Text('نسخة جديدة من التطبيق متاحة للتحميل.',
                    style: TextStyle(fontFamily: 'Cairo', fontSize: 13)),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border:
                      Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded,
                        size: 18, color: Colors.amber.shade800),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'ممكن يظهر تحذير من "Play Protect" أثناء التثبيت لأن '
                        'التطبيق مش من متجر Google Play — ده طبيعي، اضغط '
                        '"التثبيت على أي حال" ثم "حسنًا" عشان تكمل.',
                        style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 12,
                            height: 1.5,
                            color: Colors.amber.shade900),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () async {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString(_kSkippedVersionKey, info.version);
            if (context.mounted) Navigator.of(context).pop();
          },
          child: const Text('لاحقًا', style: TextStyle(fontFamily: 'Cairo')),
        ),
        ElevatedButton.icon(
          onPressed: () async {
            Navigator.of(context).pop();
            await _downloadAndInstall(context, info);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryColor,
            foregroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          icon: const Icon(Icons.system_update_alt_rounded, size: 18),
          label:
              const Text('تحديث الآن', style: TextStyle(fontFamily: 'Cairo')),
        ),
      ],
    );
  }
}

// ── تحميل وتثبيت داخل التطبيق مباشرة ───────────────────────────────────────

Future<void> _downloadAndInstall(BuildContext context, UpdateInfo info) async {
  if (info.apkUrl == null) {
    // مفيش ملف APK مرفق بالإصدار — نفتح صفحة الإصدار في المتصفح كحل بديل
    await launchUrl(Uri.parse(info.htmlUrl),
        mode: LaunchMode.externalApplication);
    return;
  }

  final progress = ValueNotifier<double>(0);
  final cancelToken = CancelToken();
  var cancelled = false;

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _DownloadProgressDialog(
      progress: progress,
      onCancel: () {
        cancelled = true;
        cancelToken.cancel();
      },
    ),
  );
  // اضمن إن الحوار اتبنى قبل ما نبدأ التحميل
  await Future.delayed(Duration.zero);

  var expectedBytes = -1;
  try {
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/active_class_${info.version}.apk';
    // مهلات صريحة عشان لو الاتصال توقّف فجأة (شبكة ضعيفة/انقطعت)، التحميل
    // يفشل برسالة واضحة بدل ما يفضل الحوار عالق للأبد بدون أي طريقة
    // للخروج منه (وده كان بيضطر المعلم يقفل التطبيق بالقوة).
    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20),
    ));
    await dio.download(
      info.apkUrl!,
      path,
      cancelToken: cancelToken,
      onReceiveProgress: (received, total) {
        if (total > 0) {
          expectedBytes = total;
          progress.value = received / total;
        }
      },
    );

    // تأكيد إن الملف اتحمّل كامل قبل ما نفتح المثبّت — لو الاتصال اتقطع في
    // آخر لحظة من غير ما Dio يرمي استثناء، بيفضل ملف ناقص على الجهاز
    // وأندرويد بيديه بالظبط خطأ "حدثت مشكلة أثناء تحليل الحزمة" لو حاولنا
    // نفتحه، فبنكتشف النقص هنا ونطلب من المعلم يعيد المحاولة بدل كده.
    final downloadedBytes = await File(path).length();
    if (expectedBytes > 0 && downloadedBytes < expectedBytes) {
      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
      ToastHelper.error('التحميل لم يكتمل — تحقق من الاتصال وحاول تاني');
      return;
    }

    if (context.mounted) Navigator.of(context, rootNavigator: true).pop();

    // بنحدد نوع الملف صراحةً (APK) بدل ما نسيب أندرويد يخمّنه من
    // الامتداد — لو التخمين فشل (بيحصل على بعض الأجهزة)، أندرويد بيفتح
    // الملف بأي تطبيق عام زي SHAREit بدل مثبّت النظام.
    final result = await OpenFilex.open(path,
        type: 'application/vnd.android.package-archive');
    if (result.type != ResultType.done) {
      ToastHelper.error('تعذر فتح مثبّت التحديث — حاول تاني');
    }
  } catch (_) {
    if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
    if (!cancelled) {
      ToastHelper.error('فشل تحميل التحديث — تحقق من الاتصال بالإنترنت');
    }
  }
}

class _DownloadProgressDialog extends StatelessWidget {
  final ValueNotifier<double> progress;
  final VoidCallback onCancel;
  const _DownloadProgressDialog(
      {required this.progress, required this.onCancel});

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
              const Icon(Icons.download_rounded,
                  size: 46, color: AppTheme.primaryColor),
              const SizedBox(height: 16),
              Text('جاري تحميل التحديث...',
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: isDark ? Colors.white : const Color(0xFF111827))),
              const SizedBox(height: 18),
              ValueListenableBuilder<double>(
                valueListenable: progress,
                builder: (_, value, __) => Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: value == 0 ? null : value,
                        minHeight: 8,
                        backgroundColor:
                            AppTheme.primaryColor.withValues(alpha: 0.12),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      value == 0
                          ? '...'
                          : '${(value * 100).toStringAsFixed(0)}%',
                      style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 12,
                          color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: onCancel,
                child: Text('إلغاء',
                    style: TextStyle(
                        fontFamily: 'Cairo', color: Colors.grey.shade600)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── عرض بسيط لملاحظات الإصدار (Markdown خفيف: ##, -, **bold**) ─────────────

List<Widget> _renderMarkdownLite(String md, {required Color textColor}) {
  final widgets = <Widget>[];
  for (final raw in md.split('\n')) {
    final line = raw.trimRight();
    if (line.trim().isEmpty) {
      widgets.add(const SizedBox(height: 6));
    } else if (line.startsWith('## ')) {
      widgets.add(Padding(
        padding: const EdgeInsets.only(top: 6, bottom: 4),
        child: Text(line.substring(3).trim(),
            style: TextStyle(
                fontFamily: 'Cairo',
                fontWeight: FontWeight.w800,
                fontSize: 14,
                color: textColor)),
      ));
    } else if (line.startsWith('- ')) {
      widgets.add(Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Icon(Icons.circle, size: 5, color: textColor),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: RichText(
                text: TextSpan(
                  children: _parseInlineBold(
                    line.substring(2).trim(),
                    TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 13,
                        height: 1.5,
                        color: textColor),
                  ),
                ),
              ),
            ),
          ],
        ),
      ));
    } else {
      widgets.add(Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: RichText(
          text: TextSpan(
            children: _parseInlineBold(
              line,
              TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 13,
                  height: 1.5,
                  color: textColor),
            ),
          ),
        ),
      ));
    }
  }
  return widgets;
}

List<InlineSpan> _parseInlineBold(String text, TextStyle base) {
  final parts = text.split('**');
  final spans = <InlineSpan>[];
  for (var i = 0; i < parts.length; i++) {
    if (parts[i].isEmpty) continue;
    final bold = i.isOdd;
    spans.add(TextSpan(
        text: parts[i],
        style: bold ? base.copyWith(fontWeight: FontWeight.w800) : base));
  }
  if (spans.isEmpty) spans.add(TextSpan(text: text, style: base));
  return spans;
}
