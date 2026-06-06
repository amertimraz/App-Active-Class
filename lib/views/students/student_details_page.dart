// lib/views/students/student_details_page.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:active_class/config/constants.dart';
import 'package:active_class/config/theme.dart';
import 'package:active_class/controllers/attendance_controller.dart';
import 'package:active_class/controllers/payment_controller.dart';
import 'package:active_class/models/payment_model.dart';
import 'package:active_class/models/student_model.dart';
import 'package:active_class/models/group_model.dart';
import 'package:active_class/widgets/custom_widgets.dart';
import 'package:active_class/utils/helpers.dart';
import 'package:active_class/services/database_service.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:active_class/controllers/settings_controller.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:media_store_plus/media_store_plus.dart';

class StudentDetailsPage extends StatefulWidget {
  const StudentDetailsPage({super.key});

  @override
  State<StudentDetailsPage> createState() => _StudentDetailsPageState();
}

class _StudentDetailsPageState extends State<StudentDetailsPage> {
  final AttendanceController attendanceController = Get.put(AttendanceController());
  final PaymentController paymentController = Get.put(PaymentController());
  Student? student;

  @override
  void initState() {
    super.initState();
    student = Get.arguments as Student?;
    if (attendanceController.attendance.isEmpty) attendanceController.loadAttendance();
    if (paymentController.payments.isEmpty) paymentController.loadPayments();
  }

  Future<void> _shareMonthlyReport(BuildContext context, Student student) async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final nextMonth = DateTime(now.year, now.month + 1, 1);
    final end = nextMonth.subtract(const Duration(days: 1));

    final atts = attendanceController.attendance
        .where((a) => a.studentId == (student.id ?? -1) && !a.date.isBefore(start) && !a.date.isAfter(DateTime(end.year, end.month, end.day, 23, 59, 59)))
        .toList();
    final pays = paymentController.payments
        .where((p) => p.studentId == (student.id ?? -1) && !p.date.isBefore(start) && !p.date.isAfter(DateTime(end.year, end.month, end.day, 23, 59, 59)))
        .toList();

    final present = atts.where((a) => a.status == ATTENDANCE_PRESENT).length;
    final absent = atts.where((a) => a.status == ATTENDANCE_ABSENT).length;
    final total = present + absent;
    final percent = total == 0 ? 0.0 : (present / total) * 100.0;
    final totalPaid = pays.fold<double>(0.0, (s, p) => s + p.amount);

    final monthLabel = DateFormat('MMMM yyyy', 'ar').format(start);

    final group = await DatabaseService().getGroup(student.groupId);
    final groupName = group?.name ?? '-';

    final attsSorted = List.of(atts)..sort((a, b) => b.date.compareTo(a.date));
    final paysSorted = List.of(pays)..sort((a, b) => b.date.compareTo(a.date));

    final buffer = StringBuffer()
      ..writeln('🧾 تقرير الشهر: $monthLabel')
      ..writeln('👤 الاسم: ${student.name}')
      ..writeln('🆔 الكود: ${student.code}')
      ..writeln('👥 المجموعة: $groupName')
      ..writeln('📅 بداية الحضور: ${FormatHelper.formatDate(student.attendanceStart ?? student.createdAt)}')
      ..writeln('')
      ..writeln('📊 الحضور: ✅ حاضر $present • ❌ غياب $absent • نسبة ${percent.toStringAsFixed(1)}%');

    if (attsSorted.isNotEmpty) {
      buffer.writeln('');
      buffer.writeln('📅 سجلات الحضور:');
      for (final a in attsSorted.take(10)) {
        final d = DateFormat('yyyy-MM-dd').format(a.date);
        final s = a.status == ATTENDANCE_PRESENT ? '✅ حاضر' : '❌ غياب';
        buffer.writeln('• $d — $s');
      }
      if (attsSorted.length > 10) buffer.writeln('• … ${attsSorted.length - 10} سجلات إضافية');
    }

    buffer
      ..writeln('')
      ..writeln('💰 المدفوعات: إجمالي ${FormatHelper.formatCurrency(totalPaid)}');

    if (paysSorted.isNotEmpty) {
      for (final p in paysSorted) {
        final d = DateFormat('yyyy-MM-dd').format(p.date);
        buffer.writeln('• $d — ${FormatHelper.formatCurrency(p.amount)}');
      }
    }

    buffer.writeln('');

    final rawPhone = student.guardianPhone?.trim() ?? '';
    if (rawPhone.isEmpty) {
      ToastHelper.info('أضف رقم ولي الأمر أولاً');
      return;
    }

    final settings = Get.find<SettingsController>();
    String normalize(String input, String defaultDial) {
      var p = input.replaceAll(RegExp(r'[^0-9+]'), '');
      if (p.startsWith('+')) p = p.substring(1);
      if (p.startsWith('00')) p = p.substring(2);
      if (p.startsWith(defaultDial)) return p;
      if (RegExp(r'^[1-9][0-9]{6,}$').hasMatch(p)) return p;
      p = p.replaceFirst(RegExp(r'^0+'), '');
      return defaultDial + p;
    }

    final tName = settings.teacherFullName.value.trim();
    final tSpec = settings.teacherSpecialization.value.trim();
    if (tName.isNotEmpty || tSpec.isNotEmpty) {
      buffer
        ..writeln('')
        ..writeln('👨‍🏫 المعلم: ${tName.isNotEmpty ? tName : '-'}')
        ..writeln('📘 التخصص: ${tSpec.isNotEmpty ? tSpec : '-'}');
    }
    buffer
      ..writeln('')
      ..writeln('تم الإرسال من تطبيق Active Class');

    final phone = normalize(rawPhone, settings.countryDial.value);
    final uri = Uri.parse('https://wa.me/$phone?text=${Uri.encodeComponent(buffer.toString())}');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final s = student;

    if (s == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('تفاصيل الطالب')),
        body: const Center(child: Text('لم يتم العثور على بيانات الطالب')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('تفاصيل الطالب'),
        centerTitle: true,
        elevation: 0,
      ),
      body: Obx(
        () {
          final studentAttendance = attendanceController.attendance
              .where((a) => a.studentId == s.id)
              .toList();
          final studentPayments = paymentController.payments
              .where((p) => p.studentId == s.id)
              .toList();

          final attendanceRate = studentAttendance.isEmpty
              ? 0.0
              : (studentAttendance
                      .where((a) => a.status == ATTENDANCE_PRESENT)
                      .length /
                  studentAttendance.length) *
              100;
          final totalPaid =
              studentPayments.fold<double>(0.0, (sum, payment) => sum + payment.amount);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(PADDING_NORMAL),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(PADDING_NORMAL),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: CircleAvatar(
                            radius: 40,
                            backgroundColor: AppTheme.primaryColor,
                            child: Text(
                              s.name[0].toUpperCase(),
                              style: const TextStyle(
                                fontSize: 28,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: SPACING_LARGE),
                        Text(s.name, style: Theme.of(context).textTheme.headlineSmall),
                        const SizedBox(height: SPACING_SMALL),
                        Text('الكود: ${s.code}', style: Theme.of(context).textTheme.bodyMedium),
                        const SizedBox(height: SPACING_SMALL),
                        FutureBuilder<Group?>(
                          future: DatabaseService().getGroup(s.groupId),
                          builder: (ctx, snap) => Text(
                            'المجموعة: ${snap.data?.name ?? '-'}',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                        const SizedBox(height: SPACING_SMALL),
                        Text('رقم ولي الأمر: ${s.guardianPhone ?? '-'}',
                            style: Theme.of(context).textTheme.bodyMedium),
                        const SizedBox(height: SPACING_SMALL),
                        Text('بداية الحضور: ${FormatHelper.formatDate(s.attendanceStart ?? s.createdAt)}',
                            style: Theme.of(context).textTheme.bodyMedium),
                        const SizedBox(height: SPACING_NORMAL),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Wrap(
                            spacing: 8,
                            children: [
                              ElevatedButton.icon(
                                onPressed: () => _showQRDialog(context, s),
                                icon: const Icon(Icons.qr_code),
                                label: const Text('عرض QR'),
                              ),
                              ElevatedButton.icon(
                                onPressed: () => _shareMonthlyReport(context, s),
                                icon: const Icon(Icons.share),
                                label: const Text('إرسال تقرير الشهر'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: SPACING_LARGE),
                Text(
                  'الإحصائيات',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: SPACING_NORMAL),
                GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: SPACING_NORMAL,
                  mainAxisSpacing: SPACING_NORMAL,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    StatsCard(
                      title: 'نسبة الحضور',
                      value: '${attendanceRate.toStringAsFixed(1)}%',
                      icon: Icons.check_circle,
                      color: Colors.green,
                    ),
                    StatsCard(
                      title: 'المبلغ المدفوع',
                      value: FormatHelper.formatCurrency(totalPaid),
                      icon: Icons.payment,
                      color: Colors.blue,
                    ),
                    StatsCard(
                      title: 'عدد الحضور',
                      value: '${studentAttendance.where((a) => a.status == ATTENDANCE_PRESENT).length}',
                      icon: Icons.people,
                      color: Colors.orange,
                    ),
                    StatsCard(
                      title: 'عدد الغياب',
                      value: '${studentAttendance.where((a) => a.status == ATTENDANCE_ABSENT).length}',
                      icon: Icons.person_off,
                      color: Colors.red,
                    ),
                  ],
                ),
                const SizedBox(height: SPACING_LARGE),
                Builder(
                  builder: (ctx) {
                    final atts = List.of(studentAttendance)
                      ..sort((a, b) => b.date.compareTo(a.date));
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'الحضور الأخير',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: SPACING_NORMAL),
                        if (atts.isEmpty)
                          const EmptyState(
                            icon: Icons.calendar_today,
                            title: 'لا توجد سجلات حضور',
                            subtitle: 'سيظهر هنا سجل الحضور عند الإضافة',
                          )
                        else
                          Card(
                            child: ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: atts.length,
                              separatorBuilder: (_, __) => const Divider(height: 0),
                              itemBuilder: (context, index) {
                                final a = atts[index];
                                return ListTile(
                                  leading: Icon(
                                    a.status == ATTENDANCE_PRESENT ? Icons.check_circle : Icons.cancel,
                                    color: a.status == ATTENDANCE_PRESENT ? Colors.green : Colors.red,
                                  ),
                                  title: Text(FormatHelper.formatFullDate(a.date)),
                                  trailing: Text(a.status),
                                );
                              },
                            ),
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: SPACING_LARGE),
                Builder(
                  builder: (ctx) {
                    final pays = List.of(studentPayments)
                      ..sort((a, b) => b.date.compareTo(a.date));
                    final Map<String, List<Payment>> byMonth = {};
                    for (final p in pays) {
                      final label = DateFormat('MMMM yyyy', 'ar').format(p.date);
                      (byMonth[label] ??= <Payment>[]).add(p);
                    }
                    final months = byMonth.keys.toList()
                      ..sort((a, b) {
                        final pa = byMonth[a]![0].date;
                        final pb = byMonth[b]![0].date;
                        return pb.compareTo(pa);
                      });
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'آخر المدفوعات',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: SPACING_NORMAL),
                        if (pays.isEmpty)
                          const EmptyState(
                            icon: Icons.payment,
                            title: 'لا توجد مدفوعات',
                            subtitle: 'سيظهر هنا سجل المدفوعات عند الإضافة',
                          )
                        else
                          Column(
                            children: months.map((m) {
                              final list = byMonth[m]!;
                              return Card(
                                margin: const EdgeInsets.only(bottom: SPACING_NORMAL),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 6),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: PADDING_NORMAL, vertical: 8),
                                        child: Text(m, style: Theme.of(context).textTheme.titleMedium),
                                      ),
                                      const Divider(height: 0),
                                      ListView.separated(
                                        shrinkWrap: true,
                                        physics: const NeverScrollableScrollPhysics(),
                                        itemCount: list.length,
                                        separatorBuilder: (_, __) => const Divider(height: 0),
                                        itemBuilder: (context, index) {
                                          final p = list[index];
                                          return ListTile(
                                            leading: const Icon(Icons.payment, color: Colors.green),
                                            title: Text(FormatHelper.formatDate(p.date)),
                                            trailing: Text(
                                              FormatHelper.formatCurrency(p.amount),
                                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                      ],
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showQRDialog(BuildContext context, Student student) {
    showDialog(
      context: context,
      builder: (ctx) {
        return FutureBuilder<Group?>(
          future: DatabaseService().getGroup(student.groupId),
          builder: (context, snapshot) {
            final groupName = snapshot.data?.name ?? '';
            return AlertDialog(
              title: const Text('QR Code'),
              content: SizedBox(
                width: 340,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(student.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    if (groupName.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text('المجموعة: $groupName'),
                    ],
                    const SizedBox(height: 12),
                    if (student.code.trim().isEmpty)
                      const Text('لا يوجد كود لعرضه', style: TextStyle(color: Colors.red))
                    else
                      QrImageView(
                        data: student.code,
                        version: QrVersions.auto,
                        size: 200,
                        backgroundColor: Colors.white,
                      ),
                    const SizedBox(height: 12),
                    Text('الكود: ${student.code}')
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('إغلاق'),
                ),
                ElevatedButton.icon(
                  onPressed: student.code.trim().isEmpty ? null : () async {
                    final ok = await _saveStudentQrImage(student);
                    if (!ctx.mounted) return;
                    if (ok) {
                      ToastHelper.success('تم حفظ صورة QR بنجاح');
                    } else {
                      ToastHelper.error('تعذر حفظ صورة QR');
                    }
                  },
                  icon: const Icon(Icons.download),
                  label: const Text('حفظ الصورة'),
                )
              ],
            );
          },
        );
      },
    );
  }

  Future<bool> _saveStudentQrImage(Student student) async {
    try {
      final group = await DatabaseService().getGroup(student.groupId);
      final groupName = group?.name;

      const int qrSize = 700;
      const double padding = 40;
      const double spacing = 24;

      final painter = QrPainter(
        data: student.code,
        version: QrVersions.auto,
        eyeStyle: const QrEyeStyle(color: Color(0xFF000000)),
        dataModuleStyle: const QrDataModuleStyle(color: Color(0xFF000000)),
      );
      final ui.Image qrImage = await painter.toImage(qrSize.toDouble());

      final textStyleTitle = const TextStyle(color: Colors.black, fontSize: 48, fontWeight: FontWeight.w600, fontFamily: 'Cairo');
      final textStyleSub = const TextStyle(color: Colors.black, fontSize: 36, fontFamily: 'Cairo');

      final tpName = TextPainter(
        text: TextSpan(text: student.name, style: textStyleTitle),
        textAlign: TextAlign.center,
        textDirection: ui.TextDirection.rtl,
      )..layout(maxWidth: qrSize.toDouble());

      final groupLine = groupName == null || groupName.isEmpty ? null : 'المجموعة: $groupName';
      final TextPainter? tpGroup = groupLine == null
          ? null
          : (TextPainter(
              text: TextSpan(text: groupLine, style: textStyleSub),
              textAlign: TextAlign.center,
              textDirection: ui.TextDirection.rtl,
            )..layout(maxWidth: qrSize.toDouble()));

      final codeLine = 'الكود: ${student.code}';
      final tpCode = TextPainter(
        text: TextSpan(text: codeLine, style: textStyleSub),
        textAlign: TextAlign.center,
        textDirection: ui.TextDirection.ltr,
      )..layout(maxWidth: qrSize.toDouble());

      final double textHeight = tpName.height + (tpGroup?.height ?? 0) + tpCode.height + spacing * 2;

      final int widthPx = (qrSize + padding * 2).round();
      final int heightPx = (padding + qrSize + spacing + textHeight + padding).round();

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final bg = Paint()..color = const Color(0xFFFFFFFF);
      canvas.drawRect(Rect.fromLTWH(0, 0, widthPx.toDouble(), heightPx.toDouble()), bg);

      final double qrLeft = (widthPx - qrSize) / 2;
      final double qrTop = padding;
      final srcRect = Rect.fromLTWH(0, 0, qrSize.toDouble(), qrSize.toDouble());
      final dstRect = Rect.fromLTWH(qrLeft, qrTop, qrSize.toDouble(), qrSize.toDouble());
      canvas.drawImageRect(qrImage, srcRect, dstRect, Paint());

      double cursorY = qrTop + qrSize + spacing;
      tpName.paint(canvas, Offset((widthPx - tpName.width) / 2, cursorY));
      cursorY += tpName.height + 8;
      if (tpGroup != null) {
        tpGroup.paint(canvas, Offset((widthPx - tpGroup.width) / 2, cursorY));
        cursorY += tpGroup.height + 8;
      }
      tpCode.paint(canvas, Offset((widthPx - tpCode.width) / 2, cursorY));

      final composed = await recorder.endRecording().toImage(widthPx, heightPx);
      final byteData = await composed.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return false;
      final bytes = byteData.buffer.asUint8List();

      await Permission.storage.request();
      await MediaStore.ensureInitialized();
      MediaStore.appFolder = "ActiveClass";

      final tmpDir = await getTemporaryDirectory();
      final tmpFile = File('${tmpDir.path}/student_qr_${student.code}.png');
      await tmpFile.writeAsBytes(bytes, flush: true);

      var saveInfo = await MediaStore().saveFile(
        tempFilePath: tmpFile.path,
        dirType: DirType.photo,
        dirName: DirType.photo.defaults,
      );

      if (saveInfo?.uri == null) {
        saveInfo = await MediaStore().saveFile(
          tempFilePath: tmpFile.path,
          dirType: DirType.download,
          dirName: DirType.download.defaults,
        );
      }

      final success = saveInfo?.uri != null;
      if (success && saveInfo?.uri != null) {
        try {
          final sUri = saveInfo?.uri;
          if (sUri != null) {
            final path = await MediaStore().getFilePathFromUri(uriString: sUri.toString());
            if (path != null && path.isNotEmpty) {
              await DatabaseService().updateStudent(student.copyWith(qrPath: path));
            }
          }
        } catch (_) {}
      }
      return success;
    } catch (_) {
      return false;
    }
  }
}
