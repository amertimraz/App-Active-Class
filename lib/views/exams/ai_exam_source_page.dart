// lib/views/exams/ai_exam_source_page.dart
//
// spec 057 — «من ملف أو صورة»: المدرس يختار الوضع (تحويل امتحان موجود / توليد
// أسئلة من شرح درس)، يحط الصور أو PDF أو نص، ويبدأ. النتيجة بتتحط كمسودة في
// محرر الامتحان للمراجعة — مفيش نشر تلقائي أبدًا. الصفحة بترجّع AiExamResult.
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import 'package:active_class/config/theme.dart';
import 'package:active_class/models/ai_draft_question.dart';
import 'package:active_class/services/ai_exam_service.dart';
import 'package:active_class/services/database_service.dart';
import 'package:active_class/utils/ai_exam_prepare.dart';
import 'package:active_class/utils/helpers.dart';
import 'package:active_class/widgets/app_chrome.dart';

enum _Phase { input, running, result }

const _kNoticeKey = 'ai_exam_notice_seen';

class AiExamSourcePage extends StatefulWidget {
  const AiExamSourcePage({super.key});

  @override
  State<AiExamSourcePage> createState() => _AiExamSourcePageState();
}

class _AiExamSourcePageState extends State<AiExamSourcePage> {
  String _mode = 'convert';
  final List<Uint8List> _pages = [];
  final _text = TextEditingController();
  int _mcq = 8; // عدد أسئلة الاختيار من متعدد (وضع التوليد)
  int _tf = 2; // عدد أسئلة صح/خطأ
  String _difficulty = 'medium';
  _Phase _phase = _Phase.input;
  bool _preparing = false;
  String _status = '';
  AiExamResult? _result;
  late Future<({int remaining, int limit})?> _quota;

  @override
  void initState() {
    super.initState();
    _quota = AiExamService.instance.quota();
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  int get _bytes => _pages.fold(0, (s, p) => s + p.length);

  Future<void> _add(Future<List<Uint8List>> Function() source) async {
    setState(() => _preparing = true);
    try {
      final fresh = await source();
      final check = checkAiLimits(
          imageCount: _pages.length + fresh.length,
          totalBytes: _bytes + fresh.fold(0, (s, p) => s + p.length));
      if (!check.ok) {
        ToastHelper.error(check.message!);
      } else {
        setState(() => _pages.addAll(fresh));
      }
    } catch (_) {
      ToastHelper.error('تعذّر قراءة الملف — جرّب صورة أو PDF تاني');
    }
    if (mounted) setState(() => _preparing = false);
  }

  Future<void> _camera() => _add(() async {
        final x = await ImagePicker().pickImage(source: ImageSource.camera, maxWidth: 2400);
        return x == null ? [] : [await compressImage(await x.readAsBytes())];
      });

  Future<void> _gallery() => _add(() async {
        final xs = await ImagePicker().pickMultiImage(maxWidth: 2400);
        return [for (final x in xs) await compressImage(await x.readAsBytes())];
      });

  Future<void> _pdf() => _add(() async {
        final r = await FilePicker.platform
            .pickFiles(type: FileType.custom, allowedExtensions: ['pdf'], withData: true);
        final bytes = r?.files.single.bytes;
        return bytes == null ? [] : await rasterizePdf(bytes);
      });

  bool get _canStart {
    if (_preparing) return false;
    if (_mode == 'convert') return _pages.isNotEmpty;
    if (_mcq + _tf < 1) return false;
    return _pages.isNotEmpty || _text.text.trim().length >= 40;
  }

  Future<bool> _confirmNotice() async {
    final seen = await DatabaseService().getSetting(_kNoticeKey);
    if (seen == '1') return true;
    final ok = await Get.dialog<bool>(AlertDialog(
      title: const Text('قبل ما تبدأ'),
      content: const Text(
          'الأسئلة بتتقرا وتتولّد بالذكاء الاصطناعي، وممكن يغلط (في نص سؤال أو إجابة '
          'صحيحة). لازم تراجع كل سؤال قبل ما تنشر الامتحان — الطلاب هيتقيّموا بيه. '
          'الصور بتتبعت للمعالجة وبتتمسح بعدها ومابتتخزنش.'),
      actions: [
        TextButton(onPressed: () => Get.back(result: false), child: const Text('إلغاء')),
        FilledButton(onPressed: () => Get.back(result: true), child: const Text('فاهم، كمّل')),
      ],
    ));
    if (ok == true) await DatabaseService().setSetting(_kNoticeKey, '1');
    return ok == true;
  }

  Future<void> _start() async {
    if (!await _confirmNotice()) return;
    setState(() {
      _phase = _Phase.running;
      _status = 'queued';
    });
    try {
      final r = await AiExamService.instance.run(
        mode: _mode,
        images: _pages,
        text: _text.text.trim(),
        count: _mcq + _tf,
        mcqCount: _mode == 'generate' ? _mcq : null,
        tfCount: _mode == 'generate' ? _tf : 0,
        difficulty: _difficulty,
        onProgress: (s) {
          if (mounted) setState(() => _status = s);
        },
      );
      if (!mounted) return;
      setState(() {
        _result = r;
        _phase = _Phase.result;
      });
    } on AiExamException catch (e) {
      if (!mounted) return;
      setState(() => _phase = _Phase.input);
      ToastHelper.error(e.message);
      _quota = AiExamService.instance.quota();
    } catch (_) {
      if (!mounted) return;
      setState(() => _phase = _Phase.input);
      ToastHelper.error('تعذّرت العملية — حاول بعد شوية');
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return PopScope(
      canPop: _phase != _Phase.running,
      child: Scaffold(
        backgroundColor: t.page,
        appBar: buildBoardAppBar(context, title: 'من ملف أو صورة'),
        body: switch (_phase) {
          _Phase.input => _input(context),
          _Phase.running => _running(),
          _Phase.result => _resultView(context),
        },
      ),
    );
  }

  // ── الإدخال ────────────────────────────────────────────────────────
  Widget _input(BuildContext context) {
    return ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 32), children: [
      SegmentedButton<String>(
        segments: const [
          ButtonSegment(value: 'convert', icon: Icon(Icons.document_scanner_rounded), label: Text('تحويل امتحان موجود')),
          ButtonSegment(value: 'generate', icon: Icon(Icons.auto_awesome_rounded), label: Text('أسئلة من شرح درس')),
        ],
        selected: {_mode},
        onSelectionChanged: (s) => setState(() => _mode = s.first),
      ),
      const SizedBox(height: 8),
      Text(
        _mode == 'convert'
            ? 'صوّر ورقة الامتحان (أو ارفع PDF) وهنطلّع الأسئلة. الإجابة الصحيحة بتتحدد بس لو معلّمة في الورقة.'
            : 'ارفع صور صفحات الدرس أو PDF أو الصق نص الشرح، وهنولّد أسئلة اختيار من متعدد بإجابات وشرح.',
        style: const TextStyle(fontFamily: 'Cairo', fontSize: 12.5),
      ),
      const SizedBox(height: 14),
      Wrap(spacing: 8, runSpacing: 8, children: [
        OutlinedButton.icon(onPressed: _preparing ? null : _camera, icon: const Icon(Icons.photo_camera_outlined), label: const Text('كاميرا')),
        OutlinedButton.icon(onPressed: _preparing ? null : _gallery, icon: const Icon(Icons.photo_library_outlined), label: const Text('من المعرض')),
        OutlinedButton.icon(onPressed: _preparing ? null : _pdf, icon: const Icon(Icons.picture_as_pdf_outlined), label: const Text('PDF')),
      ]),
      if (_preparing)
        const Padding(padding: EdgeInsets.only(top: 12), child: LinearProgressIndicator()),
      if (_pages.isNotEmpty) ...[
        const SizedBox(height: 12),
        Text('${_pages.length} صفحة (أقصى $kAiMaxImages)', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        SizedBox(
          height: 96,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _pages.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) => Stack(children: [
              ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.memory(_pages[i], height: 96, width: 72, fit: BoxFit.cover)),
              PositionedDirectional(
                top: 2, end: 2,
                child: InkWell(
                  onTap: () => setState(() => _pages.removeAt(i)),
                  child: const CircleAvatar(radius: 11, backgroundColor: Colors.black54, child: Icon(Icons.close, size: 14, color: Colors.white)),
                ),
              ),
            ]),
          ),
        ),
      ],
      if (_mode == 'generate') ...[
        const SizedBox(height: 14),
        TextField(
          controller: _text,
          minLines: 3,
          maxLines: 8,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(labelText: 'أو الصق نص الشرح هنا (40 حرف على الأقل)', alignLabelWithHint: true),
        ),
        const SizedBox(height: 12),
        const Text('نوع الأسئلة وعدد كل نوع',
            style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        _counter('اختيار من متعدد', Icons.checklist_rounded, _mcq,
            (v) => setState(() => _mcq = v)),
        _counter('صح / خطأ', Icons.rule_rounded, _tf, (v) => setState(() => _tf = v)),
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 8),
          child: Text(
            _mcq + _tf < 1
                ? 'اختار سؤال واحد على الأقل'
                : 'الإجمالي ${_mcq + _tf} سؤال (أقصى $kAiMaxQuestions)',
            style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12,
                color: _mcq + _tf < 1 ? Colors.red.shade700 : null),
          ),
        ),
        DropdownButtonFormField<String>(
          initialValue: _difficulty,
          decoration: const InputDecoration(labelText: 'الصعوبة'),
          items: const [
            DropdownMenuItem(value: 'easy', child: Text('سهل')),
            DropdownMenuItem(value: 'medium', child: Text('متوسط')),
            DropdownMenuItem(value: 'hard', child: Text('صعب')),
          ],
          onChanged: (v) => setState(() => _difficulty = v ?? 'medium'),
        ),
      ],
      const SizedBox(height: 16),
      FutureBuilder<({int remaining, int limit})?>(
        future: _quota,
        builder: (_, snap) {
          final q = snap.data;
          if (q == null) return const SizedBox.shrink();
          final low = q.remaining <= (q.limit * 0.2).ceil();
          return Row(children: [
            Icon(low ? Icons.warning_amber_rounded : Icons.data_usage_rounded, size: 18, color: low ? Colors.orange : null),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                q.remaining == 0
                    ? 'الحصة الشهرية خلصت — تقدر تكمل بالإنشاء اليدوي أو البنك'
                    : 'المتبقي ${q.remaining} من ${q.limit} عملية هذا الشهر',
                style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: low ? Colors.orange.shade800 : null),
              ),
            ),
          ]);
        },
      ),
      const SizedBox(height: 14),
      SizedBox(
        height: 50,
        child: FilledButton.icon(
          onPressed: _canStart ? _start : null,
          icon: const Icon(Icons.play_arrow_rounded),
          label: Text(_mode == 'convert' ? 'حوّل لأسئلة' : 'ولّد الأسئلة', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800)),
        ),
      ),
    ]);
  }

  /// عدّاد (− عدد +) لنوع أسئلة. الإجمالي ما يزيدش عن kAiMaxQuestions.
  Widget _counter(String label, IconData icon, int value, ValueChanged<int> onChanged) {
    final canAdd = _mcq + _tf < kAiMaxQuestions;
    return Row(children: [
      Icon(icon, size: 20),
      const SizedBox(width: 8),
      Expanded(child: Text(label, style: const TextStyle(fontFamily: 'Cairo', fontSize: 13.5))),
      IconButton(
        visualDensity: VisualDensity.compact,
        onPressed: value > 0 ? () => onChanged(value - 1) : null,
        icon: const Icon(Icons.remove_circle_outline_rounded),
      ),
      SizedBox(
        width: 28,
        child: Text('$value',
            textAlign: TextAlign.center,
            style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w900, fontSize: 16)),
      ),
      IconButton(
        visualDensity: VisualDensity.compact,
        onPressed: canAdd ? () => onChanged(value + 1) : null,
        icon: const Icon(Icons.add_circle_outline_rounded),
      ),
    ]);
  }

  // ── المعالجة ───────────────────────────────────────────────────────
  Widget _running() {
    final label = _status == 'queued' ? 'في الانتظار…' : 'بقرا الصور وبطلّع الأسئلة…';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 18),
          Text(label, style: const TextStyle(fontFamily: 'Cairo', fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          const Text('ممكن ياخد لحد دقيقة — متقفلش الشاشة', style: TextStyle(fontFamily: 'Cairo', fontSize: 12)),
        ]),
      ),
    );
  }

  // ── النتيجة ────────────────────────────────────────────────────────
  Widget _resultView(BuildContext context) {
    final r = _result!;
    final noAnswer = r.questions.where((q) => !q.hasAnswer).length;
    return ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 32), children: [
      Text('${r.questions.length} سؤال جاهز للمراجعة', style: const TextStyle(fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.w900)),
      const SizedBox(height: 8),
      if (r.needsReviewCount > 0) _note(Icons.rule_rounded, '${r.needsReviewCount} سؤال محتاج مراجعة (مش واثق من قراءته)'),
      if (noAnswer > 0) _note(Icons.help_outline_rounded, '$noAnswer سؤال من غير إجابة صحيحة — لازم تحددها قبل النشر'),
      if (r.skipped > 0) _note(Icons.skip_next_rounded, 'اتخطّى ${r.skipped} سؤال (مقالي أو غير مدعوم)'),
      for (final n in r.notes) _note(Icons.info_outline_rounded, n),
      if (r.questions.any((q) => q.hasFigure)) _note(Icons.image_outlined, 'في أسئلة فيها شكل أو رسم — ضيف صورتها من محرر السؤال'),
      const SizedBox(height: 12),
      ...r.questions.take(3).map((q) => Card(
            margin: const EdgeInsets.symmetric(vertical: 4),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Text(q.text, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: 'Cairo', fontSize: 13)),
            ),
          )),
      if (r.questions.length > 3) Text('… و${r.questions.length - 3} سؤال تاني', style: const TextStyle(fontFamily: 'Cairo', fontSize: 12)),
      const SizedBox(height: 18),
      SizedBox(
        height: 50,
        child: FilledButton.icon(
          onPressed: () => Get.back(result: r),
          icon: const Icon(Icons.playlist_add_check_rounded),
          label: const Text('أضف للامتحان وراجع', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800)),
        ),
      ),
      const SizedBox(height: 8),
      TextButton(onPressed: () => setState(() => _phase = _Phase.input), child: const Text('رجوع وجرّب صور تانية')),
    ]);
  }

  Widget _note(IconData icon, String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 17, color: AppTheme.primaryColor),
          const SizedBox(width: 6),
          Expanded(child: Text(text, style: const TextStyle(fontFamily: 'Cairo', fontSize: 12.5))),
        ]),
      );
}
