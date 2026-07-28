// lib/widgets/update_dialog.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:active_class/config/theme.dart';
import 'package:active_class/services/update_service.dart';

const String _kSkippedVersionKey = 'update_skipped_version';

/// يعرض ديالوج تحديث لو فيه إصدار جديد على GitHub. لو [silent] كانت true
/// (الفحص التلقائي عند فتح التطبيق)، بيتجاهل الإصدار اللي المعلم اختار
/// "لاحقًا" عليه قبل كده عشان ميضايقوش كل مرة بنفس التحديث.
Future<void> checkAndShowUpdateDialog(
  BuildContext context, {
  bool silent = true,
}) async {
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
                Text(info.releaseNotes,
                    style: const TextStyle(fontFamily: 'Cairo', fontSize: 13)),
              ] else
                const Text('نسخة جديدة من التطبيق متاحة للتحميل.',
                    style: TextStyle(fontFamily: 'Cairo', fontSize: 13)),
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
            final url = info.apkUrl ?? info.htmlUrl;
            await launchUrl(Uri.parse(url),
                mode: LaunchMode.externalApplication);
            if (context.mounted) Navigator.of(context).pop();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryColor,
            foregroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          icon: const Icon(Icons.download_rounded, size: 18),
          label: const Text('تحميل التحديث',
              style: TextStyle(fontFamily: 'Cairo')),
        ),
      ],
    );
  }
}
