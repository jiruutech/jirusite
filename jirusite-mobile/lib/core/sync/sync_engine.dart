import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
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
      // Push local pending items first, then pull server state
      final expResult = await _pushPendingExpenses();
      final labResult = await _pushPendingLabor();
      await _pullProjects();          // pulls total_spent from server
      await _pullExpensesAndLabor();  // pulls all server expenses/labor into local DB
      await _uploadPendingPhotos();   // upload queued receipt photos

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

  /// Pull all expenses and labor entries for every project from the server
  /// and upsert them into the local DB so list screens show server data.
  Future<void> _pullExpensesAndLabor() async {
    try {
      final projects = await db.getProjects(_organizationId!);
      for (final project in projects) {
        await _pullExpensesForProject(project.id);
        await _pullLaborForProject(project.id);
      }
    } catch (e) {
      debugPrint('[SyncEngine] Pull expenses/labor failed: $e');
    }
  }

  Future<void> _pullExpensesForProject(String projectId) async {
    try {
      final resp = await dio.get(ApiEndpoints.projectExpenses(projectId));
      final list = (resp.data as List).cast<Map<String, dynamic>>();
      final expenses = list.map((e) => LocalExpense(
        id: e['client_generated_id'] as String? ?? e['id'] as String,
        projectId: e['project_id'] as String,
        costCodeId: e['cost_code_id'] as String?,
        enteredBy: e['entered_by'] as String,
        supplierId: e['supplier_id'] as String?,
        description: e['description'] as String?,
        amount: (e['amount'] as num).toDouble(),
        quantity: (e['quantity'] as num?)?.toDouble(),
        unit: e['unit'] as String?,
        expenseType: e['expense_type'] as String,
        receiptPhotoUrl: e['receipt_photo_url'] as String?,
        transactionDate: e['transaction_date'] as String,
        syncStatus: 'synced',
        serverId: e['id'] as String,
        createdAt: DateTime.tryParse(e['created_at'] as String? ?? '') ?? DateTime.now(),
        updatedAt: DateTime.tryParse(e['updated_at'] as String? ?? '') ?? DateTime.now(),
      )).toList();
      await db.upsertExpenses(expenses);
    } catch (e) {
      debugPrint('[SyncEngine] Pull expenses for $projectId failed: $e');
    }
  }

  Future<void> _pullLaborForProject(String projectId) async {
    try {
      final resp = await dio.get(ApiEndpoints.projectLabor(projectId));
      final list = (resp.data as List).cast<Map<String, dynamic>>();
      final entries = list.map((e) => LocalLaborEntry(
        id: e['client_generated_id'] as String? ?? e['id'] as String,
        projectId: e['project_id'] as String,
        costCodeId: e['cost_code_id'] as String?,
        enteredBy: e['entered_by'] as String,
        workerOrCrewName: e['worker_or_crew_name'] as String,
        workDescription: e['work_description'] as String?,
        numberOfWorkers: e['number_of_workers'] as int? ?? 1,
        dailyRate: (e['daily_rate'] as num?)?.toDouble(),
        totalAmount: (e['total_amount'] as num).toDouble(),
        workDate: e['work_date'] as String,
        syncStatus: 'synced',
        serverId: e['id'] as String,
        createdAt: DateTime.tryParse(e['created_at'] as String? ?? '') ?? DateTime.now(),
      )).toList();
      await db.upsertLaborEntries(entries);
    } catch (e) {
      debugPrint('[SyncEngine] Pull labor for $projectId failed: $e');
    }
  }

  /// Upload queued receipt photos to the server.
  Future<void> _uploadPendingPhotos() async {
    if (kIsWeb) return;
    try {
      final pending = await db.watchPendingPhotos().first;
      for (final photo in pending) {
        try {
          final file = File(photo.localPath);
          if (!file.existsSync()) {
            // Local file gone — mark done to clear queue
            await db.markPhotoUploaded(photo.id);
            continue;
          }

          // photo.expenseId is the client_generated_id (UUID we generated locally).
          // The server expense record has this stored as client_generated_id.
          // POST /expenses/:clientGeneratedId/receipt — backend looks up by CGI
          final formData = FormData.fromMap({
            'receipt': await MultipartFile.fromFile(
              photo.localPath,
              filename: '${photo.expenseId}.jpg',
            ),
          });

          final resp = await dio.postFormData(
            ApiEndpoints.expenseReceipt(photo.expenseId),
            formData,
          );

          final url = resp.data['receipt_photo_url'] as String?;
          if (url != null) {
            await db.markPhotoUploaded(photo.id);
            debugPrint('[SyncEngine] Photo uploaded: $url');
          }
        } catch (e) {
          debugPrint('[SyncEngine] Photo upload failed for ${photo.id}: $e');
          await db.markPhotoFailed(photo.id, photo.retryCount);
        }
      }
    } catch (e) {
      debugPrint('[SyncEngine] _uploadPendingPhotos failed: $e');
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
