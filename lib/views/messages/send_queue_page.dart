// lib/views/messages/send_queue_page.dart
//
// شاشة طابور الإرسال: بتعدّي على الرسائل واحدة واحدة. المدرس بيدوس زرار واحد،
// بيفتح واتساب برسالة جاهزة، يدوس «إرسال» هناك ويرجع، فالطابور يتحرّك للتالية
// لوحده. بتصميم السبورة والطباشير.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:active_class/config/theme.dart';
import 'package:active_class/controllers/settings_controller.dart';
import 'package:active_class/utils/send_queue.dart';
import 'package:active_class/utils/whatsapp_launcher.dart';
import 'package:active_class/widgets/app_chrome.dart';
import 'package:active_class/widgets/app_panel.dart';
import 'package:active_class/widgets/app_toast.dart';
import 'package:active_class/widgets/points_chalk.dart';

class SendQueuePage extends StatefulWidget {
  final String title;
  final List<QueueItem> items;

  /// للاختبار: بدل فتح واتساب/المشاركة بنرجّع نجاح.
  final Future<bool> Function(QueueItem item)? opener;

  const SendQueuePage({
    super.key,
    required this.title,
    required this.items,
    this.opener,
  });

  @override
  State<SendQueuePage> createState() => _SendQueuePageState();
}

class _SendQueuePageState extends State<SendQueuePage>
    with WidgetsBindingObserver {
  late final SendQueue _q = SendQueue(widget.items);
  bool _awaitingReturn = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // رجع من واتساب → الطابور يروح للتالية لوحده.
    if (state == AppLifecycleState.resumed && _awaitingReturn) {
      _awaitingReturn = false;
      setState(() => _q.advance());
    }
  }

  String get _dial => Get.isRegistered<SettingsController>()
      ? Get.find<SettingsController>().countryDial.value
      : '20';

  Future<bool> _shareAttachment(QueueItem it) async {
    final att = it.attachment!;
    final bytes = await att.bytes();
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/${att.fileName}');
    await file.writeAsBytes(bytes, flush: true);
    final res = await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/pdf')],
      text: withTeacherSignature(it.message),
    );
    return res.status != ShareResultStatus.dismissed;
  }

  Future<void> _openCurrent() async {
    final it = _q.currentItem;
    if (it == null || _busy) return;
    final index = _q.current;
    setState(() => _busy = true);
    var ok = false;
    try {
      if (widget.opener != null) {
        ok = await widget.opener!(it);
      } else if (it.attachment != null) {
        ok = await _shareAttachment(it);
      } else {
        ok = await launchGuardianWhatsapp(
          context: context,
          phone: it.phone,
          whatsapp: it.whatsapp,
          message: it.message,
          dialCode: _dial,
        );
        // الحركة للتالية بتحصل لما يرجع من واتساب.
        _awaitingReturn = ok;
      }
    } catch (_) {
      ok = false;
      if (mounted) AppToast.error(context, 'تعذر فتح الإرسال لـ ${it.name}');
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (ok) {
        _q.markOpened(index);
        // المشاركة والاختبار مفيهمش رجوع من واتساب، فنتحرك فورًا.
        if (it.attachment != null || widget.opener != null) _q.advance();
      }
    });
  }

  void _skipCurrent() {
    final it = _q.currentItem;
    if (it == null) return;
    setState(() {
      _q.skip(_q.current);
      _q.advance();
    });
  }

  void _tapRow(int i) {
    setState(() {
      // اللي اتفتحت بتفضل «اتفتحت» (الضغط عليها بس بيعرضها لو عايز تبعتها
      // تاني)، واللي اتخطّت بترجع منتظرة.
      if (_q.items[i].status == QueueStatus.skipped) _q.reset(i);
      _q.jumpTo(i);
    });
  }

  void _retrySkipped() {
    setState(() {
      for (var i = 0; i < _q.items.length; i++) {
        if (_q.items[i].status == QueueStatus.skipped) _q.reset(i);
      }
      _q.advance();
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Scaffold(
      backgroundColor: t.page,
      appBar: buildBoardAppBar(context, title: widget.title),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
            AppSpace.lg, AppSpace.sm, AppSpace.lg, AppSpace.xl),
        children: [
          _board(t),
          const SizedBox(height: AppSpace.md),
          if (_q.isDone) _donePanel(t) else _currentPanel(t),
          const SizedBox(height: AppSpace.lg),
          Text('كل الرسائل', style: AppType.label.copyWith(color: t.ink)),
          const SizedBox(height: AppSpace.sm),
          for (var i = 0; i < _q.items.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpace.sm),
              child: _row(t, i),
            ),
        ],
      ),
    );
  }

  Widget _board(AppTokens t) {
    final on = AppTokens.dark;
    final done = _q.openedCount + _q.skippedCount;
    return Container(
      decoration: BoxDecoration(
        color: t.board,
        borderRadius: BorderRadius.circular(AppRadius.board),
      ),
      padding: const EdgeInsets.all(AppSpace.lg),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text('$done من ${_q.total}',
                style: AppType.greeting.copyWith(color: t.boardInk)),
          ),
          Text('${(_q.progress * 100).round()}%',
              style: AppType.greeting.copyWith(color: t.chalk)),
        ]),
        const SizedBox(height: AppSpace.sm),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: _q.progress,
            minHeight: 10,
            color: t.chalk,
            backgroundColor: Colors.white.withValues(alpha: 0.14),
          ),
        ),
        const SizedBox(height: AppSpace.md),
        const ChalkDashedLine(),
        const SizedBox(height: AppSpace.md),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
              child: BoardStat(
                  label: 'اتفتحت',
                  value: '${_q.openedCount}',
                  color: on.positive)),
          Expanded(
              child: BoardStat(
                  label: 'متبقي',
                  value: '${_q.pendingCount}',
                  color: t.chalk)),
          Expanded(
              child: BoardStat(
                  label: 'اتخطّت',
                  value: '${_q.skippedCount}',
                  color: t.boardInkSoft)),
        ]),
      ]),
    );
  }

  Widget _currentPanel(AppTokens t) {
    final it = _q.currentItem;
    if (it == null) return const SizedBox.shrink();
    final isAttachment = it.attachment != null;
    final again = it.status == QueueStatus.opened;
    return AppPanel(
      padding: const EdgeInsets.all(AppSpace.lg),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('الدور على', style: AppType.caption.copyWith(color: t.inkSoft)),
        Text(it.name, style: AppType.title.copyWith(color: t.ink)),
        if (again)
          Text('اتفتحت قبل كده ✓',
              style: AppType.caption.copyWith(color: t.positive)),
        if (it.subtitle.isNotEmpty)
          Text(it.subtitle, style: AppType.body.copyWith(color: t.inkSoft)),
        const SizedBox(height: AppSpace.md),
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxHeight: 180),
          padding: const EdgeInsets.all(AppSpace.md),
          decoration: BoxDecoration(
            color: t.rosterTint,
            borderRadius: BorderRadius.circular(AppRadius.control),
          ),
          child: SingleChildScrollView(
            child: Text(it.message,
                style: AppType.body.copyWith(color: t.ink)),
          ),
        ),
        const SizedBox(height: AppSpace.md),
        FilledButton.icon(
          onPressed: _busy ? null : _openCurrent,
          style: FilledButton.styleFrom(
              backgroundColor: t.brand,
              minimumSize: const Size(double.infinity, 52)),
          icon: Icon(isAttachment ? Icons.attach_file_rounded : Icons.chat_rounded),
          label: Text(again
              ? 'ابعت تاني'
              : (isAttachment ? 'شارك البطاقة' : 'افتح واتساب وابعت')),
        ),
        const SizedBox(height: AppSpace.sm),
        if (!again)
          OutlinedButton(
            onPressed: _busy ? null : _skipCurrent,
            style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48)),
            child: const Text('تخطّي'),
          )
        else
          OutlinedButton(
            onPressed: _busy
                ? null
                : () => setState(() {
                      if (!_q.advance()) _q.jumpTo(_q.current);
                    }),
            style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48)),
            child: const Text('التالي'),
          ),
        const SizedBox(height: AppSpace.xs),
        Text(
            isAttachment
                ? 'هتفتح قايمة المشاركة: اختار واتساب وبعدين ولي الأمر.'
                : 'ابعت الرسالة في واتساب وارجع، هنروح للي بعده لوحدنا.',
            style: AppType.caption.copyWith(color: t.inkSoft)),
      ]),
    );
  }

  Widget _donePanel(AppTokens t) => AppPanel(
        padding: const EdgeInsets.all(AppSpace.lg),
        child: Column(children: [
          Icon(Icons.check_circle_rounded, size: 48, color: t.positive),
          const SizedBox(height: AppSpace.sm),
          Text('خلّصت الطابور',
              style: AppType.title.copyWith(color: t.ink)),
          const SizedBox(height: 2),
          Text(
              'اتفتح ${_q.openedCount} من ${_q.total}'
              '${_q.skippedCount > 0 ? '، واتخطّى ${_q.skippedCount}' : ''}.',
              style: AppType.body.copyWith(color: t.inkSoft)),
          if (_q.skippedCount > 0) ...[
            const SizedBox(height: AppSpace.md),
            OutlinedButton(
              onPressed: _retrySkipped,
              child: const Text('ابعت اللي اتخطّوا'),
            ),
          ],
        ]),
      );

  Widget _row(AppTokens t, int i) {
    final it = _q.items[i];
    final isCurrent = i == _q.current && !_q.isDone;
    final (IconData icon, Color color, String label) = switch (it.status) {
      QueueStatus.opened => (Icons.check_circle_rounded, t.positive, 'اتفتحت'),
      QueueStatus.skipped when !it.canSend =>
        (Icons.phone_disabled_rounded, t.danger, 'مفيش رقم'),
      QueueStatus.skipped =>
        (Icons.skip_next_rounded, t.inkFaint, 'اتخطّت'),
      QueueStatus.pending =>
        (Icons.radio_button_unchecked_rounded, t.brand, 'منتظرة'),
    };
    return AppPanel(
      onTap: it.canSend ? () => _tapRow(i) : null,
      lineColor: isCurrent ? t.brand : null,
      child: Row(children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(width: AppSpace.md),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(it.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.label.copyWith(color: t.ink)),
                if (it.subtitle.isNotEmpty)
                  Text(it.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.caption.copyWith(color: t.inkSoft)),
              ]),
        ),
        const SizedBox(width: AppSpace.sm),
        Text(label, style: AppType.caption.copyWith(color: color)),
      ]),
    );
  }
}
