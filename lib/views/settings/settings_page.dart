import 'dart:io';
import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';
import 'package:active_class/utils/whatsapp_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:active_class/config/constants.dart';
import 'package:active_class/utils/billing_period.dart';
import 'package:active_class/utils/monthly_report_message.dart';
import 'package:active_class/config/theme.dart';
import 'package:active_class/controllers/theme_controller.dart';
import 'package:active_class/controllers/settings_controller.dart';
import 'package:active_class/controllers/license_controller.dart';
import 'package:active_class/controllers/auth_controller.dart';
import 'package:active_class/controllers/student_controller.dart';
import 'package:active_class/controllers/group_controller.dart';
import 'package:active_class/controllers/exam_controller.dart';
import 'package:active_class/controllers/attendance_controller.dart';
import 'package:active_class/controllers/payment_controller.dart';
import 'package:active_class/controllers/homework_controller.dart';
import 'package:active_class/controllers/dashboard_controller.dart';
import 'package:active_class/views/settings/account_team_screen.dart';
import 'package:active_class/widgets/custom_dialogs.dart';
import 'package:active_class/widgets/progress_dialog.dart';
import 'package:active_class/utils/booklet_message.dart';
import 'package:active_class/utils/helpers.dart';
import 'package:active_class/services/database_service.dart';
import 'package:active_class/services/backup_service.dart';
import 'package:active_class/services/team_mode_service.dart';
import 'package:active_class/services/auth_service.dart';
import 'package:active_class/controllers/google_drive_backup_controller.dart';
import 'package:active_class/services/google_drive_backup_service.dart';
import 'package:active_class/services/parent_portal_service.dart';
import 'package:share_plus/share_plus.dart';
import 'package:active_class/services/auto_backup_service.dart';
import 'package:active_class/models/student_model.dart';
import 'package:active_class/views/license/trial_banner.dart';
import 'package:active_class/widgets/update_dialog.dart';
import 'package:active_class/widgets/hardware_reader_widgets.dart';
import 'package:active_class/views/settings/delete_records_page.dart';

import 'package:active_class/views/settings/settings_registry.dart';

// spec 051 — الشاشة الرئيسية للإعدادات = قائمة فئات. باقي الكود (ودجتس،
// أفعال، حوارات، صفحات الفئات) في ملفات part بنفس الـlibrary (نقل حرفي).
part 'widgets/settings_widgets.dart';
part 'widgets/settings_category_scaffold.dart';
part 'widgets/settings_home_body.dart';
part 'actions/backup_actions.dart';
part 'actions/whatsapp_batch_send.dart';
part 'dialogs/backup_dialogs.dart';
part 'dialogs/parent_portal_tile.dart';
part 'categories/account_team_category.dart';
part 'categories/attendance_category.dart';
part 'categories/billing_category.dart';
part 'categories/whatsapp_category.dart';
part 'categories/followup_category.dart';
part 'categories/appearance_category.dart';
part 'categories/data_category.dart';
part 'categories/about_category.dart';

/// الشاشة الرئيسية للإعدادات: كارت الترخيص + قائمة الفئات (spec 051).
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0B1020) : const Color(0xFFF7F8FF),
      body: Stack(
        children: [
          _SettingsBackdrop(isDark: isDark),
          SafeArea(
            child: Column(
              children: [
                _buildAppBar(context, isDark),
                Expanded(child: _SettingsHomeBody(isDark: isDark)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── AppBar (الرئيسية + صفحات الفئات) ───────────────────────────────────────

Widget _buildAppBar(BuildContext context, bool isDark,
    {String title = 'الإعدادات'}) {
  return Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
    child: Row(
      children: [
        _IconBtn(
          icon: Icons.arrow_back_ios_new_rounded,
          isDark: isDark,
          onTap: () => Get.back(),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : const Color(0xFF111827),
            ),
          ),
        ),
      ],
    ),
  );
}
