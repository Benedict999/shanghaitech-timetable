import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../domain/course_meeting.dart';

abstract interface class ScheduleStore {
  Future<SyncResult?> load();

  Future<void> save(SyncResult schedule);

  Future<int?> loadSelectedWeek();

  Future<void> saveSelectedWeek(int week);
}

class ScheduleRepository implements ScheduleStore {
  ScheduleRepository({
    SharedPreferencesAsync? preferences,
    Future<Database>? database,
    this.legacyReader,
  }) : _providedPreferences = preferences,
       _opening = database;

  static const _scheduleKey = 'saved_schedule_v1';
  static const _selectedWeekKey = 'selected_week_v1';

  final SharedPreferencesAsync? _providedPreferences;
  late final SharedPreferencesAsync _preferences =
      _providedPreferences ?? SharedPreferencesAsync();
  final Future<String?> Function()? legacyReader;
  Future<Database>? _opening;
  Future<Database> get _database => _opening ??= openDatabase(
    'timetable_v3.db',
    version: 1,
    onCreate: createSchema,
  );

  static Future<void> createSchema(Database db, int version) async {
    await db.execute(
      'CREATE TABLE semesters (code TEXT PRIMARY KEY, payload TEXT NOT NULL)',
    );
    await db.execute(
      'CREATE TABLE meetings (term TEXT NOT NULL, ordinal INTEGER NOT NULL, payload TEXT NOT NULL, PRIMARY KEY(term, ordinal))',
    );
    await db.execute(
      'CREATE TABLE snapshots (id INTEGER PRIMARY KEY AUTOINCREMENT, term TEXT NOT NULL, saved_at TEXT NOT NULL, payload TEXT NOT NULL)',
    );
    await db.execute(
      'CREATE TABLE settings (name TEXT PRIMARY KEY, value TEXT NOT NULL)',
    );
  }

  @override
  Future<SyncResult?> load() async {
    final db = await _database;
    final active = await db.query(
      'settings',
      where: 'name = ?',
      whereArgs: ['active_term'],
    );
    if (active.isNotEmpty) {
      final code = active.first['value'];
      final terms = await db.query(
        'semesters',
        where: 'code = ?',
        whereArgs: [code],
      );
      if (terms.isEmpty) throw const FormatException('本地学期数据不完整');
      final data = Map<String, dynamic>.from(
        jsonDecode(terms.first['payload'] as String) as Map,
      );
      final rows = await db.query(
        'meetings',
        where: 'term = ?',
        whereArgs: [code],
        orderBy: 'ordinal',
      );
      data['meetings'] = rows
          .map((r) => jsonDecode(r['payload'] as String))
          .toList();
      return SyncResult.fromJson(data);
    }
    final encoded =
        await (legacyReader?.call() ?? _preferences.getString(_scheduleKey));
    if (encoded == null || encoded.isEmpty) return null;

    final decoded = jsonDecode(encoded);
    if (decoded is! Map) throw const FormatException('旧版课表数据不完整');
    final migrated = SyncResult.fromJson(Map<String, dynamic>.from(decoded));
    await save(migrated);
    // Keep the original preferences as a recovery copy after migration.
    return migrated;
  }

  @override
  Future<void> save(SyncResult schedule) async {
    final db = await _database;
    final data = schedule.toJson();
    final header = Map<String, dynamic>.from(data)..remove('meetings');
    await db.transaction((txn) async {
      await txn.insert('snapshots', {
        'term': schedule.termCode,
        'saved_at': DateTime.now().toIso8601String(),
        'payload': jsonEncode(data),
      });
      await txn.insert('semesters', {
        'code': schedule.termCode,
        'payload': jsonEncode(header),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      await txn.delete(
        'meetings',
        where: 'term = ?',
        whereArgs: [schedule.termCode],
      );
      final batch = txn.batch();
      for (var i = 0; i < schedule.meetings.length; i++) {
        batch.insert('meetings', {
          'term': schedule.termCode,
          'ordinal': i,
          'payload': jsonEncode(schedule.meetings[i].toJson()),
        });
      }
      await batch.commit(noResult: true);
      await txn.insert('settings', {
        'name': 'active_term',
        'value': schedule.termCode,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  @override
  Future<int?> loadSelectedWeek() async {
    final week = await _preferences.getInt(_selectedWeekKey);
    if (week == null || week < 1 || week > 30) return null;
    return week;
  }

  @override
  Future<void> saveSelectedWeek(int week) async {
    await _preferences.setInt(_selectedWeekKey, week.clamp(1, 30));
  }
}
