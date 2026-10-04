// lib/views/question_bank/question_editor_sheet.dart
//
// spec 025 — محرّر سؤال بنك (bottom sheet). يرجّع BankQuestion محرَّرة
// عند الحفظ، أو null عند الإلغاء. نفس حقول سؤال الامتحان (نص/صورة/
// اختيارات/إجابة صحيحة/درجة/شرح/نوع) + مادة + وسوم.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:active_class/widgets/image_crop_picker.dart';

import 'package:active_class/controllers/exam_controller.dart';
import 'package:active_class/models/bank_question_model.dart';
import 'package:active_class/models/exam_question_model.dart';
import 'package:active_class/utils/helpers.dart';

/// يفتح المحرّر ويرجّع السؤال المحرَّر أو null.
Future<BankQuestion?> showBankQuestionEditor(
  BuildContext context, {
  BankQuestion? initial,
  List<String> subjectSuggestions = const [],
}) {
  return showModalBottomSheet<BankQuestion>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _QuestionEditorSheet(
      initial: initial,
      subjectSuggestions: subjectSuggestions,
    ),
  );
}

class _QuestionEditorSheet extends StatefulWidget {
  final BankQuestion? initial;
  final List<String> subjectSuggestions;
  const _QuestionEditorSheet({this.initial, required this.subjectSuggestions});

  @override
  State<_QuestionEditorSheet> createState() => _QuestionEditorSheetState();
}

class _QuestionEditorSheetState extends State<_QuestionEditorSheet> {
  final _ec = Get.isRegistered<ExamController>()
      ? Get.find<ExamController>()
      : Get.put(ExamController());

  late ExamQuestionType _type;
  late final TextEditingController _text;
  late final TextEditingController _explanation;
  late final TextEditingController _subject;
  late final TextEditingController _tags;
  late List<TextEditingController> _options;
  int _correctIndex = 0;
  double _points = 1;
  String? _imageUrl;
  bool _uploading = false;

  // spec 043 — صورة شرح (محلية فقط) + صورة لكل اختيار (بنفس طول _options).
  String? _explanationImageUrl;
  bool _uploadingExplanationImage = false;
  List<String?> _optionImageUrls = [];
  List<bool> _uploadingOptionImage = [];

  @override
  void initState() {
    super.initState();
    final q = widget.initial;
    _type = q?.type ?? ExamQuestionType.mcq;
    _text = TextEditingController(text: q?.text ?? '');
    _explanation = TextEditingController(text: q?.explanation ?? '');
    _subject = TextEditingController(text: q?.subject ?? '');
    _tags = TextEditingController(text: (q?.tags ?? const []).join('، '));
    _correctIndex = q?.correctIndex ?? 0;
    _points = q?.points ?? 1;
    _imageUrl = q?.imageUrl;
    _explanationImageUrl = q?.explanationImageUrl;
    final opts = q?.options ??
        (_type == ExamQuestionType.trueFalse ? kTrueFalseOptions : const ['', '']);
    _options = opts.map((o) => TextEditingController(text: o)).toList();
    _optionImageUrls = alignOptionImages(
        q?.optionImageUrls ?? const [], _options.length);
    _uploadingOptionImage = List<bool>.filled(_options.length, false);
  }

  @override
  void dispose() {
    _text.dispose();
    _explanation.dispose();
    _subject.dispose();
    _tags.dispose();
    for (final o in _options) {
      o.dispose();
    }
    super.dispose();
  }

  void _setType(ExamQuestionType t) {
    setState(() {
      _type = t;
      if (t == ExamQuestionType.trueFalse) {
        for (final o in _options) {
          o.dispose();
        }
        _options =
            kTrueFalseOptions.map((o) => TextEditingController(text: o)).toList();
        if (_correctIndex > 1) _correctIndex = 0;
        // spec 043 — الاختيارات القديمة اتمسحت بالكامل، فصورها بقت بلا
        // معنى (ممكن تتحط بالغلط على "صح/خطأ" لو سبنا الطول القديم).
        _optionImageUrls = List<String?>.filled(_options.length, null);
        _uploadingOptionImage = List<bool>.filled(_options.length, false);
      }
    });
  }

  Future<void> _pickImage() async {
    final bytes = await pickAndCropImage(context);
    if (bytes == null || !mounted) return;
    setState(() => _uploading = true);
    final url = await _ec.uploadQuestionImage(0, bytes);
    if (!mounted) return;
    setState(() {
      _uploading = false;
      if (url != null) {
        _imageUrl = url;
      } else {
        ToastHelper.error('تعذّر رفع الصورة — حاول تاني');
      }
    });
  }

  Future<void> _pickExplanationImage() async {
    final bytes = await pickAndCropImage(context, maxDimension: 1000, compressQuality: 78);
    if (bytes == null || !mounted) return;
    setState(() => _uploadingExplanationImage = true);
    final url = await _ec.uploadQuestionImage(0, bytes);
    if (!mounted) return;
    setState(() {
      _uploadingExplanationImage = false;
      if (url != null) {
        _explanationImageUrl = url;
      } else {
        ToastHelper.error('تعذّر رفع الصورة — حاول تاني');
      }
    });
  }

  Future<void> _pickOptionImage(int idx) async {
    final bytes = await pickAndCropImage(context, maxDimension: 640, compressQuality: 75);
    if (bytes == null || !mounted) return;
    setState(() => _uploadingOptionImage[idx] = true);
    final url = await _ec.uploadQuestionImage(0, bytes);
    if (!mounted) return;
    setState(() {
      _uploadingOptionImage[idx] = false;
      if (url != null) {
        _optionImageUrls[idx] = url;
      } else {
        ToastHelper.error('تعذّر رفع الصورة — حاول تاني');
      }
    });
  }

  void _addOption() {
    setState(() {
      _options.add(TextEditingController());
      _optionImageUrls = addOptionImageSlot(_optionImageUrls);
      _uploadingOptionImage = [..._uploadingOptionImage, false];
    });
  }

  void _removeOptionAt(int idx) {
    setState(() {
      _options.removeAt(idx).dispose();
      _optionImageUrls = removeOptionImageSlot(_optionImageUrls, idx);
      _uploadingOptionImage = [..._uploadingOptionImage]..removeAt(idx);
      if (_correctIndex >= _options.length) _correctIndex = 0;
    });
  }

  BankQuestion _build() {
    final tags = _tags.text
        .split(RegExp(r'[،,]'))
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();
    return BankQuestion(
      id: widget.initial?.id,
      type: _type,
      text: _text.text.trim(),
      options: _options.map((o) => o.text.trim()).toList(),
      correctIndex: _correctIndex,
      points: _points,
      imageUrl: _imageUrl,
      explanation:
          _explanation.text.trim().isEmpty ? null : _explanation.text.trim(),
      explanationImageUrl: _explanationImageUrl,
      optionImageUrls: _optionImageUrls,
      subject: _subject.text.trim(),
      tags: tags,
    );
  }

  void _save() {
    final q = _build();
    if (!q.isValid) {
      ToastHelper.error('السؤال ناقص — تأكد من النص والاختيارات والإجابة الصحيحة');
      return;
    }
    Navigator.pop(context, q);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.9,
        maxChildSize: 0.95,
        builder: (_, scrollCtrl) => Column(
          children: [
            const SizedBox(height: 8),
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: cs.onSurface.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
              child: Row(children: [
                Text(widget.initial == null ? 'سؤال جديد' : 'تعديل السؤال',
                    style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.w800,
                        fontSize: 15)),
                const Spacer(),
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('إلغاء',
                        style: TextStyle(fontFamily: 'Cairo'))),
                FilledButton(
                    onPressed: _uploading ? null : _save,
                    child: const Text('حفظ',
                        style: TextStyle(fontFamily: 'Cairo'))),
              ]),
            ),
            Expanded(
              child: ListView(
                controller: scrollCtrl,
                // padding سفلي = ارتفاع الكيبورد عشان آخر الحقول تفضل
                // ظاهرة وقابلة للتمرير فوقه.
                padding: EdgeInsets.fromLTRB(
                    16, 0, 16, 24 + MediaQuery.of(context).viewInsets.bottom),
                children: [
                  // النوع
                  SegmentedButton<ExamQuestionType>(
                    segments: const [
                      ButtonSegment(
                          value: ExamQuestionType.mcq,
                          label: Text('اختيار من متعدد',
                              style: TextStyle(fontFamily: 'Cairo', fontSize: 12))),
                      ButtonSegment(
                          value: ExamQuestionType.trueFalse,
                          label: Text('صح / خطأ',
                              style: TextStyle(fontFamily: 'Cairo', fontSize: 12))),
                    ],
                    selected: {_type},
                    onSelectionChanged: (s) => _setType(s.first),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _text,
                    minLines: 1,
                    maxLines: 3,
                    style: const TextStyle(fontFamily: 'Cairo', fontSize: 13),
                    decoration: const InputDecoration(
                        labelText: 'نص السؤال',
                        labelStyle: TextStyle(fontFamily: 'Cairo')),
                  ),
                  const SizedBox(height: 10),
                  // صورة
                  Row(children: [
                    OutlinedButton.icon(
                      onPressed: _uploading ? null : _pickImage,
                      icon: _uploading
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : Icon(_imageUrl == null
                              ? Icons.add_photo_alternate_outlined
                              : Icons.check_circle,
                              size: 16),
                      label: Text(_imageUrl == null ? 'إضافة صورة' : 'تغيير الصورة',
                          style: const TextStyle(fontFamily: 'Cairo', fontSize: 12)),
                    ),
                    if (_imageUrl != null)
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 18),
                        onPressed: () => setState(() => _imageUrl = null),
                      ),
                  ]),
                  if (_imageUrl != null) ...[
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(_imageUrl!,
                          height: 110,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const SizedBox()),
                    ),
                  ],
                  const SizedBox(height: 12),
                  // الاختيارات
                  RadioGroup<int>(
                    groupValue: _correctIndex,
                    onChanged: (v) => setState(() => _correctIndex = v ?? 0),
                    child: Column(children: [
                  ..._options.asMap().entries.map((e) {
                    final idx = e.key;
                    final optImg = idx < _optionImageUrls.length
                        ? _optionImageUrls[idx]
                        : null;
                    final optUploading = idx < _uploadingOptionImage.length &&
                        _uploadingOptionImage[idx];
                    return Row(children: [
                      Radio<int>(
                        value: idx,
                        visualDensity: VisualDensity.compact,
                      ),
                      Expanded(
                        child: TextField(
                          controller: e.value,
                          enabled: _type != ExamQuestionType.trueFalse,
                          style:
                              const TextStyle(fontFamily: 'Cairo', fontSize: 13),
                          decoration: InputDecoration(
                              hintText: 'اختيار ${idx + 1}',
                              hintStyle: const TextStyle(fontFamily: 'Cairo'),
                              isDense: true),
                        ),
                      ),
                      if (optUploading)
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4),
                          child: SizedBox(
                              width: 14,
                              height: 14,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2)),
                        )
                      else if (optImg != null) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.network(optImg,
                              width: 28,
                              height: 28,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                  width: 28,
                                  height: 28,
                                  color: Colors.grey.withValues(alpha: 0.15),
                                  child: const Icon(
                                      Icons.broken_image_outlined,
                                      size: 14))),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.close, size: 14),
                          onPressed: () =>
                              setState(() => _optionImageUrls[idx] = null),
                        ),
                      ] else
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          tooltip: 'صورة الاختيار',
                          icon: const Icon(Icons.add_photo_alternate_outlined,
                              size: 17),
                          onPressed: () => _pickOptionImage(idx),
                        ),
                      if (_type == ExamQuestionType.mcq && _options.length > 2)
                        IconButton(
                          icon: const Icon(Icons.close, size: 15),
                          visualDensity: VisualDensity.compact,
                          onPressed: () => _removeOptionAt(idx),
                        ),
                    ]);
                  }),
                    ]),
                  ),
                  if (_type == ExamQuestionType.mcq && _options.length < 6)
                    TextButton.icon(
                      onPressed: _addOption,
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('اختيار',
                          style: TextStyle(fontFamily: 'Cairo', fontSize: 12)),
                    ),
                  const SizedBox(height: 8),
                  Row(children: [
                    const Text('الدرجة:',
                        style: TextStyle(fontFamily: 'Cairo', fontSize: 12)),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 60,
                      child: TextFormField(
                        initialValue: FormatHelper.formatGrade(_points),
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontFamily: 'Cairo', fontSize: 13),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
                        ],
                        onChanged: (v) =>
                            _points = double.tryParse(v) ?? _points,
                      ),
                    ),
                  ]),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _explanation,
                    minLines: 1,
                    maxLines: 2,
                    maxLength: 500,
                    style: const TextStyle(fontFamily: 'Cairo', fontSize: 12.5),
                    decoration: const InputDecoration(
                        hintText: 'شرح الإجابة (اختياري)',
                        hintStyle: TextStyle(fontFamily: 'Cairo'),
                        isDense: true),
                  ),
                  if (_uploadingExplanationImage)
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Row(children: [
                        SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(strokeWidth: 2)),
                        SizedBox(width: 6),
                        Text('جاري رفع صورة الشرح...',
                            style: TextStyle(fontFamily: 'Cairo', fontSize: 11)),
                      ]),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(children: [
                        if (_explanationImageUrl != null) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Image.network(_explanationImageUrl!,
                                height: 36,
                                width: 48,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                    height: 36,
                                    width: 48,
                                    color:
                                        Colors.grey.withValues(alpha: 0.15),
                                    child: const Icon(
                                        Icons.broken_image_outlined,
                                        size: 16))),
                          ),
                          const SizedBox(width: 6),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(Icons.close, size: 15),
                            onPressed: () =>
                                setState(() => _explanationImageUrl = null),
                          ),
                        ] else
                          TextButton.icon(
                            onPressed: _pickExplanationImage,
                            icon: const Icon(
                                Icons.add_photo_alternate_outlined,
                                size: 15),
                            label: const Text('صورة للشرح',
                                style: TextStyle(
                                    fontFamily: 'Cairo', fontSize: 11.5)),
                          ),
                      ]),
                    ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _subject,
                    maxLength: 60,
                    style: const TextStyle(fontFamily: 'Cairo', fontSize: 13),
                    decoration: const InputDecoration(
                        labelText: 'المادة / الموضوع',
                        labelStyle: TextStyle(fontFamily: 'Cairo'),
                        isDense: true),
                  ),
                  if (widget.subjectSuggestions.isNotEmpty)
                    Wrap(
                      spacing: 6,
                      children: [
                        for (final s in widget.subjectSuggestions.take(8))
                          ActionChip(
                            label: Text(s,
                                style: const TextStyle(
                                    fontFamily: 'Cairo', fontSize: 10.5)),
                            visualDensity: VisualDensity.compact,
                            onPressed: () => setState(() => _subject.text = s),
                          ),
                      ],
                    ),
                  TextField(
                    controller: _tags,
                    style: const TextStyle(fontFamily: 'Cairo', fontSize: 13),
                    decoration: const InputDecoration(
                        labelText: 'وسوم (اختياري، افصل بفاصلة)',
                        labelStyle: TextStyle(fontFamily: 'Cairo'),
                        isDense: true),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
