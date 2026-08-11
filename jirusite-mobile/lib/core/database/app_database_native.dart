// Native (Android/iOS/desktop) database implementation using sqflite.
library;
import 'dart:async';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'app_database.dart';

AppDatabase createNativeDatabase() => NativeAppDatabase();

class NativeAppDatabase extends AppDatabase {
  Database? _db;

  @override
  @visibleForTesting
  set testDatabase(dynamic db) => _db = db as Database;

  Future<Database> get _database async {
    _db ??= await _openDb();
    return _db!;
  }

  Future<Database> _openDb() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'jirusite.sqlite');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, _) async {
        for (final stmt in _schemaSql) {
          await db.execute(stmt);
        }
      },
    );
  }

  // ── Projects ────────────────────────────────────────────────────────────────

  @override
  Stream<List<LocalProject>> watchProjects(String orgId) =>
      _poll(() => getProjects(orgId));

  @override
  Future<List<LocalProject>> getProjects(String orgId) async {
    final db = await _database;
    final rows = await db.query(
      'local_projects',
      where: 'organization_id = ?',
      whereArgs: [orgId],
      orderBy: 'updated_at DESC',
    );
    return rows.map(_projectFromMap).toList();
  }

  @override
  Future<LocalProject?> getProject(String id) async {
    final db = await _database;
    final rows = await db.query('local_projects', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : _projectFromMap(rows.first);
  }

  @override
  Future<void> upsertProject(LocalProject project) async {
    final db = await _database;
    await db.insert('local_projects', _projectToMap(project),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<void> upsertProjects(List<LocalProject> projects) async {
    final db = await _database;
    final batch = db.batch();
    for (final p in projects) {
      batch.insert('local_projects', _projectToMap(p),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  // ── Expenses ──────────────────────────────────────────────────────────────

  @override
  Stream<List<LocalExpense>> watchExpenses(String projectId) =>
      _poll(() => _getExpenses(projectId));

  Future<List<LocalExpense>> _getExpenses(String projectId) async {
    final db = await _database;
    final rows = await db.query('local_expenses',
        where: 'project_id = ?', whereArgs: [projectId], orderBy: 'created_at DESC');
    return rows.map(_expenseFromMap).toList();
  }

  @override
  Future<List<LocalExpense>> getPendingExpenses() async {
    final db = await _database;
    final rows = await db.query('local_expenses', where: "sync_status = 'pending'");
    return rows.map(_expenseFromMap).toList();
  }

  @override
  Future<void> insertExpense(LocalExpense e) async {
    final db = await _database;
    await db.insert('local_expenses', _expenseToMap(e),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<void> markExpenseSynced(String localId, String serverId) async {
    final db = await _database;
    await db.update(
      'local_expenses',
      {'sync_status': 'synced', 'server_id': serverId, 'updated_at': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?', whereArgs: [localId],
    );
  }

  @override
  Future<void> markExpenseConflict(String localId, String serverJson) async {
    final db = await _database;
    await db.update(
      'local_expenses',
      {'sync_status': 'conflict', 'conflict_payload': serverJson, 'updated_at': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?', whereArgs: [localId],
    );
  }

  @override
  Future<void> upsertExpenses(List<LocalExpense> expenses) async {
    final db = await _database;
    final batch = db.batch();
    for (final e in expenses) {
      batch.insert('local_expenses', _expenseToMap(e), conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  // ── Labor ──────────────────────────────────────────────────────────────────

  @override
  Stream<List<LocalLaborEntry>> watchLabor(String projectId) =>
      _poll(() => _getLabor(projectId));

  Future<List<LocalLaborEntry>> _getLabor(String projectId) async {
    final db = await _database;
    final rows = await db.query('local_labor_entries',
        where: 'project_id = ?', whereArgs: [projectId], orderBy: 'created_at DESC');
    return rows.map(_laborFromMap).toList();
  }

  @override
  Future<List<LocalLaborEntry>> getPendingLabor() async {
    final db = await _database;
    final rows = await db.query('local_labor_entries', where: "sync_status = 'pending'");
    return rows.map(_laborFromMap).toList();
  }

  @override
  Future<void> insertLabor(LocalLaborEntry l) async {
    final db = await _database;
    await db.insert('local_labor_entries', _laborToMap(l),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<void> markLaborSynced(String localId, String serverId) async {
    final db = await _database;
    await db.update(
      'local_labor_entries',
      {'sync_status': 'synced', 'server_id': serverId},
      where: 'id = ?', whereArgs: [localId],
    );
  }

  @override
  Future<void> upsertLaborEntries(List<LocalLaborEntry> entries) async {
    final db = await _database;
    final batch = db.batch();
    for (final l in entries) {
      batch.insert('local_labor_entries', _laborToMap(l), conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  // ── Photos ─────────────────────────────────────────────────────────────────

  @override
  Stream<List<LocalPhotoQueueItem>> watchPendingPhotos() => _poll(_getPendingPhotos);

  Future<List<LocalPhotoQueueItem>> _getPendingPhotos() async {
    final db = await _database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final rows = await db.rawQuery(
      "SELECT * FROM local_photo_queue WHERE (sync_status='pending' OR sync_status='failed') AND (next_retry_at IS NULL OR next_retry_at <= ?)",
      [now],
    );
    return rows.map((m) => LocalPhotoQueueItem(
      id: m['id'] as int,
      expenseId: m['expense_id'] as String,
      localPath: m['local_path'] as String,
      syncStatus: m['sync_status'] as String,
      retryCount: m['retry_count'] as int? ?? 0,
      nextRetryAt: m['next_retry_at'] == null ? null : DateTime.fromMillisecondsSinceEpoch(m['next_retry_at'] as int),
      createdAt: DateTime.fromMillisecondsSinceEpoch(m['created_at'] as int),
    )).toList();
  }

  @override
  Future<int> queuePhoto(String expenseId, String localPath) async {
    final db = await _database;
    return db.insert('local_photo_queue', {
      'expense_id': expenseId, 'local_path': localPath,
      'sync_status': 'pending', 'retry_count': 0,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  @override
  Future<void> markPhotoUploaded(int id) async {
    final db = await _database;
    await db.update('local_photo_queue', {'sync_status': 'done'}, where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<void> markPhotoFailed(int id, int retryCount) async {
    final db = await _database;
    final nextRetry = DateTime.now().add(Duration(seconds: (60 * (retryCount + 1)).clamp(60, 3600))).millisecondsSinceEpoch;
    await db.update('local_photo_queue',
      {'sync_status': 'failed', 'retry_count': retryCount + 1, 'next_retry_at': nextRetry},
      where: 'id = ?', whereArgs: [id]);
  }

  // ── Sync meta ──────────────────────────────────────────────────────────────

  @override
  Future<DateTime?> getLastSyncedAt(String orgId) async {
    final db = await _database;
    final rows = await db.query('local_sync_meta',
        columns: ['last_synced_at'], where: 'organization_id = ?', whereArgs: [orgId]);
    if (rows.isEmpty) return null;
    final ms = rows.first['last_synced_at'] as int?;
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  @override
  Future<void> updateLastSyncedAt(String orgId) async {
    final db = await _database;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.insert('local_sync_meta',
      {'organization_id': orgId, 'last_synced_at': now, 'updated_at': now},
      conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<void> close() async => _db?.close();

  // ── Polling stream ──────────────────────────────────────────────────────────

  Stream<T> _poll<T>(Future<T> Function() fetch) {
    late StreamController<T> ctrl;
    Timer? timer;
    ctrl = StreamController<T>(
      onListen: () {
        fetch().then((v) { if (!ctrl.isClosed) ctrl.add(v); });
        timer = Timer.periodic(const Duration(seconds: 2), (_) async {
          try { final v = await fetch(); if (!ctrl.isClosed) ctrl.add(v); }
          catch (e) { if (!ctrl.isClosed) ctrl.addError(e); }
        });
      },
      onCancel: () => timer?.cancel(),
    );
    return ctrl.stream;
  }

  // ── Map helpers ─────────────────────────────────────────────────────────────

  LocalProject _projectFromMap(Map<String, dynamic> m) => LocalProject(
    id: m['id'] as String, organizationId: m['organization_id'] as String,
    name: m['name'] as String, locationText: m['location_text'] as String?,
    latitude: (m['latitude'] as num?)?.toDouble(), longitude: (m['longitude'] as num?)?.toDouble(),
    totalBudget: (m['total_budget'] as num?)?.toDouble(), currency: m['currency'] as String? ?? 'ETB',
    startDate: m['start_date'] as String?, targetEndDate: m['target_end_date'] as String?,
    status: m['status'] as String? ?? 'active', createdBy: m['created_by'] as String?,
    createdAt: DateTime.fromMillisecondsSinceEpoch(m['created_at'] as int),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(m['updated_at'] as int),
    lastSyncedAt: m['last_synced_at'] == null ? null : DateTime.fromMillisecondsSinceEpoch(m['last_synced_at'] as int),
  );

  Map<String, dynamic> _projectToMap(LocalProject p) => {
    'id': p.id, 'organization_id': p.organizationId, 'name': p.name,
    'location_text': p.locationText, 'latitude': p.latitude, 'longitude': p.longitude,
    'total_budget': p.totalBudget, 'currency': p.currency, 'start_date': p.startDate,
    'target_end_date': p.targetEndDate, 'status': p.status, 'created_by': p.createdBy,
    'created_at': p.createdAt.millisecondsSinceEpoch, 'updated_at': p.updatedAt.millisecondsSinceEpoch,
    'last_synced_at': p.lastSyncedAt?.millisecondsSinceEpoch,
  };

  LocalExpense _expenseFromMap(Map<String, dynamic> m) => LocalExpense(
    id: m['id'] as String, projectId: m['project_id'] as String,
    costCodeId: m['cost_code_id'] as String?, enteredBy: m['entered_by'] as String,
    supplierId: m['supplier_id'] as String?, description: m['description'] as String?,
    amount: (m['amount'] as num).toDouble(), quantity: (m['quantity'] as num?)?.toDouble(),
    unit: m['unit'] as String?, expenseType: m['expense_type'] as String,
    receiptPhotoUrl: m['receipt_photo_url'] as String?,
    receiptPhotoLocalPath: m['receipt_photo_local_path'] as String?,
    transactionDate: m['transaction_date'] as String, syncStatus: m['sync_status'] as String? ?? 'pending',
    serverId: m['server_id'] as String?, conflictPayload: m['conflict_payload'] as String?,
    createdAt: DateTime.fromMillisecondsSinceEpoch(m['created_at'] as int),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(m['updated_at'] as int),
  );

  Map<String, dynamic> _expenseToMap(LocalExpense e) => {
    'id': e.id, 'project_id': e.projectId, 'cost_code_id': e.costCodeId,
    'entered_by': e.enteredBy, 'supplier_id': e.supplierId, 'description': e.description,
    'amount': e.amount, 'quantity': e.quantity, 'unit': e.unit, 'expense_type': e.expenseType,
    'receipt_photo_url': e.receiptPhotoUrl, 'receipt_photo_local_path': e.receiptPhotoLocalPath,
    'transaction_date': e.transactionDate, 'sync_status': e.syncStatus,
    'server_id': e.serverId, 'conflict_payload': e.conflictPayload,
    'created_at': e.createdAt.millisecondsSinceEpoch, 'updated_at': e.updatedAt.millisecondsSinceEpoch,
  };

  LocalLaborEntry _laborFromMap(Map<String, dynamic> m) => LocalLaborEntry(
    id: m['id'] as String, projectId: m['project_id'] as String,
    costCodeId: m['cost_code_id'] as String?, enteredBy: m['entered_by'] as String,
    workerOrCrewName: m['worker_or_crew_name'] as String,
    workDescription: m['work_description'] as String?,
    numberOfWorkers: m['number_of_workers'] as int? ?? 1,
    dailyRate: (m['daily_rate'] as num?)?.toDouble(),
    totalAmount: (m['total_amount'] as num).toDouble(), workDate: m['work_date'] as String,
    syncStatus: m['sync_status'] as String? ?? 'pending', serverId: m['server_id'] as String?,
    createdAt: DateTime.fromMillisecondsSinceEpoch(m['created_at'] as int),
  );

  Map<String, dynamic> _laborToMap(LocalLaborEntry l) => {
    'id': l.id, 'project_id': l.projectId, 'cost_code_id': l.costCodeId,
    'entered_by': l.enteredBy, 'worker_or_crew_name': l.workerOrCrewName,
    'work_description': l.workDescription, 'number_of_workers': l.numberOfWorkers,
    'daily_rate': l.dailyRate, 'total_amount': l.totalAmount, 'work_date': l.workDate,
    'sync_status': l.syncStatus, 'server_id': l.serverId,
    'created_at': l.createdAt.millisecondsSinceEpoch,
  };
}

// ── Schema DDL ────────────────────────────────────────────────────────────────

const List<String> _schemaSql = [
  '''CREATE TABLE IF NOT EXISTS local_projects (
    id TEXT PRIMARY KEY NOT NULL, organization_id TEXT NOT NULL, name TEXT NOT NULL,
    location_text TEXT, latitude REAL, longitude REAL, total_budget REAL,
    currency TEXT NOT NULL DEFAULT 'ETB', start_date TEXT, target_end_date TEXT,
    status TEXT NOT NULL DEFAULT 'active', created_by TEXT,
    created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, last_synced_at INTEGER
  )''',
  '''CREATE TABLE IF NOT EXISTS local_expenses (
    id TEXT PRIMARY KEY NOT NULL, project_id TEXT NOT NULL, cost_code_id TEXT,
    entered_by TEXT NOT NULL, supplier_id TEXT, description TEXT, amount REAL NOT NULL,
    quantity REAL, unit TEXT, expense_type TEXT NOT NULL, receipt_photo_url TEXT,
    receipt_photo_local_path TEXT, transaction_date TEXT NOT NULL,
    sync_status TEXT NOT NULL DEFAULT 'pending', server_id TEXT, conflict_payload TEXT,
    created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL
  )''',
  '''CREATE TABLE IF NOT EXISTS local_labor_entries (
    id TEXT PRIMARY KEY NOT NULL, project_id TEXT NOT NULL, cost_code_id TEXT,
    entered_by TEXT NOT NULL, worker_or_crew_name TEXT NOT NULL, work_description TEXT,
    number_of_workers INTEGER NOT NULL DEFAULT 1, daily_rate REAL, total_amount REAL NOT NULL,
    work_date TEXT NOT NULL, sync_status TEXT NOT NULL DEFAULT 'pending',
    server_id TEXT, created_at INTEGER NOT NULL
  )''',
  '''CREATE TABLE IF NOT EXISTS local_photo_queue (
    id INTEGER PRIMARY KEY AUTOINCREMENT, expense_id TEXT NOT NULL, local_path TEXT NOT NULL,
    sync_status TEXT NOT NULL DEFAULT 'pending', retry_count INTEGER NOT NULL DEFAULT 0,
    next_retry_at INTEGER, created_at INTEGER NOT NULL
  )''',
  '''CREATE TABLE IF NOT EXISTS local_sync_meta (
    organization_id TEXT PRIMARY KEY NOT NULL, last_synced_at INTEGER, updated_at INTEGER NOT NULL
  )''',
  'CREATE INDEX IF NOT EXISTS idx_exp_proj ON local_expenses(project_id)',
  'CREATE INDEX IF NOT EXISTS idx_exp_sync ON local_expenses(sync_status)',
  'CREATE INDEX IF NOT EXISTS idx_lab_proj ON local_labor_entries(project_id)',
];

/// Exposed for unit testing.
const List<String> schemaSql = _schemaSql;
