// test/sync_in_place_update_test.dart — spec 049: تحديث الصف المتزامن بالـid
import 'package:active_class/utils/sync_conflict.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('inPlaceUpdateColumns يشيل مفاتيح الأصل ويبقي البيانات', () {
    final row = {
      'id': 'x',
      'team_id': 't',
      'origin_device_id': 'dev-new',
      'local_id': 7,
      'name': 'Grade 2',
      'code': 'G2',
      'updated_at': '2026-10-08T10:00:00',
      'group_remote_id': null,
    };
    final cols = inPlaceUpdateColumns(row);
    expect(cols.containsKey('team_id'), false);
    expect(cols.containsKey('origin_device_id'), false);
    expect(cols.containsKey('local_id'), false);
    expect(cols.containsKey('id'), false);
    expect(cols['name'], 'Grade 2');
    expect(cols['code'], 'G2');
    expect(cols['updated_at'], '2026-10-08T10:00:00');
    // null يتبعت (مسح قيمة) مش بيتشال
    expect(cols.containsKey('group_remote_id'), true);
    expect(cols['group_remote_id'], isNull);
  });

  test('الأصل الأصلي ما يتغيّرش لو الهوية الحالية مختلفة', () {
    final cols = inPlaceUpdateColumns(
        {'origin_device_id': 'new', 'local_id': 1, 'status': 'حاضر'});
    expect(cols, {'status': 'حاضر'});
  });
}
