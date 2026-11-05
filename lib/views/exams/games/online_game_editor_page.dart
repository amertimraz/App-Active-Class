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
import 'package:active_class/views/question_bank/question_bank_picker_page.dart';
import 'package:active_class/widgets/app_chrome.dart';
import 'package:active_class/widgets/app_panel.dart';

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
  const OnlineGameEditorPage({super.key});

  @override
  State<OnlineGameEditorPage> createState() => _OnlineGameEditorPageState();
}

class _OnlineGameEditorPageState extends State<OnlineGameEditorPage> {
  final _title = TextEditingController();
  final _ec = Get.find<ExamController>();
  final _gc = Get.isRegistered<GroupController>()
      ? Get.find<GroupController>()
      : Get.put(GroupController());

  OnlineGameType _type = OnlineGameType.race;
  int _seconds = OnlineGameType.race.defaultSeconds;
  final Set<String> _groups = {};
  List<GameQuestion> _questions = [];
  bool _publishing = false;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  void _setType(OnlineGameType t) {
    setState(() {
      // لو الوقت لسه على افتراضي النوع القديم، حوّله لافتراضي النوع الجديد.
      if (_seconds == _type.defaultSeconds) _seconds = t.defaultSeconds;
      _type = t;
    });
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

  Future<void> _publish() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      ToastHelper.error('اكتب اسم اللعبة');
      return;
    }
    if (_questions.length < kGameMinQuestions) {
      ToastHelper.error('ضيف $kGameMinQuestions أسئلة على الأقل');
      return;
    }
    setState(() => _publishing = true);
    try {
      final svc = OnlineGameService();
      final id = await svc.publish(
        title: title,
        type: _type,
        secondsPerQuestion: _seconds,
        allowedGroupNames: _groups.toList(),
        questions: _questions,
      );
      final slug = await svc.slug();
      if (!mounted) return;
      ToastHelper.success('اتنشرت اللعبة');
      Get.back(result: OnlineGameService.linkFor(slug, id));
    } catch (e) {
      if (mounted) setState(() => _publishing = false);
      ToastHelper.error('تعذّر النشر — تأكد من اتصالك بالإنترنت');
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
        child: FilledButton.icon(
          onPressed: _publishing ? null : _publish,
          style: FilledButton.styleFrom(minimumSize: const Size(0, 52)),
          icon: _publishing
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.rocket_launch_rounded),
          label: Text(_publishing ? 'جاري النشر...' : 'انشر اللعبة'),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpace.lg),
        children: [
          _label(t, 'اسم اللعبة'),
          TextField(
            controller: _title,
            textInputAction: TextInputAction.next,
            decoration:
                const InputDecoration(hintText: 'مثال: مراجعة الباب الأول'),
          ),
          const SizedBox(height: AppSpace.xl),
          _label(t, 'نوع اللعبة'),
          for (final ty in OnlineGameType.values)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpace.sm),
              child: _TypeCard(
                type: ty,
                selected: _type == ty,
                onTap: () => _setType(ty),
              ),
            ),
          const SizedBox(height: AppSpace.lg),
          _label(t, 'الوقت لكل سؤال'),
          Wrap(
            spacing: AppSpace.sm,
            children: [
              for (final s in const [10, 15, 20, 30, 45])
                ChoiceChip(
                  label: Text('$s ث'),
                  selected: _seconds == s,
                  onSelected: (_) => setState(() => _seconds = s),
                ),
            ],
          ),
          const SizedBox(height: AppSpace.xl),
          _label(t, 'لمين؟'),
          Text(
              _groups.isEmpty
                  ? 'كل الطلاب اللي معاهم كود'
                  : 'طلاب المجموعات المختارة بس',
              style: AppType.caption.copyWith(color: t.inkFaint)),
          const SizedBox(height: AppSpace.sm),
          Obx(() => Wrap(
                spacing: AppSpace.sm,
                runSpacing: AppSpace.xs,
                children: [
                  for (final g in _gc.groups)
                    FilterChip(
                      label: Text(g.name),
                      selected: _groups.contains(g.name),
                      onSelected: (v) => setState(() =>
                          v ? _groups.add(g.name) : _groups.remove(g.name)),
                    ),
                ],
              )),
          const SizedBox(height: AppSpace.xl),
          Row(children: [
            Expanded(child: _label(t, 'الأسئلة (${_questions.length})')),
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
                        padding: const EdgeInsetsDirectional.only(
                            end: AppSpace.sm),
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

class _TypeCard extends StatelessWidget {
  final OnlineGameType type;
  final bool selected;
  final VoidCallback onTap;
  const _TypeCard(
      {required this.type, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return AppPanel(
      onTap: onTap,
      lineColor: selected ? t.brand : null,
      child: Row(children: [
        Icon(
            type == OnlineGameType.race
                ? Icons.rocket_launch_rounded
                : Icons.balance_rounded,
            color: selected ? t.brand : t.inkFaint,
            size: 26),
        const SizedBox(width: AppSpace.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(type.title, style: AppType.label.copyWith(color: t.ink)),
              Text(type.description,
                  style: AppType.caption.copyWith(color: t.inkFaint)),
            ],
          ),
        ),
        Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off,
            color: selected ? t.brand : t.inkFaint),
      ]),
    );
  }
}
