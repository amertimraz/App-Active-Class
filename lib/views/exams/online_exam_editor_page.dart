// lib/views/exams/online_exam_editor_page.dart
//
// spec 016 — تأليف امتحان إلكتروني: أسئلة صح/خطأ + اختيار من متعدد،
// نافذة زمنية + مدة + مجموعات، ثم حفظ كمسودّة أو نشر.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import 'package:active_class/config/theme.dart';
import 'package:active_class/controllers/exam_controller.dart';
import 'package:active_class/controllers/group_controller.dart';
import 'package:active_class/models/exam_model.dart';
import 'package:active_class/models/exam_question_model.dart';
import 'package:active_class/models/group_model.dart';
import 'package:active_class/services/parent_portal_service.dart';
import 'package:active_class/utils/helpers.dart';
import 'package:active_class/views/exams/online_exam_preview_page.dart';

class OnlineExamEditorPage extends StatefulWidget {
  final Exam? existing;
  const OnlineExamEditorPage({super.key, this.existing});

  @override
  State<OnlineExamEditorPage> createState() => _OnlineExamEditorPageState();
}

class _QDraft {
  int? id;
  ExamQuestionType type;
  final TextEditingController text;
  final List<TextEditingController> options;
  int correctIndex;
  double points;
  String? imageUrl; // spec 019
  final TextEditingController explanation; // spec 023
  bool uploadingImage = false;

  _QDraft({
    this.id,
    this.type = ExamQuestionType.mcq,
    String text = '',
    List<String>? options,
    this.correctIndex = 0,
    this.points = 1,
    this.imageUrl,
    String explanation = '',
  })  : text = TextEditingController(text: text),
        explanation = TextEditingController(text: explanation),
        options = (options ??
                (type == ExamQuestionType.trueFalse
                    ? kTrueFalseOptions
                    : const ['', '']))
            .map((o) => TextEditingController(text: o))
            .toList();

  void dispose() {
    text.dispose();
    explanation.dispose();
    for (final o in options) {
      o.dispose();
    }
  }

  ExamQuestion toModel(int examId, int position) => ExamQuestion(
        id: id,
        examId: examId,
        position: position,
        type: type,
        text: text.text.trim(),
        options: options.map((o) => o.text.trim()).toList(),
        correctIndex: correctIndex,
        points: points,
        imageUrl: imageUrl,
        explanation:
            explanation.text.trim().isEmpty ? null : explanation.text.trim(),
      );
}

class _OnlineExamEditorPageState extends State<OnlineExamEditorPage> {
  final _ec = Get.find<ExamController>();
  final _gc = Get.isRegistered<GroupController>()
      ? Get.find<GroupController>()
      : Get.put(GroupController());

  final _nameCtrl = TextEditingController();
  final List<_QDraft> _questions = [];
  final Set<int> _groupIds = {};
  DateTime? _opensAt;
  DateTime? _closesAt;
  int _durationMinutes = 30;

  int? _examId;
  bool _loading = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      _examId = widget.existing!.id;
      _nameCtrl.text = widget.existing!.name;
      _groupIds.addAll(widget.existing!.groupIds);
      _opensAt = widget.existing!.opensAt?.toLocal();
      _closesAt = widget.existing!.closesAt?.toLocal();
      _durationMinutes = widget.existing!.durationMinutes ?? 30;
      _loadQuestions();
    }
  }

  Future<void> _loadQuestions() async {
    setState(() => _loading = true);
    final qs = await _ec.getQuestions(_examId!);
    setState(() {
      _questions
        ..clear()
        ..addAll(qs.map((q) => _QDraft(
              id: q.id,
              type: q.type,
              text: q.text,
              options: q.options,
              correctIndex: q.correctIndex,
              points: q.points,
              imageUrl: q.imageUrl,
              explanation: q.explanation ?? '',
            )));
      _loading = false;
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    for (final q in _questions) {
      q.dispose();
    }
    super.dispose();
  }

  double get _totalPoints => _questions.fold(0, (s, q) => s + q.points);

  bool get _isPublished =>
      widget.existing?.onlineStatus == OnlineExamStatus.published;

  void _addQuestion(ExamQuestionType type) {
    setState(() => _questions.add(_QDraft(type: type)));
  }

  // ── صورة السؤال (spec 019) ──────────────────────────────────────────────
  Future<void> _pickQuestionImage(int i) async {
    XFile? file;
    try {
      file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
        maxWidth: 1600,
        // requestFullMetadata: false يتجنّب قراءة الـEXIF/الموقع اللي
        // بتكراش على بعض أجهزة MIUI/شاومي (NullPointerException في
        // deliverResultsIfNeeded) — إحنا مش محتاجين الميتاداتا أصلاً.
        requestFullMetadata: false,
      );
    } catch (_) {
      // بعض أجهزة MIUI بترجّع نتيجة activity ناقصة — نجرّب استرجاع
      // الصورة الضائعة قبل ما نستسلم.
      try {
        final lost = await ImagePicker().retrieveLostData();
        if (!lost.isEmpty && lost.file != null) {
          file = lost.file;
        }
      } catch (_) {}
      if (file == null) {
        if (mounted) ToastHelper.error('تعذّر اختيار الصورة — جرّب تاني');
        return;
      }
    }
    if (file == null || !mounted) return;

    setState(() => _questions[i].uploadingImage = true);
    final bytes = await file.readAsBytes();
    final url = await _ec.uploadQuestionImage(_examId ?? 0, bytes);
    if (!mounted) return;
    setState(() {
      _questions[i].uploadingImage = false;
      if (url != null) {
        _questions[i].imageUrl = url;
      } else {
        ToastHelper.error('تعذّر رفع الصورة — حاول تاني');
      }
    });
  }

  Future<int?> _ensureSaved({required OnlineExamStatus status}) async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ToastHelper.error('أدخل اسم الامتحان');
      return null;
    }
    _examId ??= await _ec.createOnlineExamDraft(name: name);
    final baseDate = widget.existing?.date ?? DateTime.now();
    final exam = Exam(
      id: _examId,
      name: name,
      date: baseDate,
      isOnline: true,
      onlineStatus: status,
      opensAt: _opensAt?.toUtc(),
      closesAt: _closesAt?.toUtc(),
      durationMinutes: _durationMinutes,
    );
    final questions = <ExamQuestion>[
      for (var i = 0; i < _questions.length; i++) _questions[i].toModel(_examId!, i),
    ];
    final err = await _ec.saveOnlineExamDraft(
      exam: exam,
      questions: questions,
      groupIds: _groupIds.toList(),
    );
    if (err != null) {
      ToastHelper.error(err);
      return null;
    }
    return _examId;
  }

  Future<void> _saveDraft() async {
    if (_nameCtrl.text.trim().isEmpty) {
      await _blockingMsg('محتاج اسم', 'اكتب اسم الامتحان الأول.');
      return;
    }
    setState(() => _busy = true);
    int? id;
    String? err;
    try {
      id = await _ensureSaved(status: OnlineExamStatus.draft);
    } catch (e) {
      err = '$e';
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (!mounted) return;
    if (id != null) {
      ToastHelper.success('اتحفظ كمسودّة');
      Navigator.pop(context);
    } else if (err != null) {
      await _blockingMsg('مقدرش يحفظ', err);
    }
  }

  // رسالة واضحة لا تُفوَّت — بدل toast بيلمع ويختفي. بترجّع لما المستخدم
  // يقفلها.
  Future<void> _blockingMsg(String title, String body) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title,
            style: const TextStyle(
                fontFamily: 'Cairo', fontWeight: FontWeight.w800, fontSize: 15)),
        content: Text(body,
            style: const TextStyle(fontFamily: 'Cairo', fontSize: 13, height: 1.6)),
        actions: [
          FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('تمام', style: TextStyle(fontFamily: 'Cairo'))),
        ],
      ),
    );
  }

  // spec 023 — معاينة الامتحان كما يراه الطالب (للقراءة فقط، بلا إجابة/شرح).
  Future<void> _openPreview() async {
    final valid = _questions
        .asMap()
        .entries
        .map((e) => e.value.toModel(_examId ?? 0, e.key))
        .where((q) => q.isValid)
        .toList();
    if (valid.isEmpty) {
      await _blockingMsg('مفيش حاجة تتعرض',
          'الامتحان محتاج سؤال صالح واحد على الأقل قبل المعاينة.');
      return;
    }
    if (!mounted) return;
    Get.to(() => OnlineExamPreviewPage(
          exam: Exam(
            id: _examId,
            name: _nameCtrl.text.trim(),
            date: widget.existing?.date ?? DateTime.now(),
            durationMinutes: _durationMinutes,
          ),
          questions: valid,
        ));
  }

  List<String> _publishGaps() {
    final gaps = <String>[];
    if (_nameCtrl.text.trim().isEmpty) gaps.add('اسم الامتحان');
    if (_groupIds.isEmpty) gaps.add('اختيار مجموعة واحدة على الأقل');
    if (_questions.isEmpty) {
      gaps.add('إضافة سؤال واحد على الأقل');
    } else {
      for (var i = 0; i < _questions.length; i++) {
        final q = _questions[i];
        if (q.text.text.trim().isEmpty) {
          gaps.add('نص السؤال رقم ${i + 1}');
        }
        if (q.type == ExamQuestionType.mcq &&
            q.options.any((o) => o.text.trim().isEmpty)) {
          gaps.add('كل اختيارات السؤال رقم ${i + 1}');
        }
      }
    }
    if (_opensAt == null) gaps.add('وقت فتح الامتحان');
    if (_closesAt == null) gaps.add('وقت قفل الامتحان');
    if (_opensAt != null && _closesAt != null && !_closesAt!.isAfter(_opensAt!)) {
      gaps.add('وقت القفل لازم يكون بعد وقت الفتح');
    }
    return gaps;
  }

  Future<void> _publish() async {
    final gaps = _publishGaps();
    if (gaps.isNotEmpty) {
      await _blockingMsg('محتاج تكمّل قبل النشر',
          'الناقص:\n\n${gaps.map((g) => '•  $g').join('\n')}');
      return;
    }
    setState(() => _busy = true);
    String? err;
    int? id;
    try {
      id = await _ensureSaved(status: OnlineExamStatus.draft);
      if (id == null) return;
      // سقف نهائي — حتى لو أي استدعاء جوّه publishOnlineExam اتعلّق
      // (App Check / Auth / أي حاجة)، الزر ما يفضلش معلّق للأبد.
      err = await _ec
          .publishOnlineExam(id)
          .timeout(const Duration(seconds: 25), onTimeout: () => '__TIMEOUT__');
    } catch (e) {
      err = 'فشل النشر: $e';
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (id == null || !mounted) return;

    if (err == '__TIMEOUT__') {
      await _blockingMsg('النشر أخد وقت طويل',
          'تأكد إنك متصل بالإنترنت وإن التطبيق مسجّل دخول، وجرّب تاني.\n'
          'لو الامتحان ظهر في القايمة "منشور" يبقى تمام.');
      return;
    }
    if (err == null || err.startsWith('__WARN__')) {
      final slug = await ParentPortalService().ensureSlug();
      if (!mounted) return;
      if (err != null) {
        await _blockingMsg('تم', err.replaceFirst('__WARN__ ', ''));
      }
      if (!mounted) return;
      await _showLinkSheet(slug);
      if (mounted) Navigator.pop(context);
    } else {
      await _blockingMsg('مقدرش ينشر', err);
    }
  }

  Future<void> _showLinkSheet(String slug) {
    final link = 'active-class.online/exam/$slug';
    return showModalBottomSheet(
      context: context,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('تم النشر ✅',
              style: TextStyle(
                  fontFamily: 'Cairo', fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 6),
          const Text('ابعت الرابط ده للطلاب:',
              style: TextStyle(fontFamily: 'Cairo', fontSize: 13)),
          const SizedBox(height: 12),
          SelectableText(link,
              style: const TextStyle(
                  fontFamily: 'Cairo', fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: 'https://$link'));
              ToastHelper.success('اتنسخ');
            },
            icon: const Icon(Icons.copy_rounded, size: 18),
            label: const Text('نسخ الرابط',
                style: TextStyle(fontFamily: 'Cairo')),
          ),
        ]),
      ),
    );
  }

  Future<void> _pickDateTime(bool opens) async {
    final now = DateTime.now();
    final init = (opens ? _opensAt : _closesAt) ?? now.add(const Duration(hours: 1));
    final d = await showDatePicker(
      context: context,
      initialDate: init,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (d == null || !mounted) return;
    final t = await showTimePicker(
        context: context, initialTime: TimeOfDay.fromDateTime(init));
    if (t == null) return;
    setState(() {
      final dt = DateTime(d.year, d.month, d.day, t.hour, t.minute);
      if (opens) {
        _opensAt = dt;
      } else {
        _closesAt = dt;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('d MMM · h:mm a', 'ar');
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? 'امتحان إلكتروني جديد' : 'تعديل الامتحان',
            style: const TextStyle(
                fontFamily: 'Cairo', fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            tooltip: 'معاينة',
            icon: const Icon(Icons.visibility_outlined),
            onPressed: _openPreview,
          ),
          if (_questions.isNotEmpty)
            Center(
              child: Container(
                margin: const EdgeInsets.only(left: 12),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                    '${_questions.length} س · ${FormatHelper.formatGrade(_totalPoints)} د',
                    style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Colors.white)),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
              children: [
                if (_isPublished)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                        'الامتحان منشور. تقدر تعدّل أي سؤال وتضغط "حفظ هذا '
                        'السؤال" تحته (الامتحان يفضل شغّال). لإضافة/حذف سؤال '
                        'أو تغيير الميعاد لازم تلغي النشر الأول.',
                        style: TextStyle(fontFamily: 'Cairo', fontSize: 12)),
                  ),
                _setupCard(fmt),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor,
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: const Text('٢',
                          style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: Colors.white)),
                    ),
                    const SizedBox(width: 8),
                    Text('الأسئلة (${_questions.length})',
                        style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontWeight: FontWeight.w800,
                            fontSize: 14)),
                    const Spacer(),
                    if (_questions.isNotEmpty)
                      Text('الدرجة ${FormatHelper.formatGrade(_totalPoints)}',
                          style: TextStyle(
                              fontFamily: 'Cairo',
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                              color: AppTheme.primaryColor)),
                  ],
                ),
                const SizedBox(height: 8),
                ..._questions.asMap().entries.map((e) => _questionCard(e.key)),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _addQuestion(ExamQuestionType.mcq),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('اختيار من متعدد',
                          style: TextStyle(fontFamily: 'Cairo', fontSize: 12)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _addQuestion(ExamQuestionType.trueFalse),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('صح / خطأ',
                          style: TextStyle(fontFamily: 'Cairo', fontSize: 12)),
                    ),
                  ),
                ]),
              ],
            ),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.fromLTRB(
            16, 8, 16, 8 + MediaQuery.of(context).padding.bottom),
        child: Row(children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _busy ? null : _saveDraft,
              child: const Text('حفظ كمسودّة',
                  style: TextStyle(fontFamily: 'Cairo')),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton(
              onPressed: _busy ? null : _publish,
              style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor),
              child: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('نشر',
                      style: TextStyle(fontFamily: 'Cairo')),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _timeBtn(
      String label, DateTime? value, DateFormat fmt, VoidCallback onTap) {
    final missing = value == null;
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        foregroundColor: missing ? Colors.red.shade700 : null,
        side: BorderSide(
            color: missing
                ? Colors.red.shade400
                : Theme.of(context).colorScheme.outline),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(missing ? Icons.error_outline : Icons.check_circle, size: 13),
            const SizedBox(width: 4),
            Text(label,
                style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 11,
                    fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 2),
          Text(missing ? 'اضغط للتحديد' : fmt.format(value),
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontFamily: 'Cairo', fontSize: 11)),
        ],
      ),
    );
  }

  Widget _miniLabel(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 6, top: 2),
        child: Text(t,
            style: TextStyle(
                fontFamily: 'Cairo',
                fontWeight: FontWeight.w700,
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
      );

  // القسم ①: كل إعدادات الامتحان مجمّعة في كارت واحد بدل ما تكون
  // متفرّقة على طول الشاشة.
  Widget _setupCard(DateFormat fmt) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.onSurface.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 22,
              height: 22,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor,
                borderRadius: BorderRadius.circular(7),
              ),
              child: const Text('١',
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: Colors.white)),
            ),
            const SizedBox(width: 8),
            const Text('إعدادات الامتحان',
                style: TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.w800,
                    fontSize: 14)),
          ]),
          const SizedBox(height: 12),
          TextField(
            controller: _nameCtrl,
            style: const TextStyle(fontFamily: 'Cairo', fontSize: 14),
            decoration: const InputDecoration(
              labelText: 'اسم الامتحان',
              labelStyle: TextStyle(fontFamily: 'Cairo'),
              isDense: true,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 14),
          _miniLabel('المجموعات المسموح لها'),
          Obx(() => _GroupPickerField(
                allGroups: _gc.groups.toList(),
                selectedIds: _groupIds,
                onChanged: () => setState(() {}),
              )),
          const SizedBox(height: 14),
          _miniLabel('توقيت الامتحان (لازم الاتنين)'),
          Row(children: [
            Expanded(child: _timeBtn('يفتح', _opensAt, fmt, () => _pickDateTime(true))),
            const SizedBox(width: 8),
            Expanded(child: _timeBtn('يقفل', _closesAt, fmt, () => _pickDateTime(false))),
          ]),
          const SizedBox(height: 6),
          Row(children: [
            Text('مدة الحل: $_durationMinutes دقيقة',
                style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700)),
            Expanded(
              child: Slider(
                value: _durationMinutes.toDouble().clamp(5, 180),
                min: 5,
                max: 180,
                divisions: 35,
                label: '$_durationMinutes',
                onChanged: (v) =>
                    setState(() => _durationMinutes = v.round()),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  // صورة السؤال — مصغّرة صغيرة تحت النص لو موجودة. زر الإضافة نفسه
  // أيقونة في ترويسة الكارت (مش سطر كامل) عشان الكارت ما يطولش.
  Widget _questionImageThumb(int i, _QDraft q) {
    if (q.uploadingImage) {
      return const Padding(
        padding: EdgeInsets.only(top: 8),
        child: Row(children: [
          SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2)),
          SizedBox(width: 8),
          Text('جاري رفع الصورة...',
              style: TextStyle(fontFamily: 'Cairo', fontSize: 11.5)),
        ]),
      );
    }
    if (q.imageUrl == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              q.imageUrl!,
              height: 90,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                height: 90,
                alignment: Alignment.center,
                color: Colors.grey.withValues(alpha: 0.15),
                child: const Icon(Icons.broken_image_outlined),
              ),
            ),
          ),
          Positioned(
            top: 4,
            left: 4,
            child: GestureDetector(
              onTap: () => setState(() => _questions[i].imageUrl = null),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close,
                    size: 14, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _questionCard(int i) {
    final q = _questions[i];
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 5),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: cs.onSurface.withValues(alpha: 0.12)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 6, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('س${i + 1}',
                    style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                        color: AppTheme.primaryColor)),
              ),
              const SizedBox(width: 6),
              Text(q.type.label,
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 11,
                      color: cs.onSurface.withValues(alpha: 0.55))),
              const Spacer(),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: q.imageUrl == null ? 'إضافة صورة' : 'استبدال الصورة',
                icon: Icon(
                    q.imageUrl == null
                        ? Icons.add_photo_alternate_outlined
                        : Icons.image_rounded,
                    size: 19,
                    color: q.imageUrl == null
                        ? cs.onSurface.withValues(alpha: 0.6)
                        : AppTheme.primaryColor),
                onPressed:
                    q.uploadingImage ? null : () => _pickQuestionImage(i),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.delete_outline, size: 19),
                onPressed: () => setState(() {
                  _questions.removeAt(i).dispose();
                }),
              ),
            ]),
            TextField(
              controller: q.text,
              style: const TextStyle(fontFamily: 'Cairo', fontSize: 13),
              minLines: 1,
              maxLines: 3,
              decoration: const InputDecoration(
                  hintText: 'نص السؤال',
                  hintStyle: TextStyle(fontFamily: 'Cairo'),
                  isDense: true),
            ),
            _questionImageThumb(i, q),
            const SizedBox(height: 6),
            RadioGroup<int>(
              groupValue: q.correctIndex,
              onChanged: (v) => setState(() => q.correctIndex = v ?? 0),
              child: Column(children: [
            ...q.options.asMap().entries.map((e) {
              final idx = e.key;
              return Row(children: [
                Radio<int>(value: idx, visualDensity: VisualDensity.compact),
                Expanded(
                  child: TextField(
                    controller: e.value,
                    enabled: q.type != ExamQuestionType.trueFalse,
                    style: const TextStyle(fontFamily: 'Cairo', fontSize: 13),
                    decoration: InputDecoration(
                        hintText: 'اختيار ${idx + 1}',
                        hintStyle: const TextStyle(fontFamily: 'Cairo'),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 8)),
                  ),
                ),
                if (q.type == ExamQuestionType.mcq && q.options.length > 2)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.close, size: 15),
                    onPressed: () => setState(() {
                      q.options.removeAt(idx).dispose();
                      if (q.correctIndex >= q.options.length) {
                        q.correctIndex = 0;
                      }
                    }),
                  ),
              ]);
            }),
              ]),
            ),
            Row(children: [
              if (q.type == ExamQuestionType.mcq && q.options.length < 6)
                TextButton.icon(
                  onPressed: () => setState(
                      () => q.options.add(TextEditingController())),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('اختيار',
                      style: TextStyle(fontFamily: 'Cairo', fontSize: 12)),
                ),
              const Spacer(),
              const Text('درجة:',
                  style: TextStyle(fontFamily: 'Cairo', fontSize: 12)),
              SizedBox(
                width: 56,
                child: TextFormField(
                  key: ObjectKey(q),
                  initialValue: FormatHelper.formatGrade(q.points),
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontFamily: 'Cairo', fontSize: 13),
                  decoration: const InputDecoration(isDense: true),
                  onChanged: (v) => q.points = double.tryParse(v) ?? q.points,
                ),
              ),
            ]),
            const SizedBox(height: 6),
            // spec 023 — شرح الإجابة الصحيحة (اختياري). محلي فقط، بيوصل
            // الطالب في صفحة مراجعته بعد اعتماد المدرس.
            TextField(
              controller: q.explanation,
              style: const TextStyle(fontFamily: 'Cairo', fontSize: 12.5),
              minLines: 1,
              maxLines: 2,
              maxLength: 500,
              decoration: const InputDecoration(
                hintText: 'شرح الإجابة (اختياري)',
                hintStyle: TextStyle(fontFamily: 'Cairo'),
                helperText: 'يظهر للطالب في مراجعة إجاباته بعد اعتماد الدرجة',
                helperStyle: TextStyle(fontFamily: 'Cairo', fontSize: 10),
                isDense: true,
              ),
            ),
            // spec 022 — تعديل سؤال واحد في امتحان منشور بدون إلغاء
            // النشر. الحقول فوق قابلة للتعديل أصلاً؛ الزرار ده بيحفظ
            // السؤال ده بس ويعيد نشر مصفوفة الأسئلة، والامتحان يفضل شغّال.
            if (_isPublished && q.id != null) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _busy ? null : () => _saveQuestionLive(i),
                  style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 10)),
                  icon: const Icon(Icons.save_rounded, size: 16),
                  label: const Text('حفظ هذا السؤال',
                      style: TextStyle(fontFamily: 'Cairo', fontSize: 12.5)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// spec 022 — يحفظ تعديلات سؤال واحد في امتحان منشور فورًا، ويعيد
  /// نشر مصفوفة الأسئلة (بدون مفتاح إجابة). لو السؤال له تسليمات
  /// اتصححت، بيحذّر المدرس يعيد "تحديث النتائج" — من غير أي إعادة
  /// اعتماد تلقائي.
  Future<void> _saveQuestionLive(int i) async {
    final q = _questions[i];
    final model = q.toModel(_examId!, i);
    if (!model.isValid) {
      await _blockingMsg('السؤال ناقص',
          'تأكد إن نص السؤال والاختيارات كلها مكتوبة، والإجابة الصحيحة محدَّدة.');
      return;
    }
    setState(() => _busy = true);
    final affected = await _ec.updateQuestionAfterPublish(model);
    if (!mounted) return;
    setState(() => _busy = false);
    if (affected > 0) {
      await _blockingMsg(
          'اتحفظ — بس انتبه',
          'فيه $affected تسليم اتصحّح بالإجابة القديمة. روح شاشة "النتائج" '
              'واضغط "تحديث النتائج" عشان الدرجات تتحسب بالإجابة الجديدة. '
              'الاعتماد نفسه مش هيتغيّر تلقائيًا.');
    } else {
      ToastHelper.success('اتحفظ السؤال');
    }
  }
}

// ── منتقي المجموعات (قايمة منسدلة بدل شرائح) ─────────────────────────────
class _GroupPickerField extends StatelessWidget {
  final List<Group> allGroups;
  final Set<int> selectedIds;
  final VoidCallback onChanged;
  const _GroupPickerField({
    required this.allGroups,
    required this.selectedIds,
    required this.onChanged,
  });

  String get _summary {
    if (allGroups.isEmpty) return 'مفيش مجموعات';
    final names = allGroups
        .where((g) => selectedIds.contains(g.id))
        .map((g) => g.name)
        .toList();
    if (names.isEmpty) return 'اضغط لاختيار المجموعات';
    if (names.length == 1) return names.first;
    if (names.length <= 2) return names.join('، ');
    return '${names.length} مجموعات: ${names.take(2).join('، ')}…';
  }

  Future<void> _open(BuildContext context) async {
    if (allGroups.isEmpty) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: StatefulBuilder(
          builder: (ctx, setSheet) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 14, 16, 6),
                child: Text('المجموعات المسموح لها بالامتحان',
                    style: TextStyle(
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.w800,
                        fontSize: 14)),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: allGroups.map((g) {
                    final on = selectedIds.contains(g.id);
                    return CheckboxListTile(
                      dense: true,
                      value: on,
                      title: Text(g.name,
                          style: const TextStyle(fontFamily: 'Cairo', fontSize: 13)),
                      onChanged: (v) {
                        if (v == true) {
                          selectedIds.add(g.id!);
                        } else {
                          selectedIds.remove(g.id);
                        }
                        setSheet(() {});
                        onChanged();
                      },
                    );
                  }).toList(),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('تم', style: TextStyle(fontFamily: 'Cairo')),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final empty = selectedIds.isEmpty;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => _open(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: empty
                  ? Colors.red.shade300
                  : cs.outline.withValues(alpha: 0.6)),
        ),
        child: Row(children: [
          Icon(Icons.groups_rounded,
              size: 18,
              color: empty ? Colors.red.shade400 : AppTheme.primaryColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(_summary,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 13,
                    color: empty ? Colors.red.shade700 : cs.onSurface)),
          ),
          Icon(Icons.arrow_drop_down_rounded,
              color: cs.onSurface.withValues(alpha: 0.5)),
        ]),
      ),
    );
  }
}
