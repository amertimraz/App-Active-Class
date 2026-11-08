// lib/tour/tour.dart
//
// «جرّبها بنفسك»: جولة تفاعلية فوق الشاشات الحقيقية. الشاشة بتضلّم وبتنوّر
// على الزرار المطلوب وفقاعة طباشير بتقول تعمل إيه، ولما المدرس يضغط عليه
// الجولة بتكمّل للخطوة اللي بعدها (حتى لو في شاشة تانية أو شيت).
//
// أي عنصر تشاور عليه جولة لازم يتلف بـ [TourTarget] بنفس المعرّف — واختبار
// tour_sync_test بيتأكد إن كل معرّف في [kTours] موجود فعلًا في كود الواجهة،
// وإن كل كلمة بين **علامتين** في نص الخطوة لسه نص حقيقي في التطبيق.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'package:active_class/config/theme.dart';

/// إزاي الخطوة بتخلص: بالضغط على العنصر نفسه، أو بزرار «التالي» في الفقاعة
/// (للخانات اللي بتتكتب).
enum TourAdvance { tap, next, auto }

class TourStep {
  /// معرّف العنصر ([TourTarget.id]).
  final String target;

  /// النص؛ اللي بين **علامتين** اسم حقيقي في الواجهة.
  final String text;
  final TourAdvance advance;

  const TourStep(this.target, this.text, {this.advance = TourAdvance.tap});

  /// خطوة بلا عنصر معيّن (نافذة اختيار مثلًا): الفقاعة بس، وبتكمّل لوحدها
  /// أول ما عنصر الخطوة اللي بعدها يظهر.
  const TourStep.free(this.text)
      : target = '',
        advance = TourAdvance.auto;
}

class TourDef {
  final String id;
  final String title;
  final List<TourStep> steps;

  /// رسالة الختام.
  final String done;
  const TourDef(
      {required this.id,
      required this.title,
      required this.steps,
      required this.done});
}

/// كل الجولات. المعرّفات بتتربط من موضوع المساعدة (HelpTopic.tourId).
const List<TourDef> kTours = [
  TourDef(
    id: 'add_group',
    title: 'ضيف أول مجموعة',
    steps: [
      TourStep('home.groups', 'من الرئيسية اضغط **المجموعات**.'),
      TourStep('groups.add', 'اضغط **مجموعة جديدة**.'),
      TourStep('group.name', 'اكتب **اسم المجموعة** وبعدين اضغط التالي.',
          advance: TourAdvance.next),
      TourStep('group.codePrice',
          'اكتب **بادئة الكود** (حروف قصيرة زي G4A، منها بتتولّد أكواد الطلاب) وسعر الاشتراك، وبعدين اضغط التالي.',
          advance: TourAdvance.next),
      TourStep('group.pricing',
          'اختار **شهري** أو **بالحصة**. لو بالحصة بيتحسب على كل حصة يحضرها الطالب.',
          advance: TourAdvance.next),
      TourStep('group.schedule',
          'ضيف مواعيد الحصص من **إضافة موعد**. منها بيتحدد مين عليه حصة النهارده وبتوصلك إشعارات الحصص. وبعدين اضغط التالي.',
          advance: TourAdvance.next),
      TourStep('group.save', 'اضغط **إضافة المجموعة** — وخلاص!'),
    ],
    done: 'برافو! ضفت مجموعة 🎉 دلوقتي ضيف طلابها من الطلاب.',
  ),
  TourDef(
    id: 'add_student',
    title: 'ضيف أول طالب',
    steps: [
      TourStep('home.students', 'من الرئيسية اضغط **الطلاب**.'),
      TourStep('students.add', 'اضغط **إضافة طالب**.'),
      TourStep('student.name', 'اكتب **اسم الطالب** وبعدين اضغط التالي.',
          advance: TourAdvance.next),
      TourStep('student.group',
          'اختار **المجموعة** اللي الطالب فيها، وبعدين اضغط التالي.',
          advance: TourAdvance.next),
      TourStep('student.phone',
          'حط **رقم ولي الأمر** (اختياري). عليه بتتبعت رسايل الواتساب، وبيدخل بآخر 4 أرقام منه على بوابة أولياء الأمور.',
          advance: TourAdvance.next),
      TourStep('student.save', 'اضغط **إضافة الطالب** — وخلاص!'),
    ],
    done: 'برافو! ضفت طالب 🎉 الكود والـQR بتوعه بتلاقيهم في صفحته.',
  ),
  TourDef(
    id: 'attendance',
    title: 'سجّل حضور حصة',
    steps: [
      TourStep('home.attendance', 'من الرئيسية اضغط **الحضور**.'),
      TourStep('attendance.session',
          'دي مجموعات النهارده حسب جدولها. اضغط كارت المجموعة.'),
      TourStep('attendance.markAll',
          'اضغط **تحضير الكل** لو أغلب الطلاب حاضرين، وبعدين عدّل الغايبين بس.',
          advance: TourAdvance.next),
      TourStep('attendance.row',
          'أو اختار لكل طالب **حاضر** أو **متأخر** أو **غائب**. اضغط على الصف علشان تخلّص.'),
    ],
    done: 'تمام! كده سجّلت الحضور 🎉 تقدر تبعت تقرير الحصة لأولياء الأمور من نفس النافذة.',
  ),
  TourDef(
    id: 'payment',
    title: 'سجّل أول دفعة',
    steps: [
      TourStep('home.payments', 'من الرئيسية اضغط **المدفوعات**.'),
      TourStep('payments.add', 'اضغط **تسجيل دفعة**.'),
      TourStep.free('اختار الطالب من القايمة اللي ظهرت (**اختر الطالب**).'),
      TourStep('payment.amount',
          'اكتب **المبلغ** اللي دفعه (الدفعة الجزئية عادية)، وبعدين اضغط التالي.',
          advance: TourAdvance.next),
      TourStep('payment.save', 'اضغط **تسجيل الدفعة** — وخلاص!'),
    ],
    done: 'برافو! سجّلت أول دفعة 🎉 مديونية الطالب بتتحدّث لوحدها.',
  ),
  TourDef(
    id: 'online_exam',
    title: 'اعمل أول امتحان إلكتروني',
    steps: [
      TourStep('home.exams', 'من الرئيسية اضغط **الامتحانات**.'),
      TourStep('exams.onlineTab', 'اختار تاب **إلكتروني**.'),
      TourStep('exams.newOnline', 'اضغط **امتحان إلكتروني جديد**.'),
      TourStep('exam.name', 'اكتب **اسم الامتحان** وبعدين اضغط التالي.',
          advance: TourAdvance.next),
      TourStep('exam.bank',
          'ضيف أسئلتك: إما من **أضف من بنك الأسئلة** هنا، أو بزرار **اختيار من متعدد** تحت. وبعدين اضغط التالي.',
          advance: TourAdvance.next),
      TourStep('exam.publish',
          'لما تخلّص اضغط **نشر**، وهيطلعلك رابط تبعته للطلاب. ولو لسه، سيبه واضغط التالي.',
          advance: TourAdvance.next),
    ],
    done: 'تمام! الامتحان الإلكتروني جاهز للنشر 🎉 النتايج بتتجمّع لوحدها في التطبيق.',
  ),
];

TourDef? tourById(String id) {
  for (final t in kTours) {
    if (t.id == id) return t;
  }
  return null;
}

/// حالة الجولة الشغّالة (واحدة بس في المرة).
class TourController extends ChangeNotifier {
  TourController._();
  static final TourController instance = TourController._();

  final Map<String, GlobalKey> _targets = {};
  TourDef? _tour;
  int _index = 0;
  bool _finished = false;

  TourDef? get tour => _tour;
  int get index => _index;
  bool get active => _tour != null;
  bool get finished => _finished;
  TourStep? get step =>
      (_tour == null || _finished) ? null : _tour!.steps[_index];

  GlobalKey? keyFor(String id) => _targets[id];

  void _register(String id, GlobalKey key) => _targets[id] = key;
  void _unregister(String id, GlobalKey key) {
    if (_targets[id] == key) _targets.remove(id);
  }

  void start(String id) {
    final t = tourById(id);
    if (t == null) return;
    _tour = t;
    _index = 0;
    _finished = false;
    notifyListeners();
  }

  void next() {
    final t = _tour;
    if (t == null) return;
    if (_index + 1 >= t.steps.length) {
      _finished = true;
    } else {
      _index++;
    }
    notifyListeners();
  }

  void stop() {
    _tour = null;
    _finished = false;
    notifyListeners();
  }

  /// [TourTarget] بيبلّغ لما المدرس يضغط عليه.
  void _tapped(String id) {
    final s = step;
    if (s != null && s.target == id && s.advance == TourAdvance.tap) {
      // نسيب الضغطة توصل للزرار الأول (يفتح الشاشة) وبعدين نكمّل.
      scheduleMicrotask(next);
    }
  }
}

/// يعلّم عنصر في الواجهة إن الجولات تقدر تشاور عليه.
class TourTarget extends StatefulWidget {
  final String id;
  final Widget child;
  const TourTarget({super.key, required this.id, required this.child});

  @override
  State<TourTarget> createState() => _TourTargetState();
}

class _TourTargetState extends State<TourTarget> {
  final _key = GlobalKey();

  @override
  void initState() {
    super.initState();
    TourController.instance._register(widget.id, _key);
  }

  @override
  void didUpdateWidget(TourTarget old) {
    super.didUpdateWidget(old);
    if (old.id != widget.id) {
      TourController.instance._unregister(old.id, _key);
      TourController.instance._register(widget.id, _key);
    }
  }

  @override
  void dispose() {
    TourController.instance._unregister(widget.id, _key);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Listener(
        behavior: HitTestBehavior.translucent,
        onPointerUp: (_) => TourController.instance._tapped(widget.id),
        child: KeyedSubtree(key: _key, child: widget.child),
      );
}

/// طبقة الجولة — بتتحط فوق الـNavigator كله (في builder بتاع التطبيق) عشان
/// تفضل فوق الشاشات والشيتات والحوارات.
class TourLayer extends StatefulWidget {
  const TourLayer({super.key});

  @override
  State<TourLayer> createState() => _TourLayerState();
}

class _TourLayerState extends State<TourLayer>
    with SingleTickerProviderStateMixin {
  final _c = TourController.instance;
  late final Ticker _ticker = createTicker((_) => _measure());
  Rect? _rect;
  String? _scrolledFor;

  @override
  void initState() {
    super.initState();
    _c.addListener(_onChange);
    _onChange();
  }

  @override
  void dispose() {
    _c.removeListener(_onChange);
    _ticker.dispose();
    super.dispose();
  }

  void _onChange() {
    if (_c.active && !_ticker.isActive) _ticker.start();
    if (!_c.active && _ticker.isActive) _ticker.stop();
    _scrolledFor = null;
    if (mounted) setState(() => _rect = null);
  }

  /// كل فريم: مكان العنصر على الشاشة (بيتحرك مع السكرول والأنيميشن).
  void _measure() {
    final s = _c.step;
    Rect? r;
    if (s != null && s.advance == TourAdvance.auto) {
      // خطوة بلا عنصر: نكمّل لما عنصر الخطوة اللي بعدها يظهر.
      final steps = _c.tour!.steps;
      final nxt = _c.index + 1 < steps.length ? steps[_c.index + 1] : null;
      final ctx = nxt == null ? null : _c.keyFor(nxt.target)?.currentContext;
      final ro = ctx?.findRenderObject();
      if (ro is RenderBox && ro.attached && ro.hasSize) {
        scheduleMicrotask(_c.next);
      }
      return;
    }
    if (s != null) {
      final ctx = _c.keyFor(s.target)?.currentContext;
      final box = ctx?.findRenderObject();
      if (ctx != null && box is RenderBox && box.attached && box.hasSize) {
        final layer = context.findRenderObject() as RenderBox?;
        final origin = box.localToGlobal(Offset.zero, ancestor: layer);
        r = origin & box.size;
        if (_scrolledFor != s.target) {
          _scrolledFor = s.target;
          Scrollable.ensureVisible(ctx,
              alignment: 0.4, duration: const Duration(milliseconds: 300));
        }
      }
    }
    if (r != _rect) setState(() => _rect = r);
  }

  @override
  Widget build(BuildContext context) {
    if (!_c.active) return const SizedBox.shrink();
    final size = MediaQuery.sizeOf(context);
    final t = context.tokens;
    if (_c.finished) {
      return _Scrim(
        child: Center(
            child: _Bubble(
          text: _c.tour!.done,
          primaryLabel: 'تمام',
          onPrimary: _c.stop,
          title: _c.tour!.title,
        )),
      );
    }
    final step = _c.step!;
    final total = _c.tour!.steps.length;
    final hole = _rect?.inflate(6);
    final bubble = _Bubble(
      title: '${_c.tour!.title} — ${_c.index + 1} من $total',
      text: hole == null ? '${step.text}\n\n(بنستنى الشاشة تفتح…)' : step.text,
      primaryLabel: step.advance == TourAdvance.next ? 'التالي' : null,
      onPrimary: step.advance == TourAdvance.next ? _c.next : null,
      secondaryLabel: 'إنهاء الجولة',
      onSecondary: _c.stop,
      skipLabel:
          step.advance == TourAdvance.tap && hole == null ? 'تخطّي' : null,
      onSkip: _c.next,
    );
    if (step.advance == TourAdvance.auto) {
      return Align(
        alignment: Alignment.bottomCenter,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.lg),
            child: _Bubble(
              title: '${_c.tour!.title} — ${_c.index + 1} من $total',
              text: step.text,
              secondaryLabel: 'إنهاء الجولة',
              onSecondary: _c.stop,
            ),
          ),
        ),
      );
    }
    if (hole == null) {
      // العنصر لسه مش ظاهر: الفقاعة بس تحت، والشاشة شغّالة عادي.
      return Align(
        alignment: Alignment.bottomCenter,
        child: SafeArea(
            child: Padding(
          padding: const EdgeInsets.all(AppSpace.lg),
          child: bubble,
        )),
      );
    }
    final dim = Colors.black.withValues(alpha: 0.62);
    // 4 مستطيلات حوالين الفتحة بتمسك الضغط، والفتحة نفسها فاضية فالضغط
    // بيوصل للزرار الحقيقي تحتها.
    Widget block(Rect r) => Positioned.fromRect(
          rect: r,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {},
            child: ColoredBox(color: dim),
          ),
        );
    final below = hole.bottom + 180 < size.height;
    return Stack(children: [
      block(Rect.fromLTRB(0, 0, size.width, hole.top)),
      block(Rect.fromLTRB(0, hole.bottom, size.width, size.height)),
      block(Rect.fromLTRB(0, hole.top, hole.left, hole.bottom)),
      block(Rect.fromLTRB(hole.right, hole.top, size.width, hole.bottom)),
      // إطار طباشير حوالين العنصر
      Positioned.fromRect(
        rect: hole,
        child: IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: t.chalk, width: 3),
              borderRadius: BorderRadius.circular(AppRadius.control),
            ),
          ),
        ),
      ),
      Positioned(
        left: AppSpace.lg,
        right: AppSpace.lg,
        top: below ? hole.bottom + AppSpace.md : null,
        bottom: below ? null : size.height - hole.top + AppSpace.md,
        child: bubble,
      ),
    ]);
  }
}

class _Scrim extends StatelessWidget {
  final Widget child;
  const _Scrim({required this.child});
  @override
  Widget build(BuildContext context) => Stack(children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {},
            child: ColoredBox(color: Colors.black.withValues(alpha: 0.62)),
          ),
        ),
        Padding(padding: const EdgeInsets.all(AppSpace.lg), child: child),
      ]);
}

/// فقاعة السبورة: عنوان صغير + النص (العريض بخط تقيل) + أزرار.
class _Bubble extends StatelessWidget {
  final String title;
  final String text;
  final String? primaryLabel;
  final VoidCallback? onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final String? skipLabel;
  final VoidCallback? onSkip;
  const _Bubble({
    required this.title,
    required this.text,
    this.primaryLabel,
    this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
    this.skipLabel,
    this.onSkip,
  });

  List<TextSpan> _spans(TextStyle base) {
    final parts = text.split('**');
    return [
      for (var i = 0; i < parts.length; i++)
        TextSpan(
            text: parts[i],
            style: i.isOdd ? base.copyWith(fontWeight: FontWeight.w800) : base),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final base = AppType.body.copyWith(color: t.boardInk, height: 1.5);
    return Material(
      color: t.board,
      elevation: 8,
      borderRadius: BorderRadius.circular(AppRadius.panel),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpace.lg, AppSpace.md, AppSpace.lg, AppSpace.sm),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Icon(Icons.touch_app_rounded, size: 18, color: t.chalk),
              const SizedBox(width: 6),
              Expanded(
                child: Text(title,
                    style: AppType.caption.copyWith(color: t.boardInkSoft)),
              ),
            ]),
            const SizedBox(height: AppSpace.xs),
            Text.rich(TextSpan(children: _spans(base))),
            const SizedBox(height: AppSpace.xs),
            Row(children: [
              if (secondaryLabel != null)
                TextButton(
                  onPressed: onSecondary,
                  style: TextButton.styleFrom(foregroundColor: t.boardInkSoft),
                  child: Text(secondaryLabel!),
                ),
              const Spacer(),
              if (skipLabel != null)
                TextButton(
                  onPressed: onSkip,
                  style: TextButton.styleFrom(foregroundColor: t.boardInkSoft),
                  child: Text(skipLabel!),
                ),
              if (primaryLabel != null)
                FilledButton(
                  onPressed: onPrimary,
                  style: FilledButton.styleFrom(
                      backgroundColor: t.chalk, foregroundColor: t.onChalk),
                  child: Text(primaryLabel!),
                ),
            ]),
          ],
        ),
      ),
    );
  }
}
