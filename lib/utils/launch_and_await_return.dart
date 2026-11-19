// lib/utils/launch_and_await_return.dart
//
// يفتح تطبيق خارجي (واتساب) ويستنى المدرس يرجع للتطبيق قبل ما يكمّل اللوب — من غير تعليق.
// حادثة: «إرسال تقارير الشهر الجماعي» كان بيعلّق بعد عدد معيّن لأن اللوب بعد كل رسالة كان
// بيستنى حدث «رجع التطبيق» حتى لو الفتح فشل أصلًا (طالب رقمه غير صالح / واتساب ما فتحش)،
// فالتطبيق ما بيخرجش للخلفية ومفيش حدث رجوع أبدًا → انتظار للأبد. كمان المراقب كان بيتسجّل
// بعد الفتح، فلو الرجوع سبقه برضه يعلّق.
import 'dart:async';

import 'package:flutter/widgets.dart';

class _LeaveReturnWatcher with WidgetsBindingObserver {
  bool wentAway = false;
  final _left = Completer<void>();
  final _back = Completer<void>();

  Future<void> get left => _left.future;
  Future<void> get back => _back.future;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      wentAway = true;
      if (!_left.isCompleted) _left.complete();
    } else if (state == AppLifecycleState.resumed && wentAway) {
      if (!_back.isCompleted) _back.complete();
    }
  }
}

/// ينفّذ [launch] (بيرجّع true لو فتح فعلًا). لو رجّع false → يرجّع false فورًا من غير انتظار.
/// لو رجّع true → يستنى التطبيق يخرج للخلفية (بحد أقصى [leaveGrace]) ثم يستنى يرجع. لو التطبيق
/// ما خرجش أصلًا في المهلة (الفتح ما أخدش الشاشة) → يكمّل بدل ما يعلّق. المراقب بيتسجّل
/// **قبل** الفتح فمفيش سباق. [maxWait] اختياري: أقصى انتظار لرجوع المستخدم.
Future<bool> launchAndAwaitReturn(
  Future<bool> Function() launch, {
  Duration leaveGrace = const Duration(seconds: 4),
  Duration? maxWait,
}) async {
  final w = _LeaveReturnWatcher();
  WidgetsBinding.instance.addObserver(w);
  try {
    final ok = await launch();
    if (!ok) return false;
    if (!w.wentAway) {
      await Future.any<void>([w.left, Future<void>.delayed(leaveGrace)]);
    }
    if (!w.wentAway) return true; // التطبيق ما خرجش: مفيش حاجة نستناها
    if (maxWait == null) {
      await w.back;
    } else {
      await Future.any<void>([w.back, Future<void>.delayed(maxWait)]);
    }
    return true;
  } finally {
    WidgetsBinding.instance.removeObserver(w);
  }
}
