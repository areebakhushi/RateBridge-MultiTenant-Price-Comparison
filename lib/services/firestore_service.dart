import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/rfq_model.dart';
import '../models/rfq_bid_model.dart';
import '../models/dispute_model.dart';
import '../models/audit_log_model.dart';
import '../models/user_model.dart';
import '../models/company_model.dart';
import '../models/supplier_model.dart';
import '../models/material_model.dart';
import '../models/order_model.dart';
import '../models/chat_message_model.dart';
import '../models/rating_model.dart';
import '../models/subscription_model.dart';
import '../models/chat_thread_model.dart';
import '../models/price_history_model.dart';
import '../models/invitation_model.dart';
import '../models/join_request_model.dart';
import '../models/notification_model.dart';
import '../models/category_model.dart';
import '../utils/seed_data_guard.dart';
import '../utils/app_exception.dart';

class FirestoreService {
  final FirebaseFirestore _db;

  FirestoreService({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  Never _rethrowFirestore(Object error) {
    if (error is AppException) throw error;
    if (error is FirebaseException) {
      if (error.code == 'permission-denied') {
        throw AppException(
          "You don't have permission to perform this action. Please contact support if this continues.",
          'permission-denied',
        );
      }
      final message = error.message?.trim();
      throw AppException(
        (message != null && message.isNotEmpty)
            ? message
            : 'Something went wrong. Please try again.',
        error.code,
      );
    }
    throw error;
  }

  Map<String, dynamic> _requireDocData(DocumentSnapshot doc) {
    final data = doc.data();
    if (data == null) {
      throw StateError('Document ${doc.reference.path} has no data');
    }
    return Map<String, dynamic>.from(data as Map);
  }

  Map<String, dynamic> _queryDocData(QueryDocumentSnapshot doc) {
    return Map<String, dynamic>.from(doc.data() as Map);
  }

  // --- Users ---
  Future<UserModel?> getUser(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (doc.exists && doc.data() != null) {
      final data = _requireDocData(doc);
      // Ensure uid is set from document ID if missing in data
      if (data['uid'] == null || (data['uid'] as String).isEmpty) {
        data['uid'] = doc.id;
      }
      return UserModel.fromMap(data);
    }
    return null;
  }

  Future<void> saveUser(UserModel user) async {
    await _db.collection('users').doc(user.uid).set(user.toMap());
  }

  Future<List<String>> getAdminUserIds() async {
    final query = await _db.collection('users').where('role', whereIn: [
      'Admin',
      'admin',
      'ADMIN',
      'Administrator',
      'administrator',
      'ADMINISTRATOR',
    ]).get();
    return query.docs.map((doc) => doc.id).toList();
  }

  // --- Companies ---
  Future<CompanyModel?> getCompany(String companyId) async {
    final doc = await _db.collection('companies').doc(companyId).get();
    if (doc.exists && doc.data() != null) {
      final data = _requireDocData(doc);
      if (data['id'] == null || (data['id'] as String).isEmpty) {
        data['id'] = doc.id;
      }
      return CompanyModel.fromMap(data);
    }
    return null;
  }

  Future<List<CompanyModel>> getCompanies() async {
    final snap = await _db.collection('companies').get();
    return snap.docs.map((doc) {
      final data = doc.data();
      if (data['id'] == null || (data['id'] as String).isEmpty) {
        data['id'] = doc.id;
      }
      return CompanyModel.fromMap(data);
    }).toList();
  }

  Future<void> saveCompany(CompanyModel company) async {
    await _db.collection('companies').doc(company.id).set(company.toMap());
  }

  // --- Suppliers ---
  Stream<List<SupplierModel>> streamSuppliers() {
    return _db
        .collection('suppliers')
        .snapshots()
        .map(
          (snap) =>
              snap.docs
                  .map((doc) => SupplierModel.fromMap(doc.data() as Map<String, dynamic>))
                  .toList(),
        );
  }

  Future<void> saveSupplier(SupplierModel supplier) async {
    await _db.collection('suppliers').doc(supplier.id).set(supplier.toMap());
  }

  Future<SupplierModel?> getSupplierById(String supplierUid) async {
    final doc = await _db.collection('suppliers').doc(supplierUid).get();
    if (!doc.exists || doc.data() == null) return null;
    final data = _requireDocData(doc);
    return SupplierModel.fromMap({...data, 'id': doc.id});
  }

  // --- Materials ---
  Stream<List<MaterialModel>> streamMaterials() {
    return _db
        .collection('materials')
        .snapshots()
        .map(
          (snap) =>
              snap.docs
                  .map((doc) => MaterialModel.fromMap(doc.data() as Map<String, dynamic>))
                  .where((m) => m.isListed)
                  .toList(),
        );
  }

  Stream<List<MaterialModel>> streamCompanyMaterials(String companyId) {
    return _db
        .collection('companies')
        .doc(companyId)
        .collection('suppliers')
        .snapshots()
        .asyncExpand((suppliersSnap) {
          final supplierIds =
              suppliersSnap.docs
                  .where((doc) => _isActiveSupplierLink(doc.data() as Map<String, dynamic>))
                  .map((doc) => doc.id)
                  .where((id) => !SeedDataGuard.isSeedId(id))
                  .toList();

          if (supplierIds.isEmpty) {
            return Stream.value(<MaterialModel>[]);
          }

          return watchUnrestrictedSupplierIds(supplierIds).asyncMap(
            (visibleIds) => _materialsForSupplierIds(visibleIds),
          );
        });
  }

  Future<List<MaterialModel>> getRecentCompanyMaterials(
    String companyId, {
    int limit = 4,
  }) async {
    final supplierIds = await getCompanyLinkedSupplierIds(companyId);
    if (supplierIds.isEmpty) return [];

    final allMaterials = await _materialsForSupplierIds(supplierIds);

    allMaterials.sort((a, b) {
      final aDate = a.createdAt ?? _materialSortFallback(a.id);
      final bDate = b.createdAt ?? _materialSortFallback(b.id);
      return bDate.compareTo(aDate);
    });

    if (allMaterials.length <= limit) return allMaterials;
    return allMaterials.sublist(0, limit);
  }

  Future<List<MaterialModel>> _materialsForSupplierIds(
    List<String> supplierIds,
  ) async {
    if (supplierIds.isEmpty) return [];

    final chunks = <List<String>>[];
    for (var i = 0; i < supplierIds.length; i += 30) {
      chunks.add(
        supplierIds.sublist(
          i,
          i + 30 > supplierIds.length ? supplierIds.length : i + 30,
        ),
      );
    }

    final seenIds = <String>{};
    final allMaterials = <MaterialModel>[];

    void addFromDocs(
      Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    ) {
      for (final doc in docs) {
        final material = _materialFromDoc(doc.id, doc.data());
        if (SeedDataGuard.isSeedId(material.id) ||
            SeedDataGuard.isSeedId(material.supplierId)) {
          continue;
        }
        if (!material.isListed) continue;
        if (seenIds.add(material.id)) {
          allMaterials.add(material);
        }
      }
    }

    for (final chunk in chunks) {
      final bySupplierId =
          await _db
              .collection('materials')
              .where('supplierId', whereIn: chunk)
              .get();
      addFromDocs(bySupplierId.docs);

      final bySupplierUid =
          await _db
              .collection('materials')
              .where('supplierUid', whereIn: chunk)
              .get();
      addFromDocs(bySupplierUid.docs);
    }

    return allMaterials;
  }

  MaterialModel _materialFromDoc(String docId, Map<String, dynamic> data) {
    final map = Map<String, dynamic>.from(data);
    map['id'] = (map['id'] as String?)?.isNotEmpty == true ? map['id'] : docId;
    return MaterialModel.fromMap(map);
  }

  DateTime _materialSortFallback(String id) {
    final ms = int.tryParse(id);
    if (ms != null) return DateTime.fromMillisecondsSinceEpoch(ms);
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  Future<List<MaterialModel>> getPopularMaterials({String? companyId}) async {
    if (companyId != null && companyId.isNotEmpty) {
      return getRecentCompanyMaterials(companyId, limit: 10);
    }
    final snap = await _db.collection('materials').limit(10).get();
    return snap.docs
        .map((doc) => _materialFromDoc(doc.id, doc.data()))
        .where((m) => m.isListed)
        .toList();
  }

  Future<MaterialModel?> getMaterialById(String id) async {
    final doc = await _db.collection('materials').doc(id).get();
    if (!doc.exists || doc.data() == null) return null;
    return MaterialModel.fromMap(_requireDocData(doc));
  }

  Future<List<MaterialModel>> getMaterialsByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    final snap =
        await _db
            .collection('materials')
            .where(FieldPath.documentId, whereIn: ids)
            .get();
    return snap.docs
        .map((doc) => MaterialModel.fromMap(doc.data() as Map<String, dynamic>))
        .where((m) => m.isListed)
        .toList();
  }

  Future<List<MaterialModel>> searchMaterials(String query) async {
    final snap =
        await _db
            .collection('materials')
            .where('name', isGreaterThanOrEqualTo: query)
            .where('name', isLessThanOrEqualTo: '$query\uf8ff')
            .get();
    return snap.docs
        .map((doc) => MaterialModel.fromMap(doc.data() as Map<String, dynamic>))
        .where((m) => m.isListed)
        .toList();
  }

  Stream<List<MaterialModel>> streamCategoryMaterials(
    String category, {
    String? companyId,
    Map<String, dynamic>? filters,
    String? sort,
  }) {
    if (companyId != null) {
      return _db
          .collection('companies')
          .doc(companyId)
          .collection('suppliers')
          .snapshots()
          .asyncExpand((suppliersSnap) {
            final supplierIds =
                suppliersSnap.docs
                    .where((doc) => _isActiveSupplierLink(doc.data() as Map<String, dynamic>))
                    .map((doc) => doc.id)
                    .where((id) => !SeedDataGuard.isSeedId(id))
                    .toList();
            if (supplierIds.isEmpty) return Stream.value(<MaterialModel>[]);

            return watchUnrestrictedSupplierIds(supplierIds).asyncMap(
              (visibleIds) async {
                if (visibleIds.isEmpty) return <MaterialModel>[];

                final chunks = <List<String>>[];
                for (var i = 0; i < visibleIds.length; i += 30) {
                  chunks.add(
                    visibleIds.sublist(
                      i,
                      i + 30 > visibleIds.length ? visibleIds.length : i + 30,
                    ),
                  );
                }

                final filteredMaterials = <MaterialModel>[];
                for (final chunk in chunks) {
                  Query query = _db
                      .collection('materials')
                      .where('supplierId', whereIn: chunk)
                      .where('category', isEqualTo: category);

                  if (filters != null) {
                    filters.forEach((key, value) {
                      if (value != null) {
                        query = query.where(key, isEqualTo: value);
                      }
                    });
                  }

                  final materialsSnap = await query.get();
                  filteredMaterials.addAll(
                    materialsSnap.docs
                        .map(
                          (doc) => MaterialModel.fromMap(_queryDocData(doc)),
                        )
                        .where((m) => m.isListed),
                  );
                }

                if (sort == 'price_asc') {
                  filteredMaterials.sort(
                    (a, b) => a.pricePerUnit.compareTo(b.pricePerUnit),
                  );
                } else if (sort == 'price_desc') {
                  filteredMaterials.sort(
                    (a, b) => b.pricePerUnit.compareTo(a.pricePerUnit),
                  );
                }

                return filteredMaterials;
              },
            );
          });
    }

    Query query = _db
        .collection('materials')
        .where('category', isEqualTo: category);
    if (filters != null) {
      filters.forEach((key, value) {
        if (value != null) query = query.where(key, isEqualTo: value);
      });
    }
    if (sort != null) {
      if (sort == 'price_asc') {
        query = query.orderBy('pricePerUnit', descending: false);
      } else if (sort == 'price_desc') {
        query = query.orderBy('pricePerUnit', descending: true);
      }
    }
    return query.snapshots().map(
      (snap) =>
          snap.docs
              .map((doc) => MaterialModel.fromMap(_queryDocData(doc)))
              .where((m) => m.isListed)
              .toList(),
    );
  }

  Future<List<MaterialModel>> getApprovedSuppliersForMaterial(
    String materialName,
  ) async {
    final snap =
        await _db
            .collection('materials')
            .where('name', isEqualTo: materialName)
            .get();
    final materials = snap.docs
        .map((doc) => MaterialModel.fromMap(doc.data() as Map<String, dynamic>))
        .where((m) => m.isListed)
        .toList();
    if (materials.isEmpty) return materials;

    final supplierIds = materials
        .map((m) => m.supplierId)
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    final visibleIds = await filterUnrestrictedSupplierIds(supplierIds);
    final visible = visibleIds.toSet();
    return materials.where((m) => visible.contains(m.supplierId)).toList();
  }

  /// Linked supplier UIDs for a company (`companies/{id}/suppliers`, with
  /// optional fallback to `approvedSuppliers` on the company document).
  Future<List<String>> getCompanyLinkedSupplierIds(String companyId) async {
    final suppliersSnap =
        await _db
            .collection('companies')
            .doc(companyId)
            .collection('suppliers')
            .get();

    if (suppliersSnap.docs.isNotEmpty) {
      return suppliersSnap.docs
          .where((doc) => _isActiveSupplierLink(doc.data() as Map<String, dynamic>))
          .map((doc) => doc.id)
          .where((id) => !SeedDataGuard.isSeedId(id))
          .toList();
    }

    final companyDoc = await _db.collection('companies').doc(companyId).get();
    final approved = companyDoc.data()?['approvedSuppliers'];
    if (approved is List) {
      return approved
          .map((entry) => entry.toString())
          .where((id) => id.isNotEmpty)
          .toList();
    }
    return [];
  }

  bool _isActiveSupplierLink(Map<String, dynamic> data) {
    final status = (data['status'] as String?)?.toLowerCase() ?? 'active';
    return status == 'active' || status == 'approved';
  }

  bool _isCommissionRestricted(Map<String, dynamic>? data) =>
      data?['commissionRestricted'] == true;

  Future<List<String>> filterUnrestrictedSupplierIds(
    List<String> supplierIds,
  ) async {
    if (supplierIds.isEmpty) return [];
    final visible = <String>[];
    for (final id in supplierIds) {
      final doc = await _db.collection('suppliers').doc(id).get();
      if (!_isCommissionRestricted(doc.data() as Map<String, dynamic>?)) {
        visible.add(id);
      }
    }
    return visible;
  }

  /// Re-emits whenever any linked supplier's commission restriction flag changes.
  Stream<List<String>> watchUnrestrictedSupplierIds(List<String> supplierIds) {
    if (supplierIds.isEmpty) return Stream.value(const []);

    late StreamController<List<String>> controller;
    final subscriptions =
        <StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>>[];
    final restricted = <String, bool>{};

    void emitVisible() {
      if (controller.isClosed) return;
      controller.add(
        supplierIds.where((id) => restricted[id] != true).toList(),
      );
    }

    controller = StreamController<List<String>>.broadcast(
      onListen: () {
        for (final id in supplierIds) {
          restricted[id] = false;
          subscriptions.add(
            _db.collection('suppliers').doc(id).snapshots().listen((snap) {
              restricted[id] = _isCommissionRestricted(snap.data());
              emitVisible();
            }),
          );
        }
      },
      onCancel: () async {
        for (final sub in subscriptions) {
          await sub.cancel();
        }
        subscriptions.clear();
      },
    );

    return controller.stream;
  }

  String _normalizeMaterialName(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  /// Materials matching [materialName] from suppliers linked to [companyId].
  Future<List<MaterialModel>> getCompanyMaterialsByName(
    String companyId,
    String materialName,
  ) async {
    return getMaterialsByNameForCompany(companyId, materialName);
  }

  /// Materials from company-linked suppliers whose name matches [name].
  Future<List<MaterialModel>> getMaterialsByNameForCompany(
    String companyId,
    String name,
  ) async {
    final nameLower = _normalizeMaterialName(name);
    if (nameLower.isEmpty) return [];

    final supplierIds = await filterUnrestrictedSupplierIds(
      await getCompanyLinkedSupplierIds(companyId),
    );
    if (supplierIds.isEmpty) return [];
    final chunks = <List<String>>[];
    for (var i = 0; i < supplierIds.length; i += 30) {
      chunks.add(
        supplierIds.sublist(
          i,
          i + 30 > supplierIds.length ? supplierIds.length : i + 30,
        ),
      );
    }

    final matched = <MaterialModel>[];
    final seenIds = <String>{};

    void addMatches(Iterable<MaterialModel> items) {
      for (final material in items) {
        if (!material.isListed) continue;
        if (seenIds.add(material.id)) {
          matched.add(material);
        }
      }
    }

    for (final chunk in chunks) {
      final bySupplierId =
          await _db
              .collection('materials')
              .where('supplierId', whereIn: chunk)
              .get();
      addMatches(
        bySupplierId.docs
            .map((doc) => _materialFromDoc(doc.id, doc.data()))
            .where(
              (material) => _normalizeMaterialName(material.name) == nameLower,
            ),
      );

      final bySupplierUid =
          await _db
              .collection('materials')
              .where('supplierUid', whereIn: chunk)
              .get();
      addMatches(
        bySupplierUid.docs
            .map((doc) => _materialFromDoc(doc.id, doc.data()))
            .where(
              (material) => _normalizeMaterialName(material.name) == nameLower,
            ),
      );
    }
    return matched;
  }

  /// Materials from [supplierId] when that supplier is linked to [companyId].
  Future<List<MaterialModel>> getCompanyMaterialsBySupplier(
    String companyId,
    String supplierId,
  ) async {
    final link =
        await _db
            .collection('companies')
            .doc(companyId)
            .collection('suppliers')
            .doc(supplierId)
            .get();
    if (!link.exists) return [];
    final linkData = link.data();
    if (linkData == null || !_isActiveSupplierLink(linkData as Map<String, dynamic>)) return [];

    final supplierDoc = await _db.collection('suppliers').doc(supplierId).get();
    if (_isCommissionRestricted(supplierDoc.data() as Map<String, dynamic>?)) return [];

    final snap =
        await _db
            .collection('materials')
            .where('supplierId', isEqualTo: supplierId)
            .get();
    return snap.docs
        .map((doc) => MaterialModel.fromMap(doc.data() as Map<String, dynamic>))
        .where((m) => m.isListed)
        .toList();
  }

  /// Average rating from the ratings collection, matching supplier_viewmodel logic.
  Future<double> getSupplierAverageRating(String supplierUid) async {
    final stats = await getSupplierRatingStats(supplierUid);
    return stats.average;
  }

  /// Aggregated rating + review count in a single ratings query.
  Future<({double average, int count})> getSupplierRatingStats(
    String supplierUid,
  ) async {
    final snap =
        await _db
            .collection('ratings')
            .where('supplierUid', isEqualTo: supplierUid)
            .get();
    if (snap.docs.isEmpty) {
      final supplierDoc =
          await _db.collection('suppliers').doc(supplierUid).get();
      return (
        average: (supplierDoc.data()?['rating'] as num?)?.toDouble() ?? 0.0,
        count: 0,
      );
    }
    final ratings = snap.docs.map(
      (doc) => RatingModel.fromMap(doc.id, doc.data() as Map<String, dynamic>),
    );
    final sum = ratings.fold<double>(0, (acc, r) => acc + r.rating);
    return (average: sum / snap.docs.length, count: snap.docs.length);
  }

  /// Most recent priceHistory timestamp for a material listing.
  Future<DateTime?> getLatestMaterialPriceTimestamp(String materialId) async {
    final snap =
        await _db
            .collection('materials')
            .doc(materialId)
            .collection('priceHistory')
            .orderBy('timestamp', descending: true)
            .limit(1)
            .get();
    if (snap.docs.isEmpty) return null;
    final ts = snap.docs.first.data()['timestamp'];
    if (ts is Timestamp) return ts.toDate();
    return DateTime.tryParse(ts?.toString() ?? '');
  }

  Future<void> saveMaterial(MaterialModel material) async {
    await _db.collection('materials').doc(material.id).set(material.toMap());
  }

  Future<void> deleteMaterial(String id) async {
    await _db.collection('materials').doc(id).delete();
  }

  // --- Categories ---
  Future<List<CategoryModel>> getCategories() async {
    final snap = await _db.collection('categories').get();
    final categories =
        snap.docs
            .map((doc) => CategoryModel.fromDoc(doc.id, doc.data() as Map<String, dynamic>))
            .where((c) => c.id.isNotEmpty && c.name.isNotEmpty && c.isActive)
            .toList();
    categories.sort((a, b) => a.name.compareTo(b.name));
    return categories;
  }

  // --- Orders ---
  Stream<List<OrderModel>> streamOrdersByCompany(String companyId) {
    return _db
        .collection('orders')
        .where('companyId', isEqualTo: companyId)
        .snapshots()
        .map(
          (snap) =>
              snap.docs
                  .map((doc) => OrderModel.fromMap(doc.id, doc.data() as Map<String, dynamic>))
                  .toList(),
        );
  }

  Stream<List<OrderModel>> streamOrdersBySupplier(String supplierId) {
    return _db
        .collection('orders')
        .where('supplierId', isEqualTo: supplierId)
        .snapshots()
        .map(
          (snap) =>
              snap.docs
                  .map((doc) => OrderModel.fromMap(doc.id, doc.data() as Map<String, dynamic>))
                  .toList(),
        );
  }

  Future<void> saveOrder(OrderModel order) async {
    await _db.collection('orders').doc(order.orderId).set(order.toMap());
  }

  // --- Chat Messages ---
  Stream<List<ChatMessageModel>> streamChats(String uid1, String uid2) {
    return _db
        .collection('chats')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map(
          (snap) =>
              snap.docs
                  .map((doc) => ChatMessageModel.fromMap(doc.data() as Map<String, dynamic>))
                  .where(
                    (msg) =>
                        msg.content.isNotEmpty &&
                        ((msg.senderId == uid1 && msg.receiverId == uid2) ||
                            (msg.senderId == uid2 && msg.receiverId == uid1)),
                  )
                  .toList(),
        );
  }

  Stream<List<ChatThreadModel>> streamFieldUserChatThreads(
    String companyId,
    String fieldUserId,
  ) {
    return _db
        .collection('chats')
        .where('isThread', isEqualTo: true)
        .where('companyId', isEqualTo: companyId)
        .where('fieldUserId', isEqualTo: fieldUserId)
        .orderBy('lastMessageAt', descending: true)
        .snapshots()
        .map(
          (snap) =>
              snap.docs
                  .map((doc) => ChatThreadModel.fromMap(doc.id, doc.data() as Map<String, dynamic>))
                  .toList(),
        );
  }

  // REQUIRES Firestore index: chats
  // Fields: isThread ASC, supplierId ASC, lastMessageAt DESC
  // Create at Firebase Console → Firestore → Indexes
  Stream<List<ChatThreadModel>> streamSupplierChatThreads(String supplierId) {
    return _db
        .collection('chats')
        .where('isThread', isEqualTo: true)
        .where('supplierId', isEqualTo: supplierId)
        .orderBy('lastMessageAt', descending: true)
        .snapshots()
        .map(
          (snap) =>
              snap.docs
                  .map((doc) => ChatThreadModel.fromMap(doc.id, doc.data() as Map<String, dynamic>))
                  .toList(),
        );
  }

  Future<void> markChatThreadReadForSupplier(String chatId) async {
    await _db.collection('chats').doc(chatId).set({
      'unreadSupplier': 0,
    }, SetOptions(merge: true));
  }

  Stream<List<ChatMessageModel>> streamChatMessages(String chatId) {
    return _db
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map(
          (snap) =>
              snap.docs
                  .map(
                    (doc) => ChatMessageModel.fromMap({
                      ...doc.data() as Map<String, dynamic>,
                      'id': doc.id,
                      'chatId': chatId,
                    }),
                  )
                  .toList(),
        );
  }

  Future<void> ensureChatThread(ChatThreadModel thread) async {
    final ref = _db.collection('chats').doc(thread.chatId);
    final doc = await ref.get();
    if (!doc.exists) {
      await ref.set(thread.toMap());
      return;
    }
    if (thread.fieldUserName.isNotEmpty) {
      final existing = doc.data()?['fieldUserName'] as String? ?? '';
      if (existing.isEmpty) {
        await ref.set({
          'fieldUserName': thread.fieldUserName,
        }, SetOptions(merge: true));
      }
    }
  }

  Future<String> saveChatMessage(ChatMessageModel message) async {
    final chatId = message.chatId;
    if (chatId == null || chatId.isEmpty) {
      throw ArgumentError('chatId is required to save a message');
    }
    final ref =
        _db.collection('chats').doc(chatId).collection('messages').doc();
    await ref.set(message.toMap());
    return ref.id;
  }

  Future<void> markChatMessagesRead(String chatId, String currentUserId) async {
    final snap =
        await _db
            .collection('chats')
            .doc(chatId)
            .collection('messages')
            .where('isRead', isEqualTo: false)
            .get();
    if (snap.docs.isEmpty) return;

    final batch = _db.batch();
    var pending = 0;
    for (final doc in snap.docs) {
      final senderId = doc.data()['senderId'] as String? ?? '';
      if (senderId != currentUserId) {
        batch.update(doc.reference, {'isRead': true});
        pending++;
      }
    }
    if (pending > 0) {
      await batch.commit();
    }
  }

  Future<void> updateChatThreadAfterMessage({
    required String chatId,
    required String companyId,
    required String lastMessage,
    required String lastSenderId,
    required String fieldUserId,
    required String supplierId,
    String? fieldUserName,
  }) async {
    final threadRef = _db.collection('chats').doc(chatId);
    final isFromFieldUser = lastSenderId == fieldUserId;
    await threadRef.set({
      'isThread': true,
      'chatId': chatId,
      'companyId': companyId,
      'fieldUserId': fieldUserId,
      'supplierId': supplierId,
      if (fieldUserName != null && fieldUserName.isNotEmpty)
        'fieldUserName': fieldUserName,
      'lastMessage': lastMessage,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastSenderId': lastSenderId,
      if (isFromFieldUser)
        'unreadSupplier': FieldValue.increment(1)
      else
        'unreadFieldUser': FieldValue.increment(1),
    }, SetOptions(merge: true));
  }

  Future<void> markChatThreadReadForFieldUser(String chatId) async {
    await _db.collection('chats').doc(chatId).set({
      'unreadFieldUser': 0,
    }, SetOptions(merge: true));
  }

  // --- Ratings ---
  Stream<List<RatingModel>> streamSupplierRatings(String supplierId) {
    return _db
        .collection('ratings')
        .where('supplierId', isEqualTo: supplierId)
        .snapshots()
        .map(
          (snap) =>
              snap.docs
                  .map((doc) => RatingModel.fromMap(doc.id, doc.data() as Map<String, dynamic>))
                  .toList(),
        );
  }

  Future<void> saveRating(RatingModel rating) async {
    await _db.collection('ratings').doc(rating.id).set(rating.toMap());
  }

  // --- Subscriptions ---
  Future<SubscriptionModel?> getSubscription(String companyId) async {
    final doc = await _db.collection('subscriptions').doc(companyId).get();
    if (doc.exists && doc.data() != null) {
      return SubscriptionModel.fromMap(companyId, _requireDocData(doc));
    }
    return null;
  }

  Stream<SubscriptionModel?> streamSubscription(String companyId) {
    return _db.collection('subscriptions').doc(companyId).snapshots().map((
      doc,
    ) {
      if (doc.exists && doc.data() != null) {
        return SubscriptionModel.fromMap(companyId, _requireDocData(doc));
      }
      return null;
    });
  }

  Future<void> saveSubscription(SubscriptionModel sub) async {
    await _db
        .collection('subscriptions')
        .doc(sub.companyId)
        .set(sub.toMap(), SetOptions(merge: true));
  }

  Future<void> updateSubscriptionHistory(
    String companyId,
    SubscriptionHistoryEntry entry,
  ) async {
    await _db.collection('subscriptions').doc(companyId).update({
      'history': FieldValue.arrayUnion([entry.toMap()]),
    });
  }

  // --- Price Indices ---
  Stream<List<PriceHistoryModel>> streamPriceHistory() {
    return _db
        .collection('priceHistory')
        .snapshots()
        .map(
          (snap) =>
              snap.docs
                  .map((doc) => PriceHistoryModel.fromMap(doc.id, doc.data() as Map<String, dynamic>))
                  .toList(),
        );
  }

  Future<void> savePriceHistory(PriceHistoryModel price) async {
    await _db.collection('priceHistory').doc(price.histId).set(price.toMap());
  }

  // --- Invitations ---
  Future<InvitationModel?> getInvitationByCode(String code) async {
    final snap =
        await _db
            .collection('invitations')
            .where('code', isEqualTo: code)
            .limit(1)
            .get();
    if (snap.docs.isNotEmpty) {
      return InvitationModel.fromMap(
        snap.docs.first.id,
        snap.docs.first.data() as Map<String, dynamic>,
      );
    }
    return null;
  }

  Future<void> saveInvitation(InvitationModel invite) async {
    await _db.collection('invitations').doc(invite.token).set(invite.toMap());
  }

  // --- Join Requests ---
  Stream<List<JoinRequestModel>> streamJoinRequests(String companyId) {
    return _db
        .collection('joinRequests')
        .where('companyId', isEqualTo: companyId)
        .snapshots()
        .map(
          (snap) =>
              snap.docs
                  .map((doc) => JoinRequestModel.fromMap(doc.id, doc.data() as Map<String, dynamic>))
                  .toList(),
        );
  }

  Future<void> saveJoinRequest(JoinRequestModel req) async {
    await _db.collection('joinRequests').doc(req.reqId).set(req.toMap());
  }

  // --- Notifications ---
  Stream<List<NotificationModel>> streamNotifications(String userId) {
    return _db
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snap) =>
              snap.docs
                  .map((doc) => NotificationModel.fromMap(doc.id, doc.data() as Map<String, dynamic>))
                  .toList(),
        );
  }

  Future<void> saveNotification(NotificationModel notif) async {
    await _db.collection('notifications').doc(notif.notifId).set(notif.toMap());
  }

  /// Archives a price change under `materials/{materialId}/priceHistory`
  /// (same path used by the supplier panel when editing material prices).
  Future<void> archiveMaterialPriceChange({
    required String materialId,
    required double previousPrice,
    required double newPrice,
    String? supplierUid,
  }) async {
    final changePercent =
        previousPrice > 0
            ? ((newPrice - previousPrice) / previousPrice * 100)
            : 0.0;
    final payload = {
      'materialId': materialId,
      if (supplierUid != null) 'supplierUid': supplierUid,
      'price': newPrice,
      'previousPrice': previousPrice,
      'changePercent': double.parse(changePercent.toStringAsFixed(1)),
      'timestamp': FieldValue.serverTimestamp(),
      'recordedAt': FieldValue.serverTimestamp(),
    };

    await _db
        .collection('materials')
        .doc(materialId)
        .collection('priceHistory')
        .add(payload);

    if (supplierUid != null && supplierUid.isNotEmpty) {
      await _db
          .collection('suppliers')
          .doc(supplierUid)
          .collection('materials')
          .doc(materialId)
          .collection('priceHistory')
          .add({
            'price': newPrice,
            'recordedAt': FieldValue.serverTimestamp(),
            'timestamp': FieldValue.serverTimestamp(),
          });
    }
  }

  /// Initial price entry when a supplier first lists a material.
  Future<void> recordInitialMaterialPrice({
    required String materialId,
    required double price,
    String? supplierUid,
  }) async {
    final payload = {
      'materialId': materialId,
      if (supplierUid != null) 'supplierUid': supplierUid,
      'price': price,
      'timestamp': FieldValue.serverTimestamp(),
      'recordedAt': FieldValue.serverTimestamp(),
    };

    await _db
        .collection('materials')
        .doc(materialId)
        .collection('priceHistory')
        .add(payload);

    if (supplierUid != null && supplierUid.isNotEmpty) {
      await _db
          .collection('suppliers')
          .doc(supplierUid)
          .collection('materials')
          .doc(materialId)
          .collection('priceHistory')
          .add({
            'price': price,
            'recordedAt': FieldValue.serverTimestamp(),
            'timestamp': FieldValue.serverTimestamp(),
          });
    }
  }

  Future<List<PriceHistoryModel>> getMaterialPriceHistorySince(
    String materialId,
    DateTime since, {
    String? companyId,
    String? supplierUid,
  }) async {
    final entries = <PriceHistoryModel>[];
    final seen = <String>{};

    void addDoc(String id, Map<String, dynamic> data) {
      final key = '$id@${data['timestamp'] ?? data['recordedAt']}';
      if (!seen.add(key)) return;
      entries.add(
        PriceHistoryModel.fromMap(id, {
          ...data,
          'materialId': materialId,
          if (supplierUid != null &&
              (data['supplierUid'] == null || data['supplierUid'] == ''))
            'supplierUid': supplierUid,
        }),
      );
    }

    final materialSnap =
        await _db
            .collection('materials')
            .doc(materialId)
            .collection('priceHistory')
            .where(
              'timestamp',
              isGreaterThanOrEqualTo: Timestamp.fromDate(since),
            )
            .get();
    for (final doc in materialSnap.docs) {
      addDoc(doc.id, doc.data());
    }

    if (companyId != null && companyId.isNotEmpty) {
      final companySnap =
          await _db
              .collection('companies')
              .doc(companyId)
              .collection('materials')
              .doc(materialId)
              .collection('priceHistory')
              .where(
                'timestamp',
                isGreaterThanOrEqualTo: Timestamp.fromDate(since),
              )
              .get();
      for (final doc in companySnap.docs) {
        addDoc('company_${doc.id}', doc.data());
      }
    }

    if (supplierUid != null && supplierUid.isNotEmpty) {
      final supplierSnap =
          await _db
              .collection('suppliers')
              .doc(supplierUid)
              .collection('materials')
              .doc(materialId)
              .collection('priceHistory')
              .where(
                'timestamp',
                isGreaterThanOrEqualTo: Timestamp.fromDate(since),
              )
              .get();
      for (final doc in supplierSnap.docs) {
        addDoc('supplier_${doc.id}', doc.data());
      }
    }

    return entries..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  /// Price history for a single material listing + supplier, last [months], ascending.
  Future<List<PriceHistoryModel>> getMaterialPriceHistoryForSupplier({
    required String materialId,
    required String supplierUid,
    int months = 6,
    String? companyId,
  }) async {
    final since = DateTime.now().subtract(Duration(days: months * 30));
    final entries = await getMaterialPriceHistorySince(
      materialId,
      since,
      companyId: companyId,
      supplierUid: supplierUid,
    );
    return entries
        .where((e) => e.supplierUid.isEmpty || e.supplierUid == supplierUid)
        .toList();
  }

  /// Merged price history across approved suppliers for [materialName], last [months].
  Future<List<PriceHistoryModel>> getCompanyMaterialPriceTrend({
    required String companyId,
    required String materialName,
    int months = 6,
  }) async {
    final materials = await getMaterialsByNameForCompany(
      companyId,
      materialName,
    );
    if (materials.isEmpty) return [];

    final since = DateTime.now().subtract(Duration(days: months * 30));
    final all = <PriceHistoryModel>[];
    for (final material in materials) {
      all.addAll(
        await getMaterialPriceHistorySince(
          material.id,
          since,
          companyId: companyId,
          supplierUid: material.supplierId,
        ),
      );
    }
    all.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return all;
  }

  // --- Bulk Quote / RFQ ---
  Future<String> createRfqJob({
    required String uid,
    required String companyId,
    required String companyName,
    required String category,
    required String materialDescription,
    required double quantity,
    required String unit,
    required String city,
    required DateTime requiredByDate,
  }) async {
    final ref = _db.collection('rfq_jobs').doc();
    await ref.set({
      'uid': uid,
      'companyId': companyId,
      'companyName': companyName,
      'category': category,
      'materialDescription': materialDescription,
      'quantity': quantity,
      'unit': unit,
      'city': city,
      'requiredByMillis': requiredByDate.millisecondsSinceEpoch,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });

    final done = await ref.snapshots().firstWhere((snap) {
      final status = snap.data()?['status']?.toString();
      return status == 'complete' || status == 'error';
    }).timeout(
      const Duration(seconds: 60),
      onTimeout: () {
        throw AppException(
          'Publishing timed out. Please try again.',
          'deadline-exceeded',
        );
      },
    );

    final data = done.data() ?? {};
    if (data['status'] == 'error') {
      throw AppException(
        (data['error'] as String?)?.trim().isNotEmpty == true
            ? data['error'] as String
            : 'Could not publish the quote request. Please try again.',
      );
    }
    return (data['rfqId'] as String?) ?? ref.id;
  }

  /// Writes an award payload to [rfq_award_jobs] and waits for
  /// [onRfqAwardJobCreated]. Used instead of the `awardRfq` HTTPS callable,
  /// which is blocked by CORS on Flutter web.
  Future<void> createRfqAwardJob({
    required String uid,
    required String rfqId,
    required String bidId,
  }) async {
    final ref = _db.collection('rfq_award_jobs').doc();
    await ref.set({
      'uid': uid,
      'rfqId': rfqId,
      'bidId': bidId,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });

    final done = await ref.snapshots().firstWhere((snap) {
      final status = snap.data()?['status']?.toString();
      return status == 'complete' || status == 'error';
    }).timeout(
      const Duration(seconds: 60),
      onTimeout: () {
        throw AppException(
          'Awarding the contract timed out. Please try again.',
          'deadline-exceeded',
        );
      },
    );

    final data = done.data() ?? {};
    if (data['status'] == 'error') {
      throw AppException(
        (data['error'] as String?)?.trim().isNotEmpty == true
            ? data['error'] as String
            : 'Could not award this quote request. Please try again.',
      );
    }
  }

  /// Writes a cancel payload to [rfq_cancel_jobs] and waits for
  /// [onRfqCancelJobCreated].
  Future<void> createRfqCancelJob({
    required String uid,
    required String rfqId,
  }) async {
    final ref = _db.collection('rfq_cancel_jobs').doc();
    await ref.set({
      'uid': uid,
      'rfqId': rfqId,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });

    final done = await ref.snapshots().firstWhere((snap) {
      final status = snap.data()?['status']?.toString();
      return status == 'complete' || status == 'error';
    }).timeout(
      const Duration(seconds: 60),
      onTimeout: () {
        throw AppException(
          'Cancelling the quote request timed out. Please try again.',
          'deadline-exceeded',
        );
      },
    );

    final data = done.data() ?? {};
    if (data['status'] == 'error') {
      throw AppException(
        (data['error'] as String?)?.trim().isNotEmpty == true
            ? data['error'] as String
            : 'Could not cancel this quote request. Please try again.',
      );
    }
  }

  /// Writes a bid-withdraw payload to [rfq_bid_withdraw_jobs].
  Future<void> createRfqBidWithdrawJob({
    required String uid,
    required String rfqId,
  }) async {
    final ref = _db.collection('rfq_bid_withdraw_jobs').doc();
    await ref.set({
      'uid': uid,
      'rfqId': rfqId,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });

    final done = await ref.snapshots().firstWhere((snap) {
      final status = snap.data()?['status']?.toString();
      return status == 'complete' || status == 'error';
    }).timeout(
      const Duration(seconds: 60),
      onTimeout: () {
        throw AppException(
          'Withdrawing the bid timed out. Please try again.',
          'deadline-exceeded',
        );
      },
    );

    final data = done.data() ?? {};
    if (data['status'] == 'error') {
      throw AppException(
        (data['error'] as String?)?.trim().isNotEmpty == true
            ? data['error'] as String
            : 'Could not withdraw this bid. Please try again.',
      );
    }
  }

  /// Writes a report payload to [dispute_jobs] and waits for
  /// [onDisputeJobCreated]. Used instead of the `raiseDispute` HTTPS callable,
  /// which is blocked by CORS on Flutter web.
  Future<String> createDisputeJob({
    required String uid,
    required String orderId,
    required String companyId,
    required String type,
    required String description,
    String? photoUrl,
  }) async {
    final ref = _db.collection('dispute_jobs').doc();
    await ref.set({
      'uid': uid,
      'orderId': orderId,
      'companyId': companyId,
      'type': type,
      'description': description,
      'photoUrl': photoUrl,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });

    final done = await ref.snapshots().firstWhere((snap) {
      final status = snap.data()?['status']?.toString();
      return status == 'complete' || status == 'error';
    }).timeout(
      const Duration(seconds: 60),
      onTimeout: () {
        throw AppException(
          'Submitting the report timed out. Please try again.',
          'deadline-exceeded',
        );
      },
    );

    final data = done.data() ?? {};
    if (data['status'] == 'error') {
      throw AppException(
        (data['error'] as String?)?.trim().isNotEmpty == true
            ? data['error'] as String
            : 'Could not submit the report. Please try again.',
      );
    }
    return (data['disputeId'] as String?) ?? ref.id;
  }

  /// Writes an admin update payload to [dispute_update_jobs] and waits for
  /// [onDisputeUpdateJobCreated]. Used instead of the `updateDispute` HTTPS
  /// callable, which is blocked by CORS on Flutter web.
  Future<void> createDisputeUpdateJob({
    required String uid,
    required String disputeId,
    required String status,
    required String resolutionNotes,
  }) async {
    try {
      final ref = _db.collection('dispute_update_jobs').doc();
      await ref.set({
        'uid': uid,
        'disputeId': disputeId,
        'statusUpdate': status,
        'resolutionNotes': resolutionNotes,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      final done = await ref.snapshots().firstWhere((snap) {
        final jobStatus = snap.data()?['status']?.toString();
        return jobStatus == 'complete' || jobStatus == 'error';
      }).timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          throw AppException(
            'Updating the dispute timed out. Please try again.',
            'deadline-exceeded',
          );
        },
      );

      final data = done.data() ?? {};
      if (data['status'] == 'error') {
        final jobError = (data['error'] as String?)?.trim() ?? '';
        if (jobError.toLowerCase().contains('permission-denied') ||
            jobError.toLowerCase().contains('insufficient permissions')) {
          throw AppException(
            "You don't have permission to perform this action. Please contact support if this continues.",
            'permission-denied',
          );
        }
        throw AppException(
          jobError.isNotEmpty
              ? jobError
              : 'Could not update the dispute. Please try again.',
        );
      }
    } catch (error) {
      _rethrowFirestore(error);
    }
  }

  Future<void> createDisputeWithdrawJob({
    required String uid,
    required String disputeId,
  }) async {
    final ref = _db.collection('dispute_withdraw_jobs').doc();
    await ref.set({
      'uid': uid,
      'disputeId': disputeId,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });

    final done = await ref.snapshots().firstWhere((snap) {
      final jobStatus = snap.data()?['status']?.toString();
      return jobStatus == 'complete' || jobStatus == 'error';
    }).timeout(
      const Duration(seconds: 60),
      onTimeout: () {
        throw AppException(
          'Withdrawing the dispute timed out. Please try again.',
          'deadline-exceeded',
        );
      },
    );

    final data = done.data() ?? {};
    if (data['status'] == 'error') {
      throw AppException(
        (data['error'] as String?)?.trim().isNotEmpty == true
            ? data['error'] as String
            : 'Could not withdraw this dispute. Please try again.',
      );
    }
  }

  /// Writes a prompt to [ai_jobs] and waits for [onAiJobCreated] to fill it.
  /// Used instead of the `generateAiText` HTTPS callable, which 403s on Flutter web.
  Future<String> generateAiText({
    required String uid,
    required String prompt,
  }) async {
    final trimmed = prompt.trim();
    if (trimmed.isEmpty) {
      throw AppException('Missing prompt.', 'invalid-argument');
    }
    if (trimmed.length > 12000) {
      throw AppException('Prompt is too long.', 'invalid-argument');
    }

    final ref = _db.collection('ai_jobs').doc();
    debugPrint('AI job ${ref.id}: creating (prompt ${trimmed.length} chars)');
    await ref.set({
      'uid': uid,
      'prompt': trimmed,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });

    final done = await ref.snapshots().firstWhere((snap) {
      final status = snap.data()?['status']?.toString();
      return status == 'complete' || status == 'error';
    }).timeout(
      const Duration(seconds: 60),
      onTimeout: () {
        debugPrint('AI job ${ref.id}: timed out still pending');
        throw AppException(
          'The assistant timed out. Please try again.',
          'deadline-exceeded',
        );
      },
    );

    final data = done.data() ?? {};
    final status = data['status']?.toString();
    if (status == 'error') {
      final reason = (data['error'] as String?)?.trim();
      debugPrint('AI job ${ref.id}: error ${reason ?? '(no details)'}');
      throw AppException(
        (reason != null && reason.isNotEmpty)
            ? reason
            : 'The assistant could not complete that request.',
      );
    }

    final text = (data['text'] as String?)?.trim() ?? '';
    debugPrint('AI job ${ref.id}: complete (${text.length} chars)');
    if (text.isEmpty) {
      throw AppException('The assistant returned an empty response.');
    }
    return text;
  }

  Stream<List<RfqModel>> streamCompanyRfqs(String companyId) {
    return _db
        .collection('rfqs')
        .where('companyId', isEqualTo: companyId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snap) =>
              snap.docs
                  .map((doc) => RfqModel.fromMap(doc.id, doc.data() as Map<String, dynamic>))
                  .toList(),
        );
  }

  Stream<List<RfqModel>> streamOpenRfqsForSupplier(
    String city,
    List<String> categories,
  ) {
    if (categories.isEmpty) return Stream.value([]);
    return _db
        .collection('rfqs')
        .where('status', isEqualTo: 'open')
        .where('city', isEqualTo: city)
        .where('category', whereIn: categories)
        .snapshots()
        .map(
          (snap) =>
              snap.docs
                  .map((doc) => RfqModel.fromMap(doc.id, doc.data() as Map<String, dynamic>))
                  .toList(),
        );
  }

  Future<List<RfqBidModel>> getRfqBids(String rfqId) async {
    final snap =
        await _db.collection('rfqs').doc(rfqId).collection('bids').get();
    final bids = snap.docs
        .map((doc) => RfqBidModel.fromMap(doc.id, doc.data()))
        .where((b) => !b.isWithdrawn)
        .toList();
    bids.sort((a, b) => a.bidPrice.compareTo(b.bidPrice));
    return bids;
  }

  Stream<List<RfqBidModel>> streamRfqBids(String rfqId) {
    return _db.collection('rfqs').doc(rfqId).collection('bids').snapshots().map(
      (snap) {
        final bids =
            snap.docs
                .map((doc) => RfqBidModel.fromMap(doc.id, doc.data() as Map<String, dynamic>))
                .where((b) => !b.isWithdrawn)
                .toList();
        bids.sort((a, b) => a.bidPrice.compareTo(b.bidPrice));
        return bids;
      },
    );
  }

  Stream<RfqModel?> streamRfq(String rfqId) {
    return _db.collection('rfqs').doc(rfqId).snapshots().map((doc) {
      final data = doc.data();
      return doc.exists && data != null ? RfqModel.fromMap(doc.id, data as Map<String, dynamic>) : null;
    });
  }

  Stream<double> streamSupplierRating(String supplierId) {
    return _db.collection('suppliers').doc(supplierId).snapshots().map((doc) {
      final data = doc.data();
      final value = data?['globalAvgRating'] ?? data?['rating'];
      return value is num ? value.toDouble() : 0.0;
    });
  }

  // --- Dispute System ---
  Stream<List<DisputeModel>> streamAllDisputes({String? status}) {
    return _db
        .collection('disputes')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) {
          final disputes =
              snap.docs
                  .map(
                    (doc) => DisputeModel.fromMap(
                      doc.id,
                      doc.data() as Map<String, dynamic>,
                    ),
                  )
                  .toList();
          if (status == null || status == 'all') return disputes;
          return disputes.where((dispute) => dispute.status == status).toList();
        });
  }

  Stream<List<DisputeModel>> streamCompanyDisputes(String companyId) {
    if (companyId.trim().isEmpty) return Stream.value(const []);
    return _db
        .collection('disputes')
        .where('companyId', isEqualTo: companyId)
        .snapshots()
        .map((snap) {
          final disputes =
              snap.docs
                  .map(
                    (doc) => DisputeModel.fromMap(
                      doc.id,
                      doc.data() as Map<String, dynamic>,
                    ),
                  )
                  .where((dispute) => dispute.companyId == companyId)
                  .toList();
          disputes.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return disputes;
        });
  }

  Stream<List<DisputeModel>> streamRaisedByDisputes(String uid) {
    if (uid.trim().isEmpty) return Stream.value(const []);
    return _db
        .collection('disputes')
        .where('raisedByUid', isEqualTo: uid)
        .snapshots()
        .map((snap) {
          final disputes =
              snap.docs
                  .map(
                    (doc) => DisputeModel.fromMap(
                      doc.id,
                      doc.data() as Map<String, dynamic>,
                    ),
                  )
                  .where((dispute) => dispute.raisedByUid == uid)
                  .toList();
          disputes.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return disputes;
        });
  }

  Stream<DisputeModel?> streamDispute(String disputeId) {
    final id = disputeId.trim();
    if (id.isEmpty) return Stream.value(null);
    return _db.collection('disputes').doc(id).snapshots().map((doc) {
      final data = doc.data();
      if (!doc.exists || data == null) return null;
      return DisputeModel.fromMap(doc.id, data);
    });
  }

  Future<bool> isSupplierLinkedToCompany(
    String companyId,
    String supplierId,
  ) async {
    final doc =
        await _db
            .collection('companies')
            .doc(companyId)
            .collection('suppliers')
            .doc(supplierId)
            .get();
    if (!doc.exists) return false;
    final status = (doc.data()?['status'] as String?)?.toLowerCase() ?? '';
    return status == 'active' || status == 'approved';
  }

  Future<int> getSupplierDisputeCount(
    String supplierId, {
    String? companyId,
  }) async {
    Query query = _db
        .collection('disputes')
        .where('supplierId', isEqualTo: supplierId);
    if (companyId != null) {
      query = query.where('companyId', isEqualTo: companyId);
    }
    final snap = await query.get();
    return snap.docs.length;
  }

  Future<Map<String, dynamic>> getSupplierStats(
    String supplierId, {
    String? companyId,
  }) async {
    Query query = _db
        .collection('orders')
        .where('supplierId', isEqualTo: supplierId);
    if (companyId != null) {
      query = query.where('companyId', isEqualTo: companyId);
    }

    final snap = await query.get();
    final orders =
        snap.docs
            .map(
              (doc) => OrderModel.fromMap(
                doc.id,
                doc.data() as Map<String, dynamic>,
              ),
            )
            .toList();

    final deliveredOrders =
        orders
            .where((o) => o.status == 'delivered' || o.status == 'confirmed')
            .toList();
    final totalFulfilled = deliveredOrders.length;

    int onTime = 0;
    for (var o in deliveredOrders) {
      if (o.deliveredAt != null && o.requiredDate != null) {
        if (o.deliveredAt!.isBefore(o.requiredDate!) ||
            o.deliveredAt!.isAtSameMomentAs(o.requiredDate!)) {
          onTime++;
        }
      } else if (o.status == 'confirmed' || o.status == 'delivered') {
        // Fallback: if no deliveredAt, we can't be sure, but let's count as on-time if it's confirmed
        // or just skip. Usually deliveredAt should be set.
      }
    }

    double onTimeRate =
        totalFulfilled == 0 ? 0 : (onTime / totalFulfilled) * 100;

    return {'totalFulfilled': totalFulfilled, 'onTimeRate': onTimeRate};
  }

  // --- Audit Logs ---
  Future<void> saveAuditLog(AuditLogModel log) async {
    await _db.collection('audit_logs').add(log.toMap());
  }

  Stream<List<AuditLogModel>> streamAuditLogs({String? actionType}) {
    return _db
        .collection('audit_logs')
        .orderBy('timestamp', descending: true)
        .limit(300)
        .snapshots()
        .map((snap) {
          final logs =
              snap.docs
                  .map(
                    (doc) => AuditLogModel.fromMap(
                      doc.id,
                      doc.data() as Map<String, dynamic>,
                    ),
                  )
                  .toList()
                ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

          if (actionType == null || actionType == 'all') return logs;
          final matches = AuditLogModel.matchingActionTypes(actionType);
          return logs.where((log) => matches.contains(log.actionType)).toList();
        });
  }

  /// Soft-delete: Hide RFQ for current user
  Future<void> hideRfqForUser(String rfqId, String userId) async {
    await _db.collection('rfqs').doc(rfqId).update({
      'hiddenBy': FieldValue.arrayUnion([userId]),
    });
  }

  /// Bulk soft-delete RFQs
  Future<void> hideRfqsForUser(List<String> rfqIds, String userId) async {
    final batch = _db.batch();
    for (final id in rfqIds) {
      batch.update(_db.collection('rfqs').doc(id), {
        'hiddenBy': FieldValue.arrayUnion([userId]),
      });
    }
    await batch.commit();
  }
}
