// lib/firebase_options.dart
// ⚠️ نفس مشروع Firebase الخاص بلوحة الإدارة (active-class-72e0f)
// إذا أردت appId مستقل للتطبيق شغّل: dart pub global run flutterfire_cli:flutterfire configure

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.windows: return windows;
      case TargetPlatform.android: return android;
      default: return windows;
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAqFLZ4kHEgPLVgLgDGbbIjxnZheBqMjMc',
    appId: '1:822461821604:web:3bd266a9833ce045916c31',
    messagingSenderId: '822461821604',
    projectId: 'active-class-72e0f',
    authDomain: 'active-class-72e0f.firebaseapp.com',
    databaseURL: 'https://active-class-72e0f-default-rtdb.firebaseio.com',
    storageBucket: 'active-class-72e0f.firebasestorage.app',
  );

  // Windows — نفس المشروع
  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyAqFLZ4kHEgPLVgLgDGbbIjxnZheBqMjMc',
    appId: '1:822461821604:web:215f1322a9eadd82916c31',
    messagingSenderId: '822461821604',
    projectId: 'active-class-72e0f',
    authDomain: 'active-class-72e0f.firebaseapp.com',
    databaseURL: 'https://active-class-72e0f-default-rtdb.firebaseio.com',
    storageBucket: 'active-class-72e0f.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAqFLZ4kHEgPLVgLgDGbbIjxnZheBqMjMc',
    appId: '1:822461821604:android:8bb0818b1b92aa14916c31',
    messagingSenderId: '822461821604',
    projectId: 'active-class-72e0f',
    storageBucket: 'active-class-72e0f.firebasestorage.app',
  );
}
