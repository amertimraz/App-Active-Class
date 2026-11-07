// lib/utils/send_queue.dart
//
// طابور الإرسال بنقرة: قايمة رسائل (تذكير دفع، غياب، تقرير…) لأولياء الأمور،
// والمدرس بيعدّي عليها واحدة واحدة — كل واحدة بتفتح واتساب برسالة جاهزة
// وبيدوس «إرسال» هناك. واتساب مابيسمحش بإرسال أوتوماتيك من غير خدمة مدفوعة،
// فالطابور بيشيل كل شغل التنقل والنسخ والبحث عن الاسم. منطق صرف بلا Get/DB.
import 'dart:typed_data';

import 'package:active_class/models/student_model.dart';

enum QueueStatus { pending, opened, skipped }

/// مرفق (بطاقة PDF مثلًا) بيتبعت بقايمة المشاركة بدل رابط wa.me.
class QueueAttachment {
  final String fileName;
  final Future<Uint8List> Function() bytes;
  const QueueAttachment({required this.fileName, required this.bytes});
}

class QueueItem {
  final int studentId;
  final String name;

  /// سطر توضيحي تحت الاسم (المبلغ المتبقي، المجموعة…).
  final String subtitle;
  final String message;
  final String? phone;
  final String? whatsapp;
  final QueueAttachment? attachment;
  QueueStatus status;

  QueueItem({
    required this.studentId,
    required this.name,
    required this.message,
    this.subtitle = '',
    this.phone,
    this.whatsapp,
    this.attachment,
    this.status = QueueStatus.pending,
  });

  bool get hasContact =>
      (phone ?? '').trim().isNotEmpty || (whatsapp ?? '').trim().isNotEmpty;

  /// المرفقات بتتبعت بقايمة المشاركة فمش محتاجة رقم؛ غير كده لازم رقم.
  bool get canSend => attachment != null || hasContact;

  factory QueueItem.forStudent(
    Student s, {
    required String message,
    String subtitle = '',
    QueueAttachment? attachment,
  }) =>
      QueueItem(
        studentId: s.id ?? -1,
        name: s.name,
        subtitle: subtitle,
        message: message,
        phone: s.guardianPhone,
        whatsapp: s.guardianWhatsapp,
        attachment: attachment,
      );
}

class SendQueue {
  final List<QueueItem> items;

  /// الفهرس الحالي في القايمة.
  int current;

  SendQueue(List<QueueItem> items, {this.current = 0})
      : items = List.unmodifiable(items) {
    // اللي مالهوش وجهة بيتخطّى لوحده من الأول.
    for (final i in this.items) {
      if (!i.canSend) i.status = QueueStatus.skipped;
    }
    current = _firstPendingFrom(0) ?? 0;
  }

  int get total => items.length;
  int get openedCount =>
      items.where((i) => i.status == QueueStatus.opened).length;
  int get skippedCount =>
      items.where((i) => i.status == QueueStatus.skipped).length;
  int get pendingCount =>
      items.where((i) => i.status == QueueStatus.pending).length;
  int get noContactCount => items.where((i) => !i.canSend).length;

  /// خلصنا لما مفيش ولا واحدة منتظرة.
  bool get isDone => pendingCount == 0;

  /// نسبة المُعالَج (مفتوح أو متخطّى) 0..1.
  double get progress =>
      total == 0 ? 1 : (openedCount + skippedCount) / total;

  QueueItem? get currentItem =>
      items.isEmpty || current >= items.length ? null : items[current];

  int? _firstPendingFrom(int start) {
    for (var i = start; i < items.length; i++) {
      if (items[i].status == QueueStatus.pending) return i;
    }
    return null;
  }

  /// أول واحدة منتظرة بعد [from] وإلا من البداية (لو في ما قبل).
  int? nextPending({int? from}) {
    final start = (from ?? current) + 1;
    return _firstPendingFrom(start) ?? _firstPendingFrom(0);
  }

  void markOpened(int index) {
    items[index].status = QueueStatus.opened;
  }

  void skip(int index) {
    items[index].status = QueueStatus.skipped;
  }

  /// يرجّع الواحدة لقايمة الانتظار (لو فتحها بالغلط أو عايز يبعتها تاني).
  void reset(int index) {
    if (items[index].canSend) items[index].status = QueueStatus.pending;
  }

  /// يتحرّك للتالية المنتظرة. true لو لقى.
  bool advance() {
    final n = nextPending();
    if (n == null) return false;
    current = n;
    return true;
  }

  void jumpTo(int index) {
    if (index >= 0 && index < items.length) current = index;
  }
}
