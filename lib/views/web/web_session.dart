// lib/views/web/web_session.dart
//
// spec 055 (FR-021) — تسجيل الخروج على الويب: تأكيد، تحذير لو فيه تعديلات لسه
// ماترفعتش، ثم خروج + مسح بيانات المتصفح المحلية (كمبيوتر مشترك في سنتر) +
// إعادة تحميل الصفحة. بياناتك محفوظة على حسابك وبترجع عند الدخول تاني.
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:active_class/config/constants.dart';
import 'package:active_class/controllers/auth_controller.dart';
import 'package:active_class/core/platform/browser_storage_purge.dart';
import 'package:active_class/core/platform/db_factory.dart';
import 'package:active_class/core/platform/page_reload.dart';
import 'package:active_class/services/database_service.dart';

/// عدد التعديلات اللي لسه ماترفعتش للسيرفر (0 لو تعذّر القراءة).
Future<int> pendingUnsyncedCount() async {
  try {
    final db = await DatabaseService().database;
    final rows = await db.query(TABLE_SYNC_OUTBOX,
        columns: [COL_OUTBOX_ID], where: '$COL_OUTBOX_SYNCED = 0');
    return rows.length;
  } catch (_) {
    return 0;
  }
}

Future<void> confirmAndSignOutWeb(BuildContext context) async {
  final pending = await pendingUnsyncedCount();
  if (!context.mounted) return;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        title: const Text('تسجيل الخروج؟',
            style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700)),
        content: Text(
          pending > 0
              ? 'فيه $pending تعديل لسه ماترفعش للسيرفر. لو خرجت دلوقتي هتضيع. '
                  'استنى دقيقة لحد ما يترفعوا، أو اخرج وامسحهم.'
              : 'هيتمسح بيانات الويب المحلية من المتصفح ده. بياناتك محفوظة على '
                  'حسابك وهترجع لما تدخل تاني.',
          style: const TextStyle(fontFamily: 'Cairo', height: 1.7),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(pending > 0 ? 'استنى' : 'إلغاء',
                  style: const TextStyle(fontFamily: 'Cairo'))),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626)),
            child: Text(pending > 0 ? 'اخرج وامسح' : 'تسجيل الخروج',
                style: const TextStyle(fontFamily: 'Cairo')),
          ),
        ],
      ),
    ),
  );
  if (ok != true) return;
  await signOutAndWipeWeb();
}

/// مسح بيانات القاعدة المحلية فعليًا (حذف كل الصفوف + secure_delete + VACUUM).
/// حذف ملف القاعدة وحده ما كانش بيمسح محتوى IndexedDB على الويب (اتجرّب
/// عمليًا)، فنمسح المحتوى نفسه الأول. مش جوه transaction (PRAGMA/VACUUM).
Future<void> wipeLocalDatabase() async {
  final db = await DatabaseService().database;
  await db.execute('PRAGMA foreign_keys = OFF');
  await db.execute('PRAGMA secure_delete = ON');
  final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'");
  for (final t in tables) {
    await db.execute('DELETE FROM "${t['name']}"');
  }
  await db.execute('VACUUM');
}

/// خروج + مسح كل البيانات المحلية + إعادة تحميل. أي خطوة تفشل ما بتوقفش الباقي.
Future<void> signOutAndWipeWeb() async {
  try {
    await AuthController.to.signOut();
  } catch (_) {}
  try {
    await wipeLocalDatabase();
  } catch (_) {}
  try {
    await DatabaseService().close();
    await deleteAppDatabase(DATABASE_NAME);
  } catch (_) {}
  try {
    // blocks قديمة يتيمة بتفضل في IndexedDB بعد حذف الملف — نمسحها فعليًا.
    await purgeBrowserDatabaseStorage();
  } catch (_) {}
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  } catch (_) {}
  reloadPage();
}
