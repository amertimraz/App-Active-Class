import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// اسم قاعدة IndexedDB اللي sqflite_common_ffi_web بيخزّن فيها ملفات SQLite.
const _kIdbName = 'sqflite_databases';

Future<void> purgeBrowserDatabaseStorage() async {
  final open = web.window.indexedDB.open(_kIdbName);
  final opened = Completer<web.IDBDatabase>();
  open.onsuccess =
      ((web.Event _) => opened.complete(open.result as web.IDBDatabase)).toJS;
  open.onerror =
      ((web.Event _) => opened.completeError('تعذر فتح IndexedDB')).toJS;
  final db = await opened.future.timeout(const Duration(seconds: 5));
  try {
    final stores = db.objectStoreNames;
    final names = <String>[
      for (var i = 0; i < stores.length; i++) stores.item(i)!,
    ];
    if (names.isEmpty) return;
    final tx =
        db.transaction(names.map((e) => e.toJS).toList().toJS, 'readwrite');
    final done = Completer<void>();
    tx.oncomplete = ((web.Event _) => done.complete()).toJS;
    tx.onerror =
        ((web.Event _) => done.completeError('فشل مسح IndexedDB')).toJS;
    tx.onabort =
        ((web.Event _) => done.completeError('اتلغى مسح IndexedDB')).toJS;
    for (final n in names) {
      tx.objectStore(n).clear();
    }
    await done.future.timeout(const Duration(seconds: 5));
  } finally {
    db.close();
  }
}
