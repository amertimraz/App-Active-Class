// lib/widgets/archive_event_tile.dart
//
// spec 047 — صف "تمت أرشفته / أُعيد من الأرشيف" بين سجلات الحضور. عرض فقط،
// بلون ورمز محايدين عشان مايتلخبطش مع حاضر/غائب/متأخر.
import 'package:flutter/material.dart';

import 'package:active_class/utils/archive_history.dart';

class ArchiveEventTile extends StatelessWidget {
  final ArchiveEvent event;
  final String? studentName;
  const ArchiveEventTile({super.key, required this.event, this.studentName});

  @override
  Widget build(BuildContext context) {
    const c = Color(0xFF64748B);
    final label = archiveEventLabel(event, DateTime.now());
    return ListTile(
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(
          event.isArchive ? Icons.archive_rounded : Icons.unarchive_rounded,
          color: c,
          size: 18,
        ),
      ),
      title: Text(label,
          style: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w600, color: c)),
      subtitle: studentName == null
          ? null
          : Text(studentName!, style: const TextStyle(fontSize: 11)),
    );
  }
}
