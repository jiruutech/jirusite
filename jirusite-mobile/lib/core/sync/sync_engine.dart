import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/app_database.dart';
import '../network/api_endpoints.dart';
import '../network/dio_client.dart';
import '../network/connectivity_service.dart';

enum SyncStatus { idle, syncing, error }

final syncStatusProvider =
    StateProvider<SyncStatus>((_) => SyncStatus.idle);
final pendingCountProvider = StateProvider<int>((_) => 0);

final syncEngineProvider = Provider<SyncEngine>((ref) {
  final db = ref.read(appDatabaseProvider);
  final dio = ref.read(dioClientProvider);
  final engine = SyncEngine(db: db, dio: dio, ref: ref);
  ref.onDispose(engine.dispose);
  return engine;
});

class SyncEngine {
  SyncEngine({required this.db, required this.dio, required this.ref});

  final AppDatabase db;
  final DioClient dio;
  final Ref ref;

  Timer? _periodicTimer;
  bool _isSyncing = false;
  String? _organizationId;

  void initialize(String organizationId) {
    _organizationId = organizationId;
    _startPeriodicTimer();
    ref.listen(connectivityProvider, (_, next) {
      if (next.valueOrNull == true) {
        debugPrint('[SyncEngine] Connectivity restored — triggering sync');
        sync().ignore();
      }
    });
  }

  void _startPeriodicTimer() {
    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(const Duration(minutes: 5), (_) async {
      if (await checkConnectivity()) await sync();
    });
  }

  Future<SyncResult> sync() async {
    if (_isSyncing || _organizationId == null) return SyncResult.skipped();

    _isSyncing = true;
    ref.read(syncStatusProvider.notifier).state = SyncStatus.syncing;

    try {
      final expResult = await _pushPendingExpenses();
      final labResult = await _pushPendingLabor();
      await _pullProjects();

      await db.updateLastSyncedAt(_organizationId!);

      final remaining =
          expResult.pendingRemaining + labResult.pendingRemaining;
      ref.read(pendingCountProvider.notifier).state = remaining;
      ref.read(syncStatusProvider.notifier).state =
          remaining > 0 ? SyncStatus.error : SyncStatus.idle;

      debugPrint('[SyncEngine] ✓ expenses=${expResult.synced} '
          'labor=${labResult.synced} conflicts=${expResult.conflicts}');

      return SyncResult(
        expensesSynced: expResult.synced,
        laborSynced: labResult.synced,
        conflicts: expResult.conflicts,
      );
    } catch (e, st) {
      debugPrint('[SyncEngine] ✗ $e\n$st');
      ref.read(syncStatusProvider.notifier).state = SyncStatus.error;
      return SyncResult.withError(e.toString());
    } finally {
      _isSyncing = false;
    }
  }

  Future<_BatchResult> _pushPendingExpenses() async {
    final pending = await db.getPendingExpenses();
    if (pending.isEmpty) return _BatchResult.empty();

    final payload = pending.map((e) => {
          'project_id': e.projectId,
          'cost_code_id': e.costCodeId,
          'supplier_id': e.supplierId,
          'description': e.description,
          'amount': e.amount,
          'quantity': e.quantity,
          'unit': e.unit,
          'expense_type': e.expenseType,
          'transaction_date': e.transactionDate,
          'client_generated_id': e.id,
        }).toList();

    final resp = await dio.post(
      ApiEndpoints.expenseSyncBatch,
      data: {'expenses': payload},
    );

    final synced = (resp.data['synced'] as List?) ?? [];
    final conflicts = (resp.data['conflicts'] as List?) ?? [];

    for (final row in synced) {
      final cid = row['client_generated_id'] as String?;
      final sid = row['id'] as String?;
      if (cid != null && sid != null) await db.markExpenseSynced(cid, sid);
    }
    for (final c in conflicts) {
      final cid = c['client_generated_id'] as String?;
      if (cid != null) {
        await db.markExpenseConflict(cid, jsonEncode(c));
      }
    }

    final remaining = (await db.getPendingExpenses()).length;
    return _BatchResult(
      synced: synced.length,
      conflicts: conflicts.length,
      pendingRemaining: remaining,
    );
  }

  Future<_BatchResult> _pushPendingLabor() async {
    final pending = await db.getPendingLabor();
    if (pending.isEmpty) return _BatchResult.empty();

    final payload = pending.map((l) => {
          'project_id': l.projectId,
          'cost_code_id': l.costCodeId,
          'worker_or_crew_name': l.workerOrCrewName,
          'work_description': l.workDescription,
          'number_of_workers': l.numberOfWorkers,
          'daily_rate': l.dailyRate,
          'total_amount': l.totalAmount,
          'work_date': l.workDate,
          'client_generated_id': l.id,
        }).toList();

    final resp = await dio.post(
      ApiEndpoints.laborSyncBatch,
      data: {'entries': payload},
    );

    final synced = (resp.data['synced'] as List?) ?? [];
    for (final row in synced) {
      final cid = row['client_generated_id'] as String?;
      final sid = row['id'] as String?;
      if (cid != null && sid != null) await db.markLaborSynced(cid, sid);
    }

    final remaining = (await db.getPendingLabor()).length;
    return _BatchResult(
        synced: synced.length, conflicts: 0, pendingRemaining: remaining);
  }

  Future<void> _pullProjects() async {
    try {
      final resp = await dio.get(ApiEndpoints.projects);
      final list = (resp.data as List).cast<Map<String, dynamic>>();
      await db.upsertProjects(list.map(LocalProject.fromJson).toList());
    } catch (e) {
      debugPrint('[SyncEngine] Pull projects failed: $e');
    }
  }

  Future<int> getPendingCount() async {
    final e = await db.getPendingExpenses();
    final l = await db.getPendingLabor();
    return e.length + l.length;
  }

  void dispose() => _periodicTimer?.cancel();
}

class SyncResult {
  final int expensesSynced;
  final int laborSynced;
  final int conflicts;
  final bool skipped;
  final String? error;

  const SyncResult({
    this.expensesSynced = 0,
    this.laborSynced = 0,
    this.conflicts = 0,
    this.skipped = false,
    this.error,
  });

  factory SyncResult.skipped() => const SyncResult(skipped: true);
  factory SyncResult.withError(String e) => SyncResult(error: e);
}

class _BatchResult {
  final int synced;
  final int conflicts;
  final int pendingRemaining;

  const _BatchResult({
    required this.synced,
    required this.conflicts,
    required this.pendingRemaining,
  });

  factory _BatchResult.empty() =>
      const _BatchResult(synced: 0, conflicts: 0, pendingRemaining: 0);
}
