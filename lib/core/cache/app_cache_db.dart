import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class CachedSnapshot {
  const CachedSnapshot({
    required this.payloadJson,
    required this.cachedAt,
  });

  final String payloadJson;
  final DateTime cachedAt;
}

final Provider<AppCacheDb> appCacheDbProvider = Provider<AppCacheDb>((Ref ref) {
  final AppCacheDb db = Platform.environment.containsKey('FLUTTER_TEST')
      ? AppCacheDb.inMemory()
      : AppCacheDb.onDevice();
  ref.onDispose(db.close);
  return db;
});

/// Read-only offline snapshot cache backed by `drift` SQLite.
/// Every row is keyed by `(user_id, cache_key)` so different users on the same
/// device can never read each other's cached data.
class AppCacheDb extends GeneratedDatabase {
  AppCacheDb(super.e);

  factory AppCacheDb.inMemory() => AppCacheDb(NativeDatabase.memory());

  factory AppCacheDb.onDevice() {
    return AppCacheDb(
      LazyDatabase(() async {
        try {
          final Directory dir = await getApplicationDocumentsDirectory();
          final File file = File(p.join(dir.path, 'luckyledger_cache.sqlite'));
          return NativeDatabase.createInBackground(file);
        } catch (_) {
          return NativeDatabase.memory();
        }
      }),
    );
  }

  bool _initialized = false;

  @override
  int get schemaVersion => 1;

  @override
  Iterable<TableInfo<Table, dynamic>> get allTables =>
      const <TableInfo<Table, dynamic>>[];

  Future<void> _ensureTable() async {
    if (_initialized) {
      return;
    }
    await customStatement(
      '''
      CREATE TABLE IF NOT EXISTS cached_snapshots (
        user_id TEXT NOT NULL,
        cache_key TEXT NOT NULL,
        payload_json TEXT NOT NULL,
        cached_at_ms INTEGER NOT NULL,
        PRIMARY KEY (user_id, cache_key)
      )
      ''',
    );
    _initialized = true;
  }

  Future<void> putSnapshot({
    required String userId,
    required String key,
    required String payloadJson,
    DateTime? now,
  }) async {
    if (userId.isEmpty) {
      return;
    }
    await _ensureTable();
    final int ts = (now ?? DateTime.now()).millisecondsSinceEpoch;
    await customInsert(
      '''
      INSERT OR REPLACE INTO cached_snapshots
        (user_id, cache_key, payload_json, cached_at_ms)
      VALUES (?, ?, ?, ?)
      ''',
      variables: <Variable<Object>>[
        Variable.withString(userId),
        Variable.withString(key),
        Variable.withString(payloadJson),
        Variable.withInt(ts),
      ],
    );
  }

  Future<CachedSnapshot?> getSnapshot({
    required String userId,
    required String key,
  }) async {
    if (userId.isEmpty) {
      return null;
    }
    await _ensureTable();
    final List<QueryRow> rows = await customSelect(
      '''
      SELECT payload_json, cached_at_ms
      FROM cached_snapshots
      WHERE user_id = ? AND cache_key = ?
      LIMIT 1
      ''',
      variables: <Variable<Object>>[
        Variable.withString(userId),
        Variable.withString(key),
      ],
    ).get();
    if (rows.isEmpty) {
      return null;
    }
    final QueryRow row = rows.first;
    return CachedSnapshot(
      payloadJson: row.read<String>('payload_json'),
      cachedAt: DateTime.fromMillisecondsSinceEpoch(
        row.read<int>('cached_at_ms'),
      ),
    );
  }

  Future<void> putJson({
    required String userId,
    required String key,
    required Object value,
    DateTime? now,
  }) {
    return putSnapshot(
      userId: userId,
      key: key,
      payloadJson: jsonEncode(value),
      now: now,
    );
  }

  Future<({Object data, DateTime cachedAt})?> getJson({
    required String userId,
    required String key,
  }) async {
    final CachedSnapshot? snap = await getSnapshot(userId: userId, key: key);
    if (snap == null) {
      return null;
    }
    try {
      return (
        data: jsonDecode(snap.payloadJson) as Object,
        cachedAt: snap.cachedAt,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> clearForUser(String userId) async {
    if (userId.isEmpty) {
      return;
    }
    await _ensureTable();
    await customUpdate(
      'DELETE FROM cached_snapshots WHERE user_id = ?',
      variables: <Variable<Object>>[Variable.withString(userId)],
    );
  }

  Future<void> clearAll() async {
    await _ensureTable();
    await customUpdate('DELETE FROM cached_snapshots');
  }
}
