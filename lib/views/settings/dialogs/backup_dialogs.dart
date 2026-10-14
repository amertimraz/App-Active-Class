part of '../settings_page.dart';

// spec 051 — حوارات النسخ الاحتياطي (نقل حرفي)

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  const _InfoRow(this.icon, this.color, this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(label,
              style: const TextStyle(fontFamily: 'Cairo', fontSize: 13)),
        ),
      ]),
    );
  }
}

/// ملخص أعداد البيانات — بيُستخدم في حوارات نجاح النسخ الاحتياطي والحذف
class _DataSummaryList extends StatelessWidget {
  final DataSummary summary;
  const _DataSummaryList({required this.summary});

  @override
  Widget build(BuildContext context) {
    final rows = <(IconData, String)>[
      (Icons.groups_rounded, '${summary.groups} مجموعة'),
      (Icons.person_rounded, '${summary.students} طالب'),
      (Icons.how_to_reg_rounded, '${summary.attendanceRecords} سجل حضور'),
      (Icons.payments_rounded, '${summary.payments} دفعة'),
      (Icons.assignment_rounded, '${summary.exams} امتحان'),
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children:
          rows.map((r) => _InfoRow(r.$1, AppTheme.primaryColor, r.$2)).toList(),
    );
  }
}

/// زر اختيار كبير
class _ChoiceButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _ChoiceButton({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontFamily: 'Cairo', fontWeight: FontWeight.w700)),
                  Text(subtitle,
                      style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 11,
                          color: Colors.grey[600])),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, size: 14, color: color),
          ]),
        ),
      ),
    );
  }
}

/// ديالوج اختيار نسخة للاستعادة
class _BackupListDialog extends StatelessWidget {
  final List<BackupInfo> backups;
  final BackupService svc;
  const _BackupListDialog({required this.backups, required this.svc});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text('النسخ المحفوظة (${backups.length})',
          style: const TextStyle(
              fontFamily: 'Cairo', fontWeight: FontWeight.w800)),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: ListView.separated(
          itemCount: backups.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final b = backups[i];
            final isLatest = i == 0;
            return ListTile(
              leading: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isLatest
                          ? const Color(0xFFF59E0B).withValues(alpha: 0.15)
                          : AppTheme.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.backup_rounded,
                        color: isLatest
                            ? const Color(0xFFF59E0B)
                            : AppTheme.primaryColor,
                        size: 20),
                  ),
                  if (isLatest)
                    Positioned(
                      top: -4,
                      left: -4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('أحدث',
                            style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 8,
                                fontWeight: FontWeight.w800,
                                color: Colors.white)),
                      ),
                    ),
                ],
              ),
              title: Text(b.dateLabel,
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: isLatest ? const Color(0xFFF59E0B) : null)),
              subtitle: Text(b.sizeLabel,
                  style: const TextStyle(fontFamily: 'Cairo', fontSize: 11)),
              onTap: () => Navigator.of(context).pop(b.path),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo')),
        ),
      ],
    );
  }
}

/// ديالوج إدارة النسخ الاحتياطية
class _ManageBackupsDialog extends StatefulWidget {
  final List<BackupInfo> backups;
  final BackupService svc;
  final VoidCallback onChanged;
  const _ManageBackupsDialog(
      {required this.backups, required this.svc, required this.onChanged});

  @override
  State<_ManageBackupsDialog> createState() => _ManageBackupsDialogState();
}

class _ManageBackupsDialogState extends State<_ManageBackupsDialog> {
  late List<BackupInfo> _backups;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    _backups = List.from(widget.backups);
  }

  void _confirmDeleteOne(BackupInfo b) {
    ConfirmDeleteDialog.show(
      context,
      title: 'حذف النسخة الاحتياطية',
      message:
          'هل تريد حذف هذه النسخة الاحتياطية نهائياً؟ لا يمكن التراجع عن هذا الإجراء.',
      onConfirm: () => _deleteOne(b),
    );
  }

  Future<void> _deleteOne(BackupInfo b) async {
    setState(() => _deleting = true);
    await widget.svc.deleteBackup(b.path);
    if (!mounted) return;
    setState(() {
      _backups.remove(b);
      _deleting = false;
    });
    if (_backups.isEmpty && mounted) Navigator.of(context).pop();
  }

  void _confirmCleanOld() {
    ConfirmDeleteDialog.show(
      context,
      title: 'حذف النسخ القديمة',
      message:
          'سيتم حذف ${_backups.length - 5} نسخة احتياطية قديمة نهائياً والاحتفاظ بأحدث 5 فقط. لا يمكن التراجع عن هذا الإجراء.',
      onConfirm: _cleanOld,
    );
  }

  Future<void> _cleanOld() async {
    setState(() => _deleting = true);
    final deleted = await widget.svc.cleanOldBackups(keepCount: 5);
    if (!mounted) return;
    setState(() => _deleting = false);
    Navigator.of(context).pop();
    ToastHelper.success('تم حذف $deleted نسخة قديمة — تم الاحتفاظ بأحدث 5');
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text('النسخ الاحتياطية (${_backups.length})',
          style: const TextStyle(
              fontFamily: 'Cairo', fontWeight: FontWeight.w800)),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: Column(
          children: [
            // زر "احتفظ بأحدث 5"
            if (_backups.length > 5)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _deleting ? null : _confirmCleanOld,
                    icon: const Icon(Icons.cleaning_services_rounded, size: 16),
                    label: Text(
                        'احتفظ بأحدث 5 فقط (احذف ${_backups.length - 5})',
                        style:
                            const TextStyle(fontFamily: 'Cairo', fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ),
            // القائمة
            Expanded(
              child: ListView.separated(
                itemCount: _backups.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final b = _backups[i];
                  final isLatest = i == 0;
                  return ListTile(
                    dense: true,
                    leading: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Icon(Icons.backup_rounded,
                            color: isLatest
                                ? const Color(0xFFF59E0B)
                                : AppTheme.primaryColor,
                            size: 20),
                        if (isLatest)
                          Positioned(
                            top: -6,
                            left: -6,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 3, vertical: 1),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF59E0B),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: const Text('★',
                                  style: TextStyle(
                                      fontSize: 7,
                                      color: Colors.white,
                                      height: 1)),
                            ),
                          ),
                      ],
                    ),
                    title: Text(b.dateLabel,
                        style: TextStyle(
                            fontFamily: 'Cairo',
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            color: isLatest ? const Color(0xFFF59E0B) : null)),
                    subtitle: Text(b.sizeLabel,
                        style:
                            const TextStyle(fontFamily: 'Cairo', fontSize: 11)),
                    trailing: i == 0
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF59E0B)
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text('أحدث',
                                    style: TextStyle(
                                        fontFamily: 'Cairo',
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFFF59E0B))),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded,
                                    color: Colors.red, size: 20),
                                onPressed: _deleting
                                    ? null
                                    : () => _confirmDeleteOne(b),
                                tooltip: 'حذف هذه النسخة',
                              ),
                            ],
                          )
                        : IconButton(
                            icon: const Icon(Icons.delete_outline_rounded,
                                color: Colors.red, size: 20),
                            onPressed:
                                _deleting ? null : () => _confirmDeleteOne(b),
                            tooltip: 'حذف هذه النسخة',
                          ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('إغلاق', style: TextStyle(fontFamily: 'Cairo')),
        ),
      ],
    );
  }
}
