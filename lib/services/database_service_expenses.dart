part of 'database_service.dart';

// مصاريف المعلم (v42) — محلية فقط، بدون طابور مزامنة.
extension ExpensesDb on DatabaseService {
  Future<List<Expense>> getExpensesInRange(DateTime from, DateTime to) async {
    final db = await database;
    final rows = await db.query(
      TABLE_EXPENSES,
      where: '$COL_EXP_DATE >= ? AND $COL_EXP_DATE < ?',
      whereArgs: [from.toIso8601String(), to.toIso8601String()],
      orderBy: '$COL_EXP_DATE DESC',
    );
    return rows.map(Expense.fromMap).toList();
  }

  Future<int> insertExpense(Expense e) async {
    final db = await database;
    return db.insert(TABLE_EXPENSES, e.toMap());
  }

  Future<void> updateExpense(Expense e) async {
    final db = await database;
    await db.update(TABLE_EXPENSES, e.toMap(),
        where: '$COL_EXP_ID = ?', whereArgs: [e.id]);
  }

  Future<void> deleteExpense(int id) async {
    final db = await database;
    await db.delete(TABLE_EXPENSES, where: '$COL_EXP_ID = ?', whereArgs: [id]);
  }
}
