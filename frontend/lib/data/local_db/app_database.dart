import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/foundation.dart';

part 'app_database.g.dart';

class LocalProducts extends Table {
  TextColumn get id => text()();
  TextColumn get artisanId => text()();
  TextColumn get category => text().withDefault(const Constant('Pottery'))();
  RealColumn get price => real()();
  RealColumn get costPrice => real().nullable()();
  TextColumn get status => text().withDefault(const Constant('active'))();
  IntColumn get stockQuantity => integer().withDefault(const Constant(1))();
  TextColumn get primaryImageUrl => text().nullable()();
  TextColumn get enhancedImageUrl => text().nullable()();
  TextColumn get originalAudioUrl => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class LocalProductTranslations extends Table {
  TextColumn get id => text()();
  TextColumn get productId => text()();
  TextColumn get languageCode => text()();
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  TextColumn get tags => text().nullable()();
  TextColumn get materials => text().nullable()();
  TextColumn get careInstructions => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class LocalOrders extends Table {
  TextColumn get id => text()();
  TextColumn get artisanId => text()();
  TextColumn get customerName => text()();
  TextColumn get customerPhone => text()();
  TextColumn get customerAddress => text()();
  RealColumn get totalAmount => real()();
  TextColumn get status => text().withDefault(const Constant('pending'))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class LocalSyncQueue extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get clientId => text()();
  TextColumn get entityType => text()();
  TextColumn get entityId => text()();
  TextColumn get action => text()(); // create, update, delete
  TextColumn get payloadJson => text()();
  TextColumn get status => text().withDefault(const Constant('pending'))(); // pending, syncing, synced, failed
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
}

@DriftDatabase(tables: [
  LocalProducts,
  LocalProductTranslations,
  LocalOrders,
  LocalSyncQueue,
])
class AppDatabase extends _$AppDatabase {
  static AppDatabase? _instance;
  static AppDatabase get instance => _instance ??= AppDatabase._();

  AppDatabase._([QueryExecutor? e]) : super(e ?? driftDatabase(name: 'kalasetu_db'));

  factory AppDatabase([QueryExecutor? e]) {
    if (e != null) {
      return AppDatabase._(e);
    }
    return instance;
  }

  @visibleForTesting
  static void setInstanceForTesting(AppDatabase db) {
    _instance = db;
  }

  @override
  int get schemaVersion => 1;

  // --- Products Queries ---
  Stream<List<LocalProduct>> watchAllProducts() {
    return (select(localProducts)
          ..where((t) => t.status.isIn(['live', 'active', 'pending_sync', 'sold_out', 'draft']))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch();
  }

  Future<List<LocalProduct>> getAllProducts() {
    return (select(localProducts)
          ..where((t) => t.status.isIn(['live', 'active', 'pending_sync', 'sold_out', 'draft']))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
  }

  Future<LocalProduct?> getProductById(String id) {
    return (select(localProducts)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<void> upsertProduct(LocalProduct product) {
    return into(localProducts).insertOnConflictUpdate(product);
  }

  Future<void> deleteProduct(String id) {
    return (delete(localProducts)..where((t) => t.id.equals(id))).go();
  }

  // --- Translations Queries ---
  Future<List<LocalProductTranslation>> getTranslationsForProduct(String productId) {
    return (select(localProductTranslations)..where((t) => t.productId.equals(productId))).get();
  }

  Stream<List<LocalProductTranslation>> watchTranslationsForProduct(String productId) {
    return (select(localProductTranslations)..where((t) => t.productId.equals(productId))).watch();
  }

  Future<void> upsertTranslation(LocalProductTranslation translation) {
    return into(localProductTranslations).insertOnConflictUpdate(translation);
  }

  // --- Orders Queries ---
  Stream<List<LocalOrder>> watchOrders() {
    return (select(localOrders)..orderBy([(t) => OrderingTerm.desc(t.createdAt)])).watch();
  }

  Future<List<LocalOrder>> getAllOrders() {
    return (select(localOrders)..orderBy([(t) => OrderingTerm.desc(t.createdAt)])).get();
  }

  Future<void> upsertOrder(LocalOrder order) {
    return into(localOrders).insertOnConflictUpdate(order);
  }

  Future<void> updateOrderStatus(String orderId, String newStatus) {
    return (update(localOrders)..where((t) => t.id.equals(orderId)))
        .write(LocalOrdersCompanion(status: Value(newStatus)));
  }

  Future<int> getUnreadOrderCount() async {
    final count = localOrders.id.count();
    final query = selectOnly(localOrders)
      ..addColumns([count])
      ..where(localOrders.status.equals('new') | localOrders.status.equals('pending'));
    final row = await query.getSingle();
    return row.read(count) ?? 0;
  }

  // --- Sync Queue Queries ---
  Stream<int> watchPendingSyncCount() {
    final count = localSyncQueue.id.count();
    final query = selectOnly(localSyncQueue)
      ..addColumns([count])
      ..where(localSyncQueue.status.equals('pending') | localSyncQueue.status.equals('failed'));
    return query.map((row) => row.read(count) ?? 0).watchSingle();
  }

  Future<List<LocalSyncQueueData>> getPendingSyncItems() {
    return (select(localSyncQueue)
          ..where((t) => t.status.equals('pending') | t.status.equals('failed'))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();
  }

  /// Allowed entity types for offline sync queue (only real data changes: products, orders, edits, profile).
  /// Ephemeral requests like TTS/voice must NEVER enter the sync queue.
  static const Set<String> allowedSyncEntityTypes = {
    'product',
    'products',
    'order',
    'orders',
    'edit',
    'edits',
    'profile',
    'artisan',
  };

  Future<int> enqueueSyncItem(LocalSyncQueueCompanion item) {
    final type = item.entityType.value.toLowerCase().trim();
    if (type == 'tts' || type == 'voice' || !allowedSyncEntityTypes.contains(type)) {
      debugPrint('[AppDatabase] Refusing to enqueue sync item with non-data entityType: $type');
      return Future.value(-1);
    }
    return into(localSyncQueue).insert(item);
  }

  /// Removes any queued TTS/voice or non-data items from the sync queue on startup
  Future<int> removeQueuedTtsItems() {
    return (delete(localSyncQueue)
          ..where((t) =>
              t.entityType.equals('tts') |
              t.entityType.equals('voice') |
              t.entityType.isIn(allowedSyncEntityTypes.toList()).not()))
        .go();
  }

  Future<void> deleteSyncItem(int id) {
    return (delete(localSyncQueue)..where((t) => t.id.equals(id))).go();
  }

  Future<void> markSyncItemSynced(int id) {
    return (update(localSyncQueue)..where((t) => t.id.equals(id)))
        .write(const LocalSyncQueueCompanion(status: Value('synced')));
  }

  Future<void> markSyncItemFailed(int id, int currentRetries) {
    return (update(localSyncQueue)..where((t) => t.id.equals(id))).write(
      LocalSyncQueueCompanion(
        status: const Value('failed'),
        retryCount: Value(currentRetries + 1),
      ),
    );
  }
}
