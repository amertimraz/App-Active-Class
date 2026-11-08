// lib/views/team/team_sync_widgets.dart
//
// سحابة المزامنة (جوّه شاشة وضع الفريق) وقايمة «حالة أجهزة الفريق» للمدرّس.
// الـwidgets الأساسية (SyncCloudView / DeviceStatusTile) بتاخد بيانات جاهزة
// عشان تتختبر؛ والـStateful فوقها بتسحب الأرقام كل كام ثانية.
import 'dart:async';

import 'package:flutter/material.dart';

import 'package:active_class/services/team_mode_service.dart';
import 'package:active_class/utils/device_sync_status.dart';
import 'package:active_class/utils/helpers.dart' show ToastHelper;

Color syncHealthColor(SyncHealth h, bool isDark) => switch (h) {
      SyncHealth.ok => const Color(0xFF10B981),
      SyncHealth.pending => isDark ? const Color(0xFFF5B14C) : const Color(0xFFB45309),
      SyncHealth.stuck => isDark ? const Color(0xFFFF8A8A) : const Color(0xFFC9252D),
      SyncHealth.stale => isDark ? Colors.white54 : Colors.black45,
    };

IconData syncHealthIcon(SyncHealth h) => switch (h) {
      SyncHealth.ok => Icons.cloud_done_rounded,
      SyncHealth.pending => Icons.cloud_sync_rounded,
      SyncHealth.stuck => Icons.cloud_off_rounded,
      SyncHealth.stale => Icons.cloud_queue_rounded,
    };

/// السحابة: حالة مزامنة الجهاز ده (بيانات جاهزة).
class SyncCloudView extends StatelessWidget {
  final SyncHealth health;
  final int pending;
  final int unsynced;
  final String? lastError;
  final bool isDark;
  final VoidCallback? onUploadNow;

  const SyncCloudView({
    super.key,
    required this.health,
    required this.pending,
    required this.unsynced,
    required this.isDark,
    this.lastError,
    this.onUploadNow,
  });

  String get _title => switch (health) {
        SyncHealth.ok => 'كل بياناتك متزامنة مع الفريق',
        SyncHealth.pending => 'بيرفع $pending صف للفريق…',
        SyncHealth.stuck => '${pending + unsynced} صف ما وصلش للفريق',
        SyncHealth.stale => 'مش متصل بالفريق',
      };

  String? get _hint => switch (health) {
        SyncHealth.ok => null,
        SyncHealth.pending => 'استنى لحظات، وهيبقى كله متزامن لوحده.',
        SyncHealth.stuck =>
          'البيانات دي موجودة على جهازك بس، والمدرّس والمساعدين مش شايفينها. اضغط «ارفع دلوقتي».',
        SyncHealth.stale => 'اتأكد من الإنترنت وافتح التطبيق تاني.',
      };

  @override
  Widget build(BuildContext context) {
    final c = syncHealthColor(health, isDark);
    final ink = isDark ? Colors.white : Colors.black87;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.withValues(alpha: 0.5)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(syncHealthIcon(health), color: c, size: 30),
          const SizedBox(width: 10),
          Expanded(
            child: Text(_title,
                style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: ink)),
          ),
        ]),
        if (_hint != null) ...[
          const SizedBox(height: 4),
          Text(_hint!,
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 12,
                  color: isDark ? Colors.white70 : Colors.black54)),
        ],
        if ((lastError ?? '').isNotEmpty && health == SyncHealth.stuck) ...[
          const SizedBox(height: 4),
          Text(lastError!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontFamily: 'Cairo', fontSize: 11, color: c)),
        ],
        if (health == SyncHealth.stuck && onUploadNow != null) ...[
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: onUploadNow,
            style: FilledButton.styleFrom(backgroundColor: c),
            icon: const Icon(Icons.cloud_upload_rounded, size: 18),
            label: const Text('ارفع دلوقتي',
                style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700)),
          ),
        ],
      ]),
    );
  }
}

/// بتسحب أرقام الجهاز ده كل 3 ثواني وتعرض السحابة.
class SyncCloud extends StatefulWidget {
  final bool isDark;
  final TeamModeService team;
  const SyncCloud({super.key, required this.isDark, required this.team});

  @override
  State<SyncCloud> createState() => _SyncCloudState();
}

class _SyncCloudState extends State<SyncCloud> {
  Timer? _timer;
  int _pending = 0, _unsynced = 0;
  String? _error;
  bool _transient = false;
  DateTime? _drainAt;

  @override
  void initState() {
    super.initState();
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _refresh());
  }

  Future<void> _refresh() async {
    final p = await widget.team.pendingOutboxCount() ?? 0;
    final u = await widget.team.unsyncedTotal();
    if (!mounted) return;
    setState(() {
      _pending = p;
      _unsynced = u;
      _error = widget.team.lastOutboxError;
      _transient = widget.team.lastOutboxErrorIsTransient;
      _drainAt = widget.team.lastDrainAt;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _uploadNow() async {
    final n = await widget.team.resyncUnsyncedOnly();
    if (!mounted) return;
    ToastHelper.info(n == null
        ? 'وضع الفريق مش شغّال دلوقتي'
        : n == 0
            ? 'مفيش صفوف ناقصة — كله متزامن'
            : 'جاري رفع $n صف ناقص...');
    unawaited(widget.team.reportStatusNow());
    unawaited(_refresh());
  }

  @override
  Widget build(BuildContext context) {
    final health = classifySyncHealth(
      pending: _pending,
      unsynced: _unsynced,
      lastError: _error,
      errorTransient: _transient,
      sinceLastContact:
          _drainAt == null ? null : DateTime.now().difference(_drainAt!),
      staleAfter: const Duration(minutes: 10),
    );
    return SyncCloudView(
      health: health,
      pending: _pending,
      unsynced: _unsynced,
      lastError: _error,
      isDark: widget.isDark,
      onUploadNow: _uploadNow,
    );
  }
}

/// صف جهاز واحد في «حالة أجهزة الفريق».
class DeviceStatusTile extends StatelessWidget {
  final DeviceSyncStatus status;
  final bool isMe;
  final bool isDark;
  const DeviceStatusTile(
      {super.key, required this.status, required this.isMe, required this.isDark});

  String get _line1 => switch (status.health) {
        SyncHealth.ok => 'متزامن ✓',
        SyncHealth.pending => 'بيرفع ${status.pending} صف',
        SyncHealth.stuck =>
          '${status.pending + status.unsynced} صف ما وصلش السيرفر',
        SyncHealth.stale => 'مش متصل ${agoText(status.sinceUpdate)}',
      };

  @override
  Widget build(BuildContext context) {
    final h = status.health;
    final c = syncHealthColor(h, isDark);
    final ink = isDark ? Colors.white : Colors.black87;
    final sub = isDark ? Colors.white60 : Colors.black45;
    final details = <String>[
      'آخر نبضة ${agoText(status.sinceUpdate)}',
      if (status.sincePush != null) 'آخر رفع ${agoText(status.sincePush!)}',
      if (status.appVersion != null) 'إصدار ${status.appVersion}',
    ].join(' • ');
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.withValues(alpha: 0.35)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(syncHealthIcon(h), color: c, size: 24),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(spacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
              Text(status.name,
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: ink)),
              _chip(status.isOwner ? 'المدرّس' : 'مساعد', sub),
              if (isMe) _chip('جهازك', const Color(0xFF6366F1)),
            ]),
            Text(_line1,
                style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: c)),
            Text(details,
                style: TextStyle(fontFamily: 'Cairo', fontSize: 11, color: sub)),
            if (h == SyncHealth.stuck && (status.lastError ?? '').isNotEmpty)
              Text(status.lastError!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontFamily: 'Cairo', fontSize: 11, color: c)),
          ]),
        ),
      ]),
    );
  }

  Widget _chip(String t, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(t,
            style: TextStyle(fontFamily: 'Cairo', fontSize: 10.5, color: c)),
      );
}

/// قسم المدرّس: «حالة أجهزة الفريق» (بيتحدّث كل 20 ثانية + زرار تحديث).
class TeamDevicesCard extends StatefulWidget {
  final bool isDark;
  final TeamModeService team;
  const TeamDevicesCard({super.key, required this.isDark, required this.team});

  @override
  State<TeamDevicesCard> createState() => _TeamDevicesCardState();
}

class _TeamDevicesCardState extends State<TeamDevicesCard> {
  Timer? _timer;
  List<DeviceSyncStatus>? _rows;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 20), (_) => _load());
  }

  Future<void> _load() async {
    final rows = await widget.team.deviceStatuses();
    if (!mounted) return;
    setState(() {
      _rows = rows;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ink = widget.isDark ? Colors.white : Colors.black87;
    final sub = widget.isDark ? Colors.white60 : Colors.black45;
    final rows = _rows;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(
          child: Text('حالة أجهزة الفريق',
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: ink)),
        ),
        IconButton(
          tooltip: 'تحديث حالة الأجهزة',
          onPressed: () {
            setState(() => _loading = true);
            _load();
          },
          icon: const Icon(Icons.refresh_rounded, size: 20),
        ),
      ]),
      if (_loading && rows == null)
        const Padding(
          padding: EdgeInsets.all(12),
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        )
      else if (rows == null)
        Text(
            'مش قادر أقرا حالة الأجهزة دلوقتي (تأكد من الإنترنت). لو المشكلة '
            'مستمرة يبقى لسه محتاجة تحديث من السيرفر.',
            style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: sub))
      else if (rows.isEmpty)
        Text(
            'لسه مفيش جهاز بعت حالته. الأجهزة بتظهر هنا بعد ما تفتح التطبيق '
            'النسخة الجديدة وتتصل بالفريق.',
            style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: sub))
      else
        for (final r in rows)
          DeviceStatusTile(
              status: r,
              isMe: r.deviceId == widget.team.myDeviceId,
              isDark: widget.isDark),
    ]);
  }
}
