// lib/utils/session_guest.dart
//
// طالب "ضيف" في حصة مجموعة تانية (حصة تعويضية/بديلة): بيتسجّل له حضور اليوم
// عادي على سجله هو، ومعاه وسم في ملاحظة سجل الحضور بيقول إنه ضيف على أنهي
// مجموعة. الحضور في التطبيق بالطالب واليوم (مش بالمجموعة)، فمفيش حصة بتتضاف
// لمجموعته الأصلية، والوسم بيتزامن مع الفريق لأن الملاحظة جزء من الصف.
import 'package:active_class/models/attendance_model.dart';

const String kGuestNotePrefix = 'guest=';

/// ملاحظة سجل الحضور لضيف على المجموعة [groupId].
String guestNote(int groupId) => '$kGuestNotePrefix$groupId';

/// المجموعة اللي الطالب ضيف عليها في السجل ده، أو null لو مش ضيف.
int? guestGroupIdOf(Attendance a) {
  final n = (a.notes ?? '').trim();
  if (!n.startsWith(kGuestNotePrefix)) return null;
  return int.tryParse(n.substring(kGuestNotePrefix.length).split(';').first);
}

/// السجل ده ضيف على المجموعة [groupId] بالذات؟
bool isGuestOfGroup(Attendance a, int groupId) => guestGroupIdOf(a) == groupId;
