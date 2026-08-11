import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../utils/json_helpers.dart';

// sqflite is only available on non-web platforms
import 'app_database_stub.dart'
    if (dart.library.io) 'app_database_native.dart' as platform;

export 'app_database.dart' show AppDatabase, appDatabaseProvider;

/// Riverpod provider — overridden in main.dart with the real instance.
final appDatabaseProvider = Provider<AppDatabase>(
    (_) => throw UnimplementedError('appDatabaseProvider not initialized'));

/// Factory that creates the right AppDatabase for the current platform.
/// Factory that creates the right AppDatabase for the current platform.
AppDatabase createAppDatabase() {
  if (kIsWeb) return WebAppDatabase();
  return platform.createNativeDatabase();
}

// ═══════════════════════════════════════════════════════════════════════════
// ABSTRACT BASE — shared interface
// ═══════════════════════════════════════════════════════════════════════════

abstract class AppDatabase {
  // Projects
  Stream<List<LocalProject>> watchProjects(String orgId);
  Future<List<LocalProject>> getProjects(String orgId);
  Future<LocalProject?> getProject(String id);
  Future<void> upsertProject(LocalProject project);
  Future<void> upsertProjects(List<LocalProject> projects);

  // Expenses
  Stream<List<LocalExpense>> watchExpenses(String projectId);
  Future<List<LocalExpense>> getPendingExpenses();
  Future<void> insertExpense(LocalExpense e);
  Future<void> markExpenseSynced(String localId, String serverId);
  Future<void> markExpenseConflict(String localId, String serverJson);
  Future<void> upsertExpenses(List<LocalExpense> expenses);

  // Labor
  Stream<List<LocalLaborEntry>> watchLabor(String projectId);
  Future<List<LocalLaborEntry>> getPendingLabor();
  Future<void> insertLabor(LocalLaborEntry l);
  Future<void> markLaborSynced(String localId, String serverId);
  Future<void> upsertLaborEntries(List<LocalLaborEntry> entries);

  // Photos
  Stream<List<LocalPhotoQueueItem>> watchPendingPhotos();
  Future<int> queuePhoto(String expenseId, String localPath);
  Future<void> markPhotoUploaded(int id);
  Future<void> markPhotoFailed(int id, int retryCount);

  // Sync meta
  Future<DateTime?> getLastSyncedAt(String orgId);
  Future<void> updateLastSyncedAt(String orgId);

  Future<void> close();

  @visibleForTesting
  // ignore: avoid_setters_without_getters
  set testDatabase(dynamic db);
}

// ═══════════════════════════════════════════════════════════════════════════
// WEB IMPLEMENTATION — in-memory, used for Chrome dev preview
// ═══════════════════════════════════════════════════════════════════════════

class WebAppDatabase extends AppDatabase {
  final _projects = <String, LocalProject>{};
  final _expenses = <String, LocalExpense>{};
  final _labor = <String, LocalLaborEntry>{};
  final _photoQueue = <int, LocalPhotoQueueItem>{};
  int _photoIdSeq = 1;
  final _syncMeta = <String, DateTime>{};

  // ── Projects ──────────────────────────────────────────────────────────────

  @override
  Stream<List<LocalProject>> watchProjects(String orgId) =>
      _poll(() async => getProjects(orgId));

  @override
  Future<List<LocalProject>> getProjects(String orgId) async =>
      _projects.values.where((p) => p.organizationId == orgId).toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  @override
  Future<LocalProject?> getProject(String id) async => _projects[id];

  @override
  Future<void> upsertProject(LocalProject project) async =>
      _projects[project.id] = project;

  @override
  Future<void> upsertProjects(List<LocalProject> projects) async {
    for (final p in projects) {
      _projects[p.id] = p;
    }
  }

  // ── Expenses ──────────────────────────────────────────────────────────────

  @override
  Stream<List<LocalExpense>> watchExpenses(String projectId) =>
      _poll(() async => _expenses.values
          .where((e) => e.projectId == projectId)
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt)));

  @override
  Future<List<LocalExpense>> getPendingExpenses() async =>
      _expenses.values.where((e) => e.syncStatus == 'pending').toList();

  @override
  Future<void> insertExpense(LocalExpense e) async => _expenses[e.id] = e;

  @override
  Future<void> markExpenseSynced(String localId, String serverId) async {
    final e = _expenses[localId];
    if (e != null) {
      _expenses[localId] = LocalExpense(
        id: e.id, projectId: e.projectId, costCodeId: e.costCodeId,
        enteredBy: e.enteredBy, supplierId: e.supplierId,
        description: e.description, amount: e.amount, quantity: e.quantity,
        unit: e.unit, expenseType: e.expenseType,
        receiptPhotoUrl: e.receiptPhotoUrl,
        receiptPhotoLocalPath: e.receiptPhotoLocalPath,
        transactionDate: e.transactionDate, syncStatus: 'synced',
        serverId: serverId, conflictPayload: e.conflictPayload,
        createdAt: e.createdAt, updatedAt: DateTime.now(),
      );
    }
  }

  @override
  Future<void> markExpenseConflict(String localId, String serverJson) async {
    final e = _expenses[localId];
    if (e != null) {
      _expenses[localId] = LocalExpense(
        id: e.id, projectId: e.projectId, costCodeId: e.costCodeId,
        enteredBy: e.enteredBy, supplierId: e.supplierId,
        description: e.description, amount: e.amount, quantity: e.quantity,
        unit: e.unit, expenseType: e.expenseType,
        receiptPhotoUrl: e.receiptPhotoUrl,
        receiptPhotoLocalPath: e.receiptPhotoLocalPath,
        transactionDate: e.transactionDate, syncStatus: 'conflict',
        serverId: e.serverId, conflictPayload: serverJson,
        createdAt: e.createdAt, updatedAt: DateTime.now(),
      );
    }
  }

  @override
  Future<void> upsertExpenses(List<LocalExpense> expenses) async {
    for (final e in expenses) {
      _expenses[e.id] = e;
    }
  }

  // ── Labor ──────────────────────────────────────────────────────────────────

  @override
  Stream<List<LocalLaborEntry>> watchLabor(String projectId) =>
      _poll(() async => _labor.values
          .where((l) => l.projectId == projectId)
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt)));

  @override
  Future<List<LocalLaborEntry>> getPendingLabor() async =>
      _labor.values.where((l) => l.syncStatus == 'pending').toList();

  @override
  Future<void> insertLabor(LocalLaborEntry l) async => _labor[l.id] = l;

  @override
  Future<void> markLaborSynced(String localId, String serverId) async {
    final l = _labor[localId];
    if (l != null) {
      _labor[localId] = LocalLaborEntry(
        id: l.id, projectId: l.projectId, costCodeId: l.costCodeId,
        enteredBy: l.enteredBy, workerOrCrewName: l.workerOrCrewName,
        workDescription: l.workDescription, numberOfWorkers: l.numberOfWorkers,
        dailyRate: l.dailyRate, totalAmount: l.totalAmount,
        workDate: l.workDate, syncStatus: 'synced',
        serverId: serverId, createdAt: l.createdAt,
      );
    }
  }

  @override
  Future<void> upsertLaborEntries(List<LocalLaborEntry> entries) async {
    for (final l in entries) {
      _labor[l.id] = l;
    }
  }

  // ── Photos ─────────────────────────────────────────────────────────────────

  @override
  Stream<List<LocalPhotoQueueItem>> watchPendingPhotos() =>
      _poll(() async => _photoQueue.values
          .where((p) =>
              (p.syncStatus == 'pending' || p.syncStatus == 'failed') &&
              (p.nextRetryAt == null ||
                  p.nextRetryAt!.isBefore(DateTime.now())))
          .toList());

  @override
  Future<int> queuePhoto(String expenseId, String localPath) async {
    final id = _photoIdSeq++;
    _photoQueue[id] = LocalPhotoQueueItem(
      id: id, expenseId: expenseId, localPath: localPath,
      syncStatus: 'pending', retryCount: 0,
      createdAt: DateTime.now(),
    );
    return id;
  }

  @override
  Future<void> markPhotoUploaded(int id) async =>
      _photoQueue.remove(id);

  @override
  Future<void> markPhotoFailed(int id, int retryCount) async {
    final p = _photoQueue[id];
    if (p != null) {
      _photoQueue[id] = LocalPhotoQueueItem(
        id: id, expenseId: p.expenseId, localPath: p.localPath,
        syncStatus: 'failed', retryCount: retryCount + 1,
        nextRetryAt: DateTime.now().add(
            Duration(seconds: (60 * (retryCount + 1)).clamp(60, 3600))),
        createdAt: p.createdAt,
      );
    }
  }

  // ── Sync meta ──────────────────────────────────────────────────────────────

  @override
  Future<DateTime?> getLastSyncedAt(String orgId) async => _syncMeta[orgId];

  @override
  Future<void> updateLastSyncedAt(String orgId) async =>
      _syncMeta[orgId] = DateTime.now();

  @override
  Future<void> close() async {}

  @override
  set testDatabase(dynamic db) {}

  // ── Utility ────────────────────────────────────────────────────────────────

  Stream<T> _poll<T>(Future<T> Function() fetch) {
    late StreamController<T> ctrl;
    Timer? timer;
    ctrl = StreamController<T>(
      onListen: () {
        fetch().then((v) { if (!ctrl.isClosed) ctrl.add(v); });
        timer = Timer.periodic(const Duration(seconds: 2), (_) async {
          try {
            final v = await fetch();
            if (!ctrl.isClosed) ctrl.add(v);
          } catch (e) {
            if (!ctrl.isClosed) ctrl.addError(e);
          }
        });
      },
      onCancel: () => timer?.cancel(),
    );
    return ctrl.stream;
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// SHARED MODEL CLASSES
// ═══════════════════════════════════════════════════════════════════════════

class LocalProject {
  final String id;
  final String organizationId;
  final String name;
  final String? locationText;
  final double? latitude;
  final double? longitude;
  final double? totalBudget;
  final String currency;
  final String? startDate;
  final String? targetEndDate;
  final String status;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastSyncedAt;

  const LocalProject({
    required this.id,
    required this.organizationId,
    required this.name,
    this.locationText,
    this.latitude,
    this.longitude,
    this.totalBudget,
    this.currency = 'ETB',
    this.startDate,
    this.targetEndDate,
    this.status = 'active',
    this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.lastSyncedAt,
  });

  factory LocalProject.fromJson(Map<String, dynamic> json) => LocalProject(
        id: json['id'] as String,
        organizationId: json['organization_id'] as String,
        name: json['name'] as String,
        locationText: json['location_text'] as String?,
        latitude: parseDouble(json['latitude']),
        longitude: parseDouble(json['longitude']),
        totalBudget: parseDouble(json['total_budget']),
        currency: json['currency'] as String? ?? 'ETB',
        startDate: json['start_date'] as String?,
        targetEndDate: json['target_end_date'] as String?,
        status: json['status'] as String? ?? 'active',
        createdBy: json['created_by'] as String?,
        createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
        updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? '') ?? DateTime.now(),
      );
}

class LocalExpense {
  final String id;
  final String projectId;
  final String? costCodeId;
  final String enteredBy;
  final String? supplierId;
  final String? description;
  final double amount;
  final double? quantity;
  final String? unit;
  final String expenseType;
  final String? receiptPhotoUrl;
  final String? receiptPhotoLocalPath;
  final String transactionDate;
  final String syncStatus;
  final String? serverId;
  final String? conflictPayload;
  final DateTime createdAt;
  final DateTime updatedAt;

  const LocalExpense({
    required this.id,
    required this.projectId,
    this.costCodeId,
    required this.enteredBy,
    this.supplierId,
    this.description,
    required this.amount,
    this.quantity,
    this.unit,
    required this.expenseType,
    this.receiptPhotoUrl,
    this.receiptPhotoLocalPath,
    required this.transactionDate,
    this.syncStatus = 'pending',
    this.serverId,
    this.conflictPayload,
    required this.createdAt,
    required this.updatedAt,
  });
}

class LocalLaborEntry {
  final String id;
  final String projectId;
  final String? costCodeId;
  final String enteredBy;
  final String workerOrCrewName;
  final String? workDescription;
  final int numberOfWorkers;
  final double? dailyRate;
  final double totalAmount;
  final String workDate;
  final String syncStatus;
  final String? serverId;
  final DateTime createdAt;

  const LocalLaborEntry({
    required this.id,
    required this.projectId,
    this.costCodeId,
    required this.enteredBy,
    required this.workerOrCrewName,
    this.workDescription,
    this.numberOfWorkers = 1,
    this.dailyRate,
    required this.totalAmount,
    required this.workDate,
    this.syncStatus = 'pending',
    this.serverId,
    required this.createdAt,
  });
}

class LocalPhotoQueueItem {
  final int id;
  final String expenseId;
  final String localPath;
  final String syncStatus;
  final int retryCount;
  final DateTime? nextRetryAt;
  final DateTime createdAt;

  const LocalPhotoQueueItem({
    required this.id,
    required this.expenseId,
    required this.localPath,
    required this.syncStatus,
    required this.retryCount,
    this.nextRetryAt,
    required this.createdAt,
  });
}

/// Public schema SQL — exposed for testing.
const List<String> schemaSql = [];
