// lib/views/bookings/booking_settings_page.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';

import 'package:active_class/controllers/booking_controller.dart';
import 'package:active_class/controllers/license_controller.dart';
import 'package:active_class/controllers/settings_controller.dart';
import 'package:active_class/widgets/app_toast.dart';

const _kPrimary = Color(0xFF4F46E5);
const _kAccent = Color(0xFF0EA5E9);

class BookingSettingsPage extends StatefulWidget {
  const BookingSettingsPage({super.key});

  @override
  State<BookingSettingsPage> createState() => _BookingSettingsPageState();
}

class _BookingSettingsPageState extends State<BookingSettingsPage> {
  late final TextEditingController _bioCtrl;
  bool _bioInitialized = false;

  @override
  void initState() {
    super.initState();
    _bioCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _bioCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final BookingController booking = Get.put(BookingController());
    final SettingsController settings = Get.find();
    final LicenseController license = Get.find();

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0B1020) : const Color(0xFFF7F8FF),
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? const [Color(0xFF08101F), Color(0xFF121A2D)]
                      : const [Color(0xFFFDFDFF), Color(0xFFEEF4FF)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
          _glow(
            top: -100,
            left: -70,
            size: 230,
            colors: isDark
                ? const [Color(0x330EA5E9), Color(0x000EA5E9)]
                : const [Color(0x55BAE6FD), Color(0x00BAE6FD)],
          ),
          _glow(
            bottom: 40,
            right: -90,
            size: 240,
            colors: isDark
                ? const [Color(0x334F46E5), Color(0x004F46E5)]
                : const [Color(0x55C7D2FE), Color(0x00C7D2FE)],
          ),
          SafeArea(
            child: Column(
              children: [
                _buildAppBar(context, isDark),
                Expanded(
                  child: Obx(() {
                    if (booking.loading.value) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (!_bioInitialized) {
                      _bioInitialized = true;
                      _bioCtrl.text = booking.bio.value;
                    }
                    return ListView(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      children: [
                        if (booking.syncError.value) ...[
                          _card(
                            isDark,
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.sync_problem_rounded,
                                          color: Color(0xFFEF4444)),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text('رابط الحجز الحالي معطّل',
                                            style: TextStyle(
                                                fontFamily: 'Cairo',
                                                fontWeight: FontWeight.w800,
                                                fontSize: 14.5,
                                                color: isDark
                                                    ? Colors.white
                                                    : const Color(0xFF111827))),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'مش هينفع تعدّل أي إعداد تاني هنا لحد ما تولّد رابط جديد — أي تعديل على الرابط القديم هيفشل. باقي الإعدادات اتعطّلت مؤقتًا تحت.',
                                    style: TextStyle(
                                        fontFamily: 'Cairo',
                                        fontSize: 12.5,
                                        color: isDark
                                            ? Colors.white70
                                            : Colors.grey[700]),
                                  ),
                                  const SizedBox(height: 12),
                                  ElevatedButton.icon(
                                    onPressed: () => _confirmRegenerateLink(
                                        context, booking),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _kPrimary,
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12)),
                                    ),
                                    icon: const Icon(Icons.refresh_rounded,
                                        size: 18),
                                    label: const Text('توليد رابط حجز جديد',
                                        style: TextStyle(fontFamily: 'Cairo')),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        IgnorePointer(
                          ignoring: booking.syncError.value,
                          child: Opacity(
                            opacity: booking.syncError.value ? 0.45 : 1,
                            child: Column(
                              children: [
                                if (!license.canBooking)
                                  _card(
                                    isDark,
                                    child: const Padding(
                                      padding: EdgeInsets.all(16),
                                      child: Text(
                                        'ميزة رابط الحجز متاحة للباقة الاحترافية أو مدى الحياة فقط.',
                                        style: TextStyle(fontFamily: 'Cairo'),
                                      ),
                                    ),
                                  ),
                                _card(
                                  isDark,
                                  child: SwitchListTile(
                                    title: const Text('تفعيل رابط الحجز',
                                        style: TextStyle(
                                            fontFamily: 'Cairo',
                                            fontWeight: FontWeight.w700)),
                                    subtitle: const Text(
                                      'لما يتفعّل، ولي الأمر أو الطالب يقدر يسجّل بياناته من الرابط العام',
                                      style: TextStyle(
                                          fontFamily: 'Cairo', fontSize: 12),
                                    ),
                                    activeColor: _kPrimary,
                                    value: booking.enabled.value,
                                    onChanged: (v) async {
                                      final err = await booking.setEnabled(
                                        v,
                                        teacherName: settings
                                                .teacherFullName.value.isEmpty
                                            ? 'المعلم'
                                            : settings.teacherFullName.value,
                                        subject: settings
                                            .teacherSpecialization.value,
                                        title: settings.teacherTitle,
                                        photoLocalPath:
                                            settings.teacherAvatarPath.value,
                                      );
                                      if (!context.mounted) return;
                                      if (err != null) {
                                        AppToast.error(context, err);
                                      } else {
                                        AppToast.success(
                                            context,
                                            v
                                                ? 'تم تفعيل رابط الحجز'
                                                : 'تم إيقاف رابط الحجز');
                                      }
                                    },
                                  ),
                                ),
                                if (booking.enabled.value &&
                                    booking.bookingUrl.isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  _card(
                                    isDark,
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          _sectionTitle(isDark,
                                              icon: Icons.link_rounded,
                                              color: _kAccent,
                                              text: 'رابط الحجز الخاص بك'),
                                          const SizedBox(height: 10),
                                          Container(
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              color: isDark
                                                  ? Colors.white
                                                      .withValues(alpha: 0.04)
                                                  : const Color(0xFFF3F4F8),
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            width: double.infinity,
                                            child: SelectableText(
                                                booking.bookingUrl,
                                                style: TextStyle(
                                                    fontFamily: 'Cairo',
                                                    fontSize: 13,
                                                    color: isDark
                                                        ? Colors.white70
                                                        : const Color(
                                                            0xFF374151))),
                                          ),
                                          const SizedBox(height: 12),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: OutlinedButton.icon(
                                                  onPressed: () async {
                                                    await Clipboard.setData(
                                                        ClipboardData(
                                                            text: booking
                                                                .bookingUrl));
                                                    if (context.mounted) {
                                                      AppToast.success(context,
                                                          'تم نسخ الرابط');
                                                    }
                                                  },
                                                  style:
                                                      OutlinedButton.styleFrom(
                                                    shape:
                                                        RoundedRectangleBorder(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        12)),
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        vertical: 11),
                                                  ),
                                                  icon: const Icon(
                                                      Icons.copy_rounded,
                                                      size: 18),
                                                  label: const Text('نسخ',
                                                      style: TextStyle(
                                                          fontFamily: 'Cairo')),
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: ElevatedButton.icon(
                                                  onPressed: () => Share.share(
                                                      booking.bookingUrl),
                                                  style:
                                                      ElevatedButton.styleFrom(
                                                    backgroundColor: _kPrimary,
                                                    foregroundColor:
                                                        Colors.white,
                                                    elevation: 0,
                                                    shape:
                                                        RoundedRectangleBorder(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        12)),
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        vertical: 11),
                                                  ),
                                                  icon: const Icon(
                                                      Icons.share_rounded,
                                                      size: 18),
                                                  label: const Text('مشاركة',
                                                      style: TextStyle(
                                                          fontFamily: 'Cairo')),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                                if (booking.enabled.value) ...[
                                  const SizedBox(height: 12),
                                  _card(
                                    isDark,
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          _sectionTitle(isDark,
                                              icon: Icons.image_rounded,
                                              color: const Color(0xFF0EA5E9),
                                              text: 'صورة خلفية صفحة الحجز'),
                                          const SizedBox(height: 4),
                                          Text(
                                            'اختياري — لو رفعتها هتظهر خلف صورتك في صفحة الحجز، لو مرفعتهاش هيفضل التصميم الافتراضي',
                                            style: TextStyle(
                                                fontFamily: 'Cairo',
                                                fontSize: 12,
                                                color: isDark
                                                    ? Colors.white54
                                                    : Colors.grey[600]),
                                          ),
                                          const SizedBox(height: 12),
                                          if (booking.coverUrl.value.isNotEmpty)
                                            ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              child: Image.network(
                                                booking.coverUrl.value,
                                                height: 100,
                                                width: double.infinity,
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, __, ___) =>
                                                    const SizedBox.shrink(),
                                              ),
                                            ),
                                          if (booking.coverUrl.value.isNotEmpty)
                                            const SizedBox(height: 12),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: OutlinedButton.icon(
                                                  onPressed: booking
                                                          .uploadingCover.value
                                                      ? null
                                                      : () async {
                                                          final picker =
                                                              ImagePicker();
                                                          final x = await picker
                                                              .pickImage(
                                                                  source:
                                                                      ImageSource
                                                                          .gallery,
                                                                  imageQuality:
                                                                      85);
                                                          if (x == null) return;
                                                          final err =
                                                              await booking
                                                                  .uploadCover(
                                                                      File(x
                                                                          .path));
                                                          if (!context.mounted)
                                                            return;
                                                          if (err != null) {
                                                            AppToast.error(
                                                                context, err);
                                                          } else {
                                                            AppToast.success(
                                                                context,
                                                                'تم رفع صورة الخلفية');
                                                          }
                                                        },
                                                  style:
                                                      OutlinedButton.styleFrom(
                                                    shape:
                                                        RoundedRectangleBorder(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        12)),
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        vertical: 11),
                                                  ),
                                                  icon: booking
                                                          .uploadingCover.value
                                                      ? const SizedBox(
                                                          width: 16,
                                                          height: 16,
                                                          child:
                                                              CircularProgressIndicator(
                                                                  strokeWidth:
                                                                      2))
                                                      : const Icon(
                                                          Icons.image_rounded,
                                                          size: 18),
                                                  label: Text(
                                                      booking.coverUrl.value
                                                              .isEmpty
                                                          ? 'رفع صورة'
                                                          : 'تغيير الصورة',
                                                      style: const TextStyle(
                                                          fontFamily: 'Cairo')),
                                                ),
                                              ),
                                              if (booking.coverUrl.value
                                                  .isNotEmpty) ...[
                                                const SizedBox(width: 10),
                                                OutlinedButton(
                                                  onPressed: () async {
                                                    await booking.removeCover();
                                                    if (context.mounted) {
                                                      AppToast.info(context,
                                                          'تم حذف صورة الخلفية');
                                                    }
                                                  },
                                                  style:
                                                      OutlinedButton.styleFrom(
                                                    foregroundColor: Colors.red,
                                                    shape:
                                                        RoundedRectangleBorder(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        12)),
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        vertical: 11,
                                                        horizontal: 14),
                                                  ),
                                                  child: const Icon(
                                                      Icons
                                                          .delete_outline_rounded,
                                                      size: 18),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                                if (booking.enabled.value) ...[
                                  const SizedBox(height: 12),
                                  _card(
                                    isDark,
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          _sectionTitle(isDark,
                                              icon: Icons.person_rounded,
                                              color: const Color(0xFF8B5CF6),
                                              text:
                                                  'نبذة عنك (سيرة ذاتية مختصرة)'),
                                          const SizedBox(height: 4),
                                          Text(
                                            'اختياري — لو كتبتها هتظهر في صفحة الحجز، لو سبتها فاضية القسم ده مش هيظهر خالص',
                                            style: TextStyle(
                                                fontFamily: 'Cairo',
                                                fontSize: 12,
                                                color: isDark
                                                    ? Colors.white54
                                                    : Colors.grey[600]),
                                          ),
                                          const SizedBox(height: 12),
                                          TextField(
                                            controller: _bioCtrl,
                                            maxLines: 4,
                                            maxLength: 500,
                                            style: TextStyle(
                                                fontFamily: 'Cairo',
                                                fontSize: 13,
                                                color: isDark
                                                    ? Colors.white
                                                    : Colors.black87),
                                            decoration: InputDecoration(
                                              hintText:
                                                  'مثال: مدرس رياضيات بخبرة 10 سنوات، متخصص في مناهج الثانوية العامة...',
                                              hintStyle: const TextStyle(
                                                  fontFamily: 'Cairo',
                                                  fontSize: 12),
                                              filled: true,
                                              fillColor: isDark
                                                  ? Colors.white
                                                      .withValues(alpha: 0.04)
                                                  : const Color(0xFFF3F4F8),
                                              border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                borderSide: BorderSide.none,
                                              ),
                                            ),
                                          ),
                                          Align(
                                            alignment: Alignment.centerLeft,
                                            child: ElevatedButton.icon(
                                              onPressed: booking.savingBio.value
                                                  ? null
                                                  : () async {
                                                      await booking.saveBio(
                                                          _bioCtrl.text.trim());
                                                      if (context.mounted) {
                                                        AppToast.success(
                                                            context,
                                                            'تم حفظ النبذة');
                                                      }
                                                    },
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: _kPrimary,
                                                foregroundColor: Colors.white,
                                                elevation: 0,
                                                shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12)),
                                              ),
                                              icon: booking.savingBio.value
                                                  ? const SizedBox(
                                                      width: 16,
                                                      height: 16,
                                                      child:
                                                          CircularProgressIndicator(
                                                              strokeWidth: 2,
                                                              color:
                                                                  Colors.white))
                                                  : const Icon(
                                                      Icons.save_rounded,
                                                      size: 18),
                                              label: const Text('حفظ',
                                                  style: TextStyle(
                                                      fontFamily: 'Cairo')),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                                if (booking.enabled.value) ...[
                                  const SizedBox(height: 12),
                                  _card(
                                    isDark,
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          _sectionTitle(isDark,
                                              icon: Icons.playlist_add_rounded,
                                              color: const Color(0xFF16A34A),
                                              text: 'حقول مخصصة'),
                                          const SizedBox(height: 4),
                                          Text(
                                            'ضيف أي حقل عايزه إنت في فورم الحجز (حد أقصى ${BookingController.maxCustomFields})',
                                            style: TextStyle(
                                                fontFamily: 'Cairo',
                                                fontSize: 12,
                                                color: isDark
                                                    ? Colors.white54
                                                    : Colors.grey[600]),
                                          ),
                                          const SizedBox(height: 12),
                                          ...booking.customFields
                                              .map((f) => Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                            bottom: 8),
                                                    child: Row(
                                                      children: [
                                                        Expanded(
                                                          child: Text(
                                                              f['label']
                                                                      as String? ??
                                                                  '',
                                                              style: TextStyle(
                                                                  fontFamily:
                                                                      'Cairo',
                                                                  fontSize:
                                                                      13.5,
                                                                  color: isDark
                                                                      ? Colors
                                                                          .white
                                                                      : const Color(
                                                                          0xFF111827))),
                                                        ),
                                                        Row(
                                                          children: [
                                                            Text('إجباري',
                                                                style: TextStyle(
                                                                    fontFamily:
                                                                        'Cairo',
                                                                    fontSize:
                                                                        10,
                                                                    color: isDark
                                                                        ? Colors
                                                                            .white54
                                                                        : Colors
                                                                            .grey[600])),
                                                            Switch(
                                                              value: f['required']
                                                                      as bool? ??
                                                                  false,
                                                              activeColor:
                                                                  _kPrimary,
                                                              onChanged: (v) => booking.toggleCustomFieldRequired(
                                                                  f['key']
                                                                      as String,
                                                                  v,
                                                                  teacherName:
                                                                      settings
                                                                          .teacherFullName
                                                                          .value,
                                                                  subject: settings
                                                                      .teacherSpecialization
                                                                      .value,
                                                                  title: settings
                                                                      .teacherTitle),
                                                            ),
                                                          ],
                                                        ),
                                                        IconButton(
                                                          icon: const Icon(
                                                              Icons
                                                                  .delete_outline_rounded,
                                                              size: 20,
                                                              color:
                                                                  Colors.red),
                                                          onPressed: () => booking.removeCustomField(
                                                              f['key']
                                                                  as String,
                                                              teacherName: settings
                                                                  .teacherFullName
                                                                  .value,
                                                              subject: settings
                                                                  .teacherSpecialization
                                                                  .value,
                                                              title: settings
                                                                  .teacherTitle),
                                                        ),
                                                      ],
                                                    ),
                                                  )),
                                          if (booking.customFields.length <
                                              BookingController.maxCustomFields)
                                            Align(
                                              alignment: Alignment.centerLeft,
                                              child: OutlinedButton.icon(
                                                onPressed: () =>
                                                    _showAddCustomFieldDialog(
                                                        context,
                                                        booking,
                                                        settings),
                                                style: OutlinedButton.styleFrom(
                                                  shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              12)),
                                                ),
                                                icon: const Icon(
                                                    Icons.add_rounded,
                                                    size: 18),
                                                label: const Text('إضافة حقل',
                                                    style: TextStyle(
                                                        fontFamily: 'Cairo')),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 12),
                                _card(
                                  isDark,
                                  child: Column(
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                            16, 14, 16, 4),
                                        child: Align(
                                          alignment: Alignment.centerRight,
                                          child: _sectionTitle(isDark,
                                              icon: Icons.tune_rounded,
                                              color: const Color(0xFFF59E0B),
                                              text:
                                                  'الحقول اللي تظهر في فورم الحجز'),
                                        ),
                                      ),
                                      _fieldRow(
                                        context,
                                        isDark: isDark,
                                        title: 'المرحلة الدراسية',
                                        show: booking.showGrade,
                                        required: booking.requireGrade,
                                        onShow: (v) => booking.updateField(
                                            'grade',
                                            show: v,
                                            teacherName:
                                                settings.teacherFullName.value,
                                            subject: settings
                                                .teacherSpecialization.value,
                                            title: settings.teacherTitle),
                                        onRequired: (v) => booking.updateField(
                                            'grade',
                                            required: v,
                                            teacherName:
                                                settings.teacherFullName.value,
                                            subject: settings
                                                .teacherSpecialization.value,
                                            title: settings.teacherTitle),
                                      ),
                                      _fieldRow(
                                        context,
                                        isDark: isDark,
                                        title: 'الصف / الفصل',
                                        show: booking.showClass,
                                        required: booking.requireClass,
                                        onShow: (v) => booking.updateField(
                                            'classSection',
                                            show: v,
                                            teacherName:
                                                settings.teacherFullName.value,
                                            subject: settings
                                                .teacherSpecialization.value,
                                            title: settings.teacherTitle),
                                        onRequired: (v) => booking.updateField(
                                            'classSection',
                                            required: v,
                                            teacherName:
                                                settings.teacherFullName.value,
                                            subject: settings
                                                .teacherSpecialization.value,
                                            title: settings.teacherTitle),
                                      ),
                                      _fieldRow(
                                        context,
                                        isDark: isDark,
                                        title: 'الوقت المفضل',
                                        show: booking.showTime,
                                        required: booking.requireTime,
                                        onShow: (v) => booking.updateField(
                                            'preferredTime',
                                            show: v,
                                            teacherName:
                                                settings.teacherFullName.value,
                                            subject: settings
                                                .teacherSpecialization.value,
                                            title: settings.teacherTitle),
                                        onRequired: (v) => booking.updateField(
                                            'preferredTime',
                                            required: v,
                                            teacherName:
                                                settings.teacherFullName.value,
                                            subject: settings
                                                .teacherSpecialization.value,
                                            title: settings.teacherTitle),
                                      ),
                                      _fieldRow(
                                        context,
                                        isDark: isDark,
                                        title: 'ملاحظات',
                                        show: booking.showNotes,
                                        required: booking.requireNotes,
                                        onShow: (v) => booking.updateField(
                                            'notes',
                                            show: v,
                                            teacherName:
                                                settings.teacherFullName.value,
                                            subject: settings
                                                .teacherSpecialization.value,
                                            title: settings.teacherTitle),
                                        onRequired: (v) => booking.updateField(
                                            'notes',
                                            required: v,
                                            teacherName:
                                                settings.teacherFullName.value,
                                            subject: settings
                                                .teacherSpecialization.value,
                                            title: settings.teacherTitle),
                                      ),
                                      const SizedBox(height: 8),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  }),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmRegenerateLink(
      BuildContext context, BookingController booking) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('توليد رابط حجز جديد؟',
            style: TextStyle(fontFamily: 'Cairo')),
        content: const Text(
          'الرابط القديم هيوقف عن العمل نهائيًا وأي طلبات حجز وصلت عليه هتضيع. '
          'المفروض تشارك الرابط الجديد بدل القديم مع طلابك.',
          style: TextStyle(fontFamily: 'Cairo'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: _kPrimary, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('توليد رابط جديد',
                style: TextStyle(fontFamily: 'Cairo')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final err = await booking.regenerateLink();
    if (!context.mounted) return;
    if (err != null) {
      AppToast.error(context, err);
    } else {
      AppToast.success(context, 'تم توليد رابط حجز جديد');
    }
  }

  Widget _buildAppBar(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
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
              'إعدادات الحجوزات',
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

  Widget _sectionTitle(bool isDark,
      {required IconData icon, required Color color, required String text}) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text,
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.w700,
                  fontSize: 14.5,
                  color: isDark ? Colors.white : const Color(0xFF111827))),
        ),
      ],
    );
  }

  Widget _card(bool isDark, {required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141B2E) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _fieldRow(
    BuildContext context, {
    required bool isDark,
    required String title,
    required RxBool show,
    required RxBool required,
    required ValueChanged<bool> onShow,
    required ValueChanged<bool> onRequired,
  }) {
    return Obx(() => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              Expanded(
                child: Text(title,
                    style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 14,
                        color:
                            isDark ? Colors.white70 : const Color(0xFF374151))),
              ),
              Column(
                children: [
                  Text('إجباري',
                      style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 10,
                          color: isDark ? Colors.white54 : Colors.grey[600])),
                  Switch(
                    value: required.value,
                    activeColor: _kPrimary,
                    onChanged: show.value ? onRequired : null,
                  ),
                ],
              ),
              const SizedBox(width: 6),
              Column(
                children: [
                  Text('إظهار',
                      style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 10,
                          color: isDark ? Colors.white54 : Colors.grey[600])),
                  Switch(
                    value: show.value,
                    activeColor: _kPrimary,
                    onChanged: (v) {
                      onShow(v);
                      if (!v && required.value) onRequired(false);
                    },
                  ),
                ],
              ),
            ],
          ),
        ));
  }

  Future<void> _showAddCustomFieldDialog(
    BuildContext context,
    BookingController booking,
    SettingsController settings,
  ) async {
    final labelCtrl = TextEditingController();
    final isRequired = ValueNotifier<bool>(false);

    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title:
            const Text('إضافة حقل جديد', style: TextStyle(fontFamily: 'Cairo')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: labelCtrl,
              autofocus: true,
              maxLength: 60,
              style: const TextStyle(fontFamily: 'Cairo'),
              decoration: const InputDecoration(
                hintText: 'مثال: عدد الحصص المطلوبة',
                hintStyle: TextStyle(fontFamily: 'Cairo', fontSize: 13),
                border: OutlineInputBorder(),
              ),
            ),
            ValueListenableBuilder<bool>(
              valueListenable: isRequired,
              builder: (_, value, __) => CheckboxListTile(
                value: value,
                onChanged: (v) => isRequired.value = v ?? false,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text('حقل إجباري',
                    style: TextStyle(fontFamily: 'Cairo', fontSize: 13)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: _kPrimary, foregroundColor: Colors.white),
            onPressed: () async {
              final err = await booking.addCustomField(
                labelCtrl.text,
                required: isRequired.value,
                teacherName: settings.teacherFullName.value,
                subject: settings.teacherSpecialization.value,
                title: settings.teacherTitle,
              );
              if (!dialogContext.mounted) return;
              Navigator.pop(dialogContext);
              if (!context.mounted) return;
              if (err != null) {
                AppToast.error(context, err);
              } else {
                AppToast.success(context, 'تم إضافة الحقل');
              }
            },
            child: const Text('إضافة', style: TextStyle(fontFamily: 'Cairo')),
          ),
        ],
      ),
    );
  }
}

Widget _glow({
  double? top,
  double? right,
  double? bottom,
  double? left,
  required double size,
  required List<Color> colors,
}) {
  return Positioned(
    top: top,
    right: right,
    bottom: bottom,
    left: left,
    child: IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: colors),
        ),
      ),
    ),
  );
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final bool isDark;
  final VoidCallback onTap;

  const _IconBtn(
      {required this.icon, required this.isDark, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF131D31).withValues(alpha: 0.94)
              : Colors.white.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.white.withValues(alpha: 0.9),
          ),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.16)
                  : const Color(0xFFD9E1F2).withValues(alpha: 0.5),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(icon,
            size: 18, color: isDark ? Colors.white : const Color(0xFF111827)),
      ),
    );
  }
}
