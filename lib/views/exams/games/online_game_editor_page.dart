// lib/views/exams/games/online_game_editor_page.dart
//
// إنشاء لعبة: الاسم + نوع اللعبة + الوقت + المجموعات + الأسئلة (من بنك
// الأسئلة أو من امتحان إلكتروني). النشر بيكتب مستند اللعبة على Firestore
// ويرجّع الرابط.
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:active_class/config/theme.dart';
import 'package:active_class/controllers/exam_controller.dart';
import 'package:active_class/controllers/group_controller.dart';
import 'package:active_class/models/bank_question_model.dart';
import 'package:active_class/models/online_game_model.dart';
import 'package:active_class/services/online_game_service.dart';
import 'package:active_class/utils/helpers.dart';
import 'package:active_class/views/exams/games/game_type_picker_page.dart';
import 'package:active_class/views/question_bank/question_bank_picker_page.dart';
import 'package:active_class/widgets/app_chrome.dart';
import 'package:active_class/widgets/app_panel.dart';
import 'package:active_class/widgets/group_multi_select_field.dart';

/// أقل/أكبر عدد أسئلة للعبة (أقل من 3 مش لعبة، وأكتر من 50 بيطوّل المستند).
const int kGameMinQuestions = 3;
const int kGameMaxQuestions = 50;

/// بيضيف [incoming] على [current] من غير تكرار (نفس نص السؤال) وبحد أقصى
/// [kGameMaxQuestions]. بيرجّع القائمة الجديدة.
List<GameQuestion> mergeGameQuestions(
    List<GameQuestion> current, Iterable<GameQuestion> incoming) {
  final out = List<GameQuestion>.of(current);
  final seen = {for (final q in out) q.text.trim()};
  for (final q in incoming) {
    if (out.length >= kGameMaxQuestions) break;
    if (!q.isValid || !seen.add(q.text.trim())) continue;
    out.add(q);
  }
  return out;
}

class OnlineGameEditorPage extends StatefulWidget {
  /// الشكل اللي اتختار من كروت الألعاب (الخطوة الأولى).
  final OnlineGameType type;
  const OnlineGameEditorPage({super.key, required this.type});

  @override
  State<OnlineGameEditorPage> createState() => _OnlineGameEditorPageState();
}

class _OnlineGameEditorPageState extends State<OnlineGameEditorPage> {
  final _title = TextEditingController();
  final _ec = Get.find<ExamController>();
  final _gc = Get.isRegistered<GroupController>()
      ? Get.find<GroupController>()
      : Get.put(GroupController());

  OnlineGameType get _type => widget.type;
  late int _seconds = widget.type.defaultSeconds;
  final Set<int> _groupIds = {};
  List<GameQuestion> _questions = [];
  bool _publishing = false;
  // بعد أول محاولة نشر ناقصة: بنبرّز الناقص بالأحمر ونودّي المستخدم له.
  bool _tried = false;
  // آخر خطأ نشر بنصّه الحقيقي — بنعرضه جوّه الشاشة (التوست ممكن ما يبانش).
  String? _error;
  final _scroll = ScrollController();
  final _titleKey = GlobalKey();
  final _questionsKey = GlobalKey();

  @override
  void dispose() {
    _scroll.dispose();
    _title.dispose();
    super.dispose();
  }

  Future<void> _addFromBank() async {
    final res =
        await Get.to<List<BankQuestion>>(() => const QuestionBankPickerPage());
    if (res == null || res.isEmpty) return;
    final before = _questions.length;
    setState(() => _questions =
        mergeGameQuestions(_questions, res.map(GameQuestion.fromBank)));
    final added = _questions.length - before;
    ToastHelper.info(added == res.length
        ? 'اتضافت $added سؤال'
        : 'اتضافت $added سؤال (الباقي مكرّر أو فوق الحد)');
  }

  Future<void> _addFromExam() async {
    final exams = _ec.onlineExams.where((e) => e.id != null).toList();
    if (exams.isEmpty) {
      ToastHelper.info('مفيش امتحانات إلكترونية لسه');
      return;
    }
    final t = context.tokens;
    final picked = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: t.surface,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(
              AppSpace.lg, 0, AppSpace.lg, AppSpace.lg),
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpace.sm),
              child: Text('اختار الامتحان',
                  style: AppType.title.copyWith(color: t.ink)),
            ),
            for (final e in exams)
              ListTile(
                title: Text(e.name),
                trailing: const Icon(Icons.chevron_left_rounded),
                onTap: () => Navigator.of(context).pop(e.id),
              ),
          ],
        ),
      ),
    );
    if (picked == null) return;
    final qs = await _ec.getQuestions(picked);
    if (qs.isEmpty) {
      ToastHelper.info('الامتحان ده مفيهوش أسئلة');
      return;
    }
    final before = _questions.length;
    setState(() => _questions =
        mergeGameQuestions(_questions, qs.map(GameQuestion.fromExam)));
    ToastHelper.info('اتضافت ${_questions.length - before} سؤال');
  }

  /// نص الوقت: «45 ث» أو «1:30 د» لما يعدّي الدقيقة.
  String _secondsLabel(int s) =>
      s < 60 ? '$s ث' : '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')} د';

  /// الناقص قبل النشر (فاضي = جاهزة).
  List<String> _missing() => [
        if (_title.text.trim().isEmpty) 'اسم اللعبة',
        if (_questions.length < kGameMinQuestions)
          '${kGameMinQuestions - _questions.length} سؤال كمان',
      ];

  void _reveal(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx,
          duration: const Duration(milliseconds: 300), alignment: 0.1);
    }
  }

  Future<void> _publish() async {
    final missing = _missing();
    if (missing.isNotEmpty) {
      setState(() => _tried = true);
      ToastHelper.error('ناقص: ${missing.join(' و')}');
      _reveal(_title.text.trim().isEmpty ? _titleKey : _questionsKey);
      return;
    }
    final title = _title.text.trim();
    setState(() {
      _publishing = true;
      _error = null;
    });
    try {
      final svc = OnlineGameService();
      final id = await svc
          .publish(
            title: title,
            type: _type,
            secondsPerQuestion: _seconds,
            allowedGroupNames: [
          for (final g in _gc.groups)
            if (_groupIds.contains(g.id)) g.name
        ],
            questions: _questions,
          )
          .timeout(const Duration(seconds: 40));
      final slug = await svc.slug();
      if (!mounted) return;
      ToastHelper.success('اتنشرت اللعبة');
      Get.back(result: OnlineGameService.linkFor(slug, id));
    } catch (e) {
      debugPrint('OnlineGameEditor.publish failed — $e');
      if (mounted) {
        setState(() {
          _publishing = false;
          _error = e.toString();
        });
      }
      ToastHelper.error('تعذّر النشر — راجع الرسالة تحت');
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      backgroundColor: t.page,
      appBar: buildBoardAppBar(context, title: 'لعبة جديدة'),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.fromLTRB(
            AppSpace.lg, AppSpace.sm, AppSpace.lg, AppSpace.md + bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_error != null)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: AppSpace.sm),
                padding: const EdgeInsets.all(AppSpace.md),
                decoration: BoxDecoration(
                  color: t.dangerSoft,
                  borderRadius: BorderRadius.circular(AppRadius.control),
                ),
                child: SelectableText('تعذّر النشر:\n$_error',
                    maxLines: 6,
                    textDirection: TextDirection.ltr,
                    style: AppType.caption
                        .copyWith(color: const Color(0xFF14172B))),
              ),
            if (_missing().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpace.sm),
                child: Text('ناقص: ${_missing().join(' و')}',
                    textAlign: TextAlign.center,
                    style: AppType.body.copyWith(
                        fontWeight: FontWeight.w700,
                        color: _tried ? t.danger : t.inkFaint)),
              ),
            FilledButton.icon(
              onPressed: _publishing ? null : _publish,
              style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52)),
              icon: _publishing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.rocket_launch_rounded),
              label: Text(_publishing ? 'جاري النشر...' : 'انشر اللعبة'),
            ),
          ],
        ),
      ),
      body: ListView(
        controller: _scroll,
        padding: const EdgeInsets.all(AppSpace.lg),
        children: [
          KeyedSubtree(key: _titleKey, child: _label(t, 'اسم اللعبة')),
          TextField(
            controller: _title,
            onChanged: (_) => setState(() {}),
            textInputAction: TextInputAction.next,
            decoration:
                const InputDecoration(hintText: 'مثال: مراجعة الباب الأول'),
          ),
          const SizedBox(height: AppSpace.xl),
          _TypeBanner(type: _type, onChange: () => Get.back()),
          const SizedBox(height: AppSpace.xl),
          _label(t, 'الوقت لكل سؤال'),
          AppPanel(
            padding: const EdgeInsets.fromLTRB(
                AppSpace.md, AppSpace.sm, AppSpace.md, AppSpace.md),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton.filledTonal(
                      tooltip: 'أقل',
                      onPressed: _seconds > kGameMinSeconds
                          ? () => setState(() => _seconds--)
                          : null,
                      icon: const Icon(Icons.remove_rounded),
                    ),
                    SizedBox(
                      width: 120,
                      child: Text(_secondsLabel(_seconds),
                          textAlign: TextAlign.center,
                          style: AppType.figure.copyWith(color: t.brand)),
                    ),
                    IconButton.filledTonal(
                      tooltip: 'أكتر',
                      onPressed: _seconds < kGameMaxSeconds
                          ? () => setState(() => _seconds++)
                          : null,
                      icon: const Icon(Icons.add_rounded),
                    ),
                  ],
                ),
                Slider(
                  value: _seconds.toDouble(),
                  min: kGameMinSeconds.toDouble(),
                  max: kGameMaxSeconds.toDouble(),
                  divisions: kGameMaxSeconds - kGameMinSeconds,
                  label: '$_seconds ث',
                  onChanged: (v) => setState(() => _seconds = v.round()),
                ),
                Wrap(
                  spacing: AppSpace.sm,
                  children: [
                    for (final s in const [10, 15, 20, 30, 45, 60, 90])
                      ChoiceChip(
                        label: Text('$s ث'),
                        selected: _seconds == s,
                        onSelected: (_) => setState(() => _seconds = s),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.xl),
          _label(t, 'لمين؟'),
          Text(
              _groupIds.isEmpty
                  ? 'كل الطلاب اللي معاهم كود'
                  : 'طلاب المجموعات المختارة بس',
              style: AppType.caption.copyWith(color: t.inkFaint)),
          const SizedBox(height: AppSpace.sm),
          Obx(() => GroupMultiSelectField(
                groups: _gc.groups.toList(),
                selected: _groupIds,
                title: 'اللعبة لمجموعات مين؟',
                emptyHint: 'كل الطلاب (اضغط لاختيار مجموعات)',
                onChanged: (ids) => setState(() {
                  _groupIds
                    ..clear()
                    ..addAll(ids);
                }),
              )),
          const SizedBox(height: AppSpace.xl),
          Row(key: _questionsKey, children: [
            Expanded(
                child: _label(t,
                    'الأسئلة (${_questions.length} من $kGameMinQuestions على الأقل)')),
            if (_questions.isNotEmpty)
              TextButton(
                  onPressed: () => setState(() => _questions = []),
                  child: const Text('مسح الكل')),
          ]),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _addFromBank,
                icon: const Icon(Icons.library_books_rounded, size: 18),
                label: const Text('من البنك'),
              ),
            ),
            const SizedBox(width: AppSpace.md),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _addFromExam,
                icon: const Icon(Icons.wifi_tethering_rounded, size: 18),
                label: const Text('من امتحان'),
              ),
            ),
          ]),
          const SizedBox(height: AppSpace.md),
          if (_questions.isEmpty)
            AppPanel(
              child: Text(
                  'ضيف $kGameMinQuestions أسئلة على الأقل من البنك أو من '
                  'امتحان إلكتروني.',
                  textAlign: TextAlign.center,
                  style: AppType.body.copyWith(color: t.inkSoft)),
            )
          else
            for (var i = 0; i < _questions.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpace.sm),
                child: AppPanel(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpace.md, vertical: AppSpace.sm),
                  child: Row(children: [
                    Text('${i + 1}',
                        style: AppType.label.copyWith(color: t.inkFaint)),
                    const SizedBox(width: AppSpace.md),
                    if (_questions[i].hasImages)
                      Padding(
                        padding:
                            const EdgeInsetsDirectional.only(end: AppSpace.sm),
                        child: Tooltip(
                          message: 'السؤال فيه صور',
                          child: Icon(Icons.image_outlined,
                              size: 18, color: t.inkFaint),
                        ),
                      ),
                    Expanded(
                      child: Text(_questions[i].text,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppType.body.copyWith(color: t.ink)),
                    ),
                    IconButton(
                      tooltip: 'شيل السؤال',
                      icon: Icon(Icons.close_rounded, color: t.inkSoft),
                      onPressed: () => setState(
                          () => _questions = List.of(_questions)..removeAt(i)),
                    ),
                  ]),
                ),
              ),
          const SizedBox(height: AppSpace.md),
          Text(
              'ملحوظة: إجابات اللعبة بتتحمّل مع الصفحة عشان الرد يبقى فوري، '
              'فاللعبة للمراجعة والتحفيز مش للتقييم — ومفيش درجة بتتسجّل في '
              'سجل الطالب.',
              style: AppType.caption.copyWith(color: t.inkFaint)),
        ],
      ),
    );
  }

  Widget _label(AppTokens t, String text) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpace.sm),
        child: Text(text, style: AppType.label.copyWith(color: t.ink)),
      );
}

/// شكل اللعبة المختار فوق المحرّر، مع رجوع لتغييره.
class _TypeBanner extends StatelessWidget {
  final OnlineGameType type;
  final VoidCallback onChange;
  const _TypeBanner({required this.type, required this.onChange});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpace.md + 2),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gameTypeGradient(type),
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(AppRadius.panel),
      ),
      child: Row(children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.22),
            borderRadius: BorderRadius.circular(AppRadius.control),
          ),
          child: Icon(gameTypeIcon(type), color: Colors.white, size: 26),
        ),
        const SizedBox(width: AppSpace.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(type.title,
                  style: AppType.label.copyWith(color: Colors.white)),
              Text(type.description,
                  style: AppType.caption
                      .copyWith(color: Colors.white.withValues(alpha: 0.9))),
            ],
          ),
        ),
        TextButton(
          onPressed: onChange,
          style: TextButton.styleFrom(foregroundColor: Colors.white),
          child: const Text('تغيير'),
        ),
      ]),
    );
  }
}
