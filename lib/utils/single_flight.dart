// lib/utils/single_flight.dart
//
// تجميع الاستدعاءات المتزامنة لمهمة ثقيلة: لو المهمة شغّالة، الاستدعاءات
// الجديدة ما بتبدأش نسخ موازية — بتتعلّم "محتاجة إعادة" وتتنفّذ مرة واحدة
// بعد ما الشغّالة تخلّص (آخر حالة بتتحسب). كل المستدعين بيستنّوا نفس
// الـFuture اللي بيخلص بعد آخر إعادة.
//
// السبب (2026-10-14): الداشبورد كان بيتحسب من أول وجديد مع كل حدث realtime
// وارد في وضع الفريق؛ مع مساعد شغّال (عشرات الأحداث) والحسابات تقيلة
// (O(طلاب × سجلات حضور))، النُسخ كانت بتتراكم ويفضل مؤشر التحميل دايمًا.

class SingleFlight {
  final Future<void> Function() _task;
  Future<void>? _running;
  bool _rerun = false;

  SingleFlight(this._task);

  /// هل فيه تنفيذ شغّال دلوقتي؟
  bool get isRunning => _running != null;

  Future<void> run() {
    final current = _running;
    if (current != null) {
      _rerun = true;
      return current;
    }
    final f = _loop();
    _running = f;
    return f;
  }

  Future<void> _loop() async {
    try {
      do {
        _rerun = false;
        await _task();
      } while (_rerun);
    } finally {
      _running = null;
    }
  }
}
