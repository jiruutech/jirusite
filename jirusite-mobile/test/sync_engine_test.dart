import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:jirusite_mobile/core/database/app_database_native.dart';
import 'package:jirusite_mobile/core/database/app_database.dart'
    show LocalProject, LocalExpense, LocalLaborEntry;

/// Creates an in-memory AppDatabase for unit tests.
Future<NativeAppDatabase> createTestDb() async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  final rawDb = await databaseFactoryFfi.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(
      version: 1,
      onCreate: (db, _) async {
        for (final stmt in schemaSql) {
          await db.execute(stmt);
        }
      },
    ),
  );

  final db = NativeAppDatabase();
  db.testDatabase = rawDb;
  return db;
}

void main() {
  late NativeAppDatabase db;

  setUp(() async => db = await createTestDb());
  tearDown(() => db.close());

  // ── Expense tests ──────────────────────────────────────────────────────────

  group('Expenses', () {
    test('insert records as pending and can be retrieved', () async {
      await db.insertExpense(LocalExpense(
        id: 'exp-001',
        projectId: 'proj-001',
        enteredBy: 'user-001',
        amount: 5000,
        expenseType: 'material',
        transactionDate: '2026-08-01',
        createdAt: DateTime(2026, 8, 1),
        updatedAt: DateTime(2026, 8, 1),
      ));

      final pending = await db.getPendingExpenses();
      expect(pending.length, equals(1));
      expect(pending.first.id, equals('exp-001'));
      expect(pending.first.amount, equals(5000));
      expect(pending.first.syncStatus, equals('pending'));
    });

    test('markExpenseSynced removes from pending list', () async {
      await db.insertExpense(LocalExpense(
        id: 'exp-002',
        projectId: 'proj-001',
        enteredBy: 'user-001',
        amount: 1200,
        expenseType: 'labor',
        transactionDate: '2026-08-02',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      await db.markExpenseSynced('exp-002', 'server-abc');

      expect(await db.getPendingExpenses(), isEmpty);
    });

    test('markExpenseConflict sets conflict — no longer pending', () async {
      await db.insertExpense(LocalExpense(
        id: 'exp-003',
        projectId: 'proj-001',
        enteredBy: 'user-001',
        amount: 999,
        expenseType: 'equipment',
        transactionDate: '2026-08-03',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      await db.markExpenseConflict('exp-003', '{"server":"data"}');

      expect(await db.getPendingExpenses(), isEmpty);
    });

    test('batch insert — all returned as pending', () async {
      for (var i = 1; i <= 5; i++) {
        await db.insertExpense(LocalExpense(
          id: 'batch-exp-$i',
          projectId: 'proj-001',
          enteredBy: 'user-001',
          amount: i * 100.0,
          expenseType: 'material',
          transactionDate: '2026-08-0$i',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ));
      }
      expect((await db.getPendingExpenses()).length, equals(5));
    });

    test('synced expenses do not appear in pending list', () async {
      await db.insertExpense(LocalExpense(
        id: 'exp-synced',
        projectId: 'proj-001',
        enteredBy: 'user-001',
        amount: 300,
        expenseType: 'material',
        transactionDate: '2026-08-01',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        syncStatus: 'synced',
      ));

      expect(await db.getPendingExpenses(), isEmpty);
    });
  });

  // ── Labor tests ────────────────────────────────────────────────────────────

  group('Labor', () {
    test('insert and retrieve pending labor entry', () async {
      await db.insertLabor(LocalLaborEntry(
        id: 'lab-001',
        projectId: 'proj-001',
        enteredBy: 'user-001',
        workerOrCrewName: 'Rebar Crew',
        totalAmount: 3600,
        workDate: '2026-08-01',
        createdAt: DateTime.now(),
      ));

      final pending = await db.getPendingLabor();
      expect(pending.length, equals(1));
      expect(pending.first.workerOrCrewName, equals('Rebar Crew'));
    });

    test('markLaborSynced removes from pending', () async {
      await db.insertLabor(LocalLaborEntry(
        id: 'lab-002',
        projectId: 'proj-001',
        enteredBy: 'user-001',
        workerOrCrewName: 'Masonry Crew',
        totalAmount: 4800,
        workDate: '2026-08-02',
        createdAt: DateTime.now(),
      ));

      await db.markLaborSynced('lab-002', 'server-lab-001');

      expect(await db.getPendingLabor(), isEmpty);
    });

    test('number_of_workers defaults to 1', () async {
      await db.insertLabor(LocalLaborEntry(
        id: 'lab-003',
        projectId: 'proj-001',
        enteredBy: 'user-001',
        workerOrCrewName: 'Solo Worker',
        totalAmount: 450,
        workDate: '2026-08-03',
        createdAt: DateTime.now(),
      ));

      final pending = await db.getPendingLabor();
      expect(pending.first.numberOfWorkers, equals(1));
    });
  });

  // ── Project tests ──────────────────────────────────────────────────────────

  group('Projects', () {
    test('upsert and retrieve by id', () async {
      await db.upsertProject(LocalProject(
        id: 'proj-001',
        organizationId: 'org-001',
        name: 'Bole Residential',
        currency: 'ETB',
        status: 'active',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      ));

      final p = await db.getProject('proj-001');
      expect(p, isNotNull);
      expect(p!.name, equals('Bole Residential'));
    });

    test('upsert is idempotent — second call updates', () async {
      final base = LocalProject(
        id: 'proj-upd',
        organizationId: 'org-001',
        name: 'Before',
        currency: 'ETB',
        status: 'planning',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await db.upsertProject(base);

      await db.upsertProject(LocalProject(
        id: 'proj-upd',
        organizationId: 'org-001',
        name: 'After',
        currency: 'ETB',
        status: 'active',
        createdAt: base.createdAt,
        updatedAt: DateTime.now(),
      ));

      final fetched = await db.getProject('proj-upd');
      expect(fetched!.name, equals('After'));
      expect(fetched.status, equals('active'));
    });

    test('getProjects scopes to organization', () async {
      await db.upsertProject(LocalProject(
        id: 'p-org1',
        organizationId: 'org-001',
        name: 'Org1 Project',
        currency: 'ETB',
        status: 'active',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));
      await db.upsertProject(LocalProject(
        id: 'p-org2',
        organizationId: 'org-002',
        name: 'Org2 Project',
        currency: 'ETB',
        status: 'active',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      final result = await db.getProjects('org-001');
      expect(result.length, equals(1));
      expect(result.first.organizationId, equals('org-001'));
    });
  });

  // ── Sync meta tests ────────────────────────────────────────────────────────

  group('SyncMeta', () {
    test('returns null before first sync', () async {
      expect(await db.getLastSyncedAt('org-001'), isNull);
    });

    test('persists and retrieves last synced timestamp', () async {
      final before = DateTime.now().subtract(const Duration(seconds: 1));
      await db.updateLastSyncedAt('org-001');
      final ts = await db.getLastSyncedAt('org-001');

      expect(ts, isNotNull);
      expect(ts!.isAfter(before), isTrue);
    });

    test('upsert is safe to call multiple times', () async {
      await db.updateLastSyncedAt('org-001');
      await db.updateLastSyncedAt('org-001');
      final ts = await db.getLastSyncedAt('org-001');
      expect(ts, isNotNull);
    });
  });

  // ── Photo queue tests ──────────────────────────────────────────────────────

  group('PhotoQueue', () {
    test('queue photo returns positive id', () async {
      final id = await db.queuePhoto('exp-001', '/tmp/receipt.jpg');
      expect(id, greaterThan(0));
    });

    test('uploaded photo not in pending list', () async {
      final id = await db.queuePhoto('exp-002', '/tmp/r2.jpg');
      await db.markPhotoUploaded(id);

      final pending = await db.watchPendingPhotos().first;
      expect(pending, isEmpty);
    });

    test('failed photo with future retry not in immediate pending', () async {
      final id = await db.queuePhoto('exp-003', '/tmp/r3.jpg');
      await db.markPhotoFailed(id, 0); // sets next_retry_at 60s in future

      final pending = await db.watchPendingPhotos().first;
      expect(pending, isEmpty,
          reason: 'Backed-off photo should not appear until retry window');
    });
  });
}
