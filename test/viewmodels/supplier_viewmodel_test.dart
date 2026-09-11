import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ratebridge/constants/app_constants.dart';
import 'package:ratebridge/constants/firestore_paths.dart';
import 'package:ratebridge/models/company_model.dart';
import 'package:ratebridge/models/material_model.dart';
import 'package:ratebridge/models/order_model.dart';
import 'package:ratebridge/models/partnership_request_model.dart';
import 'package:ratebridge/models/rating_model.dart';
import 'package:ratebridge/models/transaction_model.dart';
import 'package:ratebridge/models/user_model.dart';
import 'package:ratebridge/utils/app_exception.dart';
import 'package:ratebridge/viewmodels/auth_viewmodel.dart';
import 'package:ratebridge/viewmodels/supplier_viewmodel.dart';

import '../mocks/mocks.dart';

class MockAuthViewModel extends Mock implements AuthViewModel {}

class MockXFile extends Mock implements XFile {}

UserModel _user({
  String uid = 'sup-1',
  String status = 'active',
  String? rejectionReason,
}) {
  return UserModel(
    uid: uid,
    email: 'steel@co.test',
    name: 'Steel Co',
    role: 'Supplier',
    companyId: '',
    phone: '03001234567',
    city: 'Lahore',
    status: status,
    rejectionReason: rejectionReason,
    createdAt: DateTime.utc(2026, 1, 1),
  );
}

CompanyModel _company({
  String id = 'co-1',
  String name = 'Acme Builders',
  String city = 'Lahore',
  String status = 'active',
  String? companyType = 'Contractor',
}) {
  return CompanyModel(
    id: id,
    name: name,
    registrationNumber: 'REG-1',
    address: 'Site 1',
    city: city,
    status: status,
    createdAt: DateTime.utc(2026, 1, 1),
    companyType: companyType,
  );
}

OrderModel _order({
  String orderId = 'order-1',
  String companyId = 'co-1',
  String status = 'pending',
  DateTime? createdAt,
}) {
  final created = createdAt ?? DateTime.utc(2026, 4, 1);
  return OrderModel(
    orderId: orderId,
    companyId: companyId,
    fieldUserUid: 'field-1',
    supplierId: 'sup-1',
    materialId: 'mat-1',
    materialName: 'OPC Cement',
    supplierName: 'Steel Co',
    fieldUserName: 'Ali Raza',
    quantity: 10,
    unit: 'bag',
    unitPrice: 100,
    totalAmount: 1000,
    deliveryAddress: 'Lahore',
    status: status,
    createdAt: created,
    updatedAt: created,
  );
}

MaterialModel _material({String id = 'mat-1', double price = 1250}) {
  return MaterialModel(
    id: id,
    name: 'OPC Cement',
    category: 'Cement',
    pricePerUnit: price,
    unit: 'bag',
    specifications: '53',
    qualityGrade: 'OPC 53',
    supplierId: 'sup-1',
    supplierName: 'Steel Co',
    isCertified: true,
    originCity: 'Lahore',
    createdAt: DateTime.utc(2026, 3, 1),
  );
}

PartnershipRequestModel _request({
  String requestId = 'req-1',
  String companyId = 'co-1',
  String status = 'pending',
  String initiatedBy = 'ceo',
  DateTime? createdAt,
  DateTime? respondedAt,
  String? rejectionReason,
}) {
  return PartnershipRequestModel(
    requestId: requestId,
    companyId: companyId,
    companyName: 'Acme Builders',
    supplierId: 'sup-1',
    supplierName: 'Steel Co',
    initiatedBy: initiatedBy,
    status: status,
    rejectionReason: rejectionReason,
    createdAt: createdAt ?? DateTime.utc(2026, 4, 1),
    respondedAt: respondedAt,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final user = _user();
  final company = _company();
  final order = _order();
  final material = _material();

  setUpAll(() {
    registerFallbackValue(user);
    registerFallbackValue(material);
    registerFallbackValue(order);
    registerFallbackValue(<String, dynamic>{});
    registerFallbackValue(<String>[]);
    registerFallbackValue(0.0);
    registerFallbackValue('');
    registerFallbackValue(DateTime.utc(2026, 1, 1));
  });

  late FakeFirebaseFirestore fake;
  late MockMaterialRepository materialRepo;
  late MockOrderRepository orderRepo;
  late MockTransactionRepository transactionRepo;
  late MockStorageService storageService;
  late MockPriceHistoryRepository priceHistoryRepo;
  late MockCloudFunctionService cloudFunctions;
  late MockUserRepository userRepo;
  late MockCompanyRepository companyRepo;
  late MockPartnershipRequestRepository partnershipRepo;
  late MockNotificationService notificationService;
  late MockAuthViewModel auth;
  late SupplierViewModel viewModel;
  late StreamSubscription<QuerySnapshot<Map<String, dynamic>>> bidJobsSub;
  String? uploadResult;
  bool failRfqBidJobs = false;

  void stubDefaults() {
    when(() => userRepo.watchUserDoc(any())).thenAnswer(
      (_) => Stream<UserModel>.value(user),
    );
    when(() => userRepo.getUserDoc(any())).thenAnswer((_) async => user);
    when(() => userRepo.updateUserDoc(any(), any())).thenAnswer((_) async {});
    when(() => userRepo.cachedUser).thenReturn(user);
    when(() => companyRepo.getCompanyById(any())).thenAnswer((_) async => company);
    when(() => companyRepo.getAllCompanies()).thenAnswer((_) async => [company]);
    when(() => orderRepo.getOrdersForSupplier(any(), userId: any(named: 'userId'))).thenAnswer(
      (_) => Stream.value([order]),
    );
    when(() => orderRepo.updateStatus(any(), any(), any())).thenAnswer((_) async {});
    when(
      () => orderRepo.updateStatus(
        any(),
        any(),
        any(),
        reason: any(named: 'reason'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => orderRepo.updateStatus(
        any(),
        any(),
        any(),
        deliveredAt: any(named: 'deliveredAt'),
      ),
    ).thenAnswer((_) async {});
    when(() => transactionRepo.getMonthlyEarningsSummary(any(), any()))
        .thenAnswer((_) async => const []);
    when(
      () => transactionRepo.createUnsettledCommissionTransaction(
        orderId: any(named: 'orderId'),
        companyId: any(named: 'companyId'),
        supplierUid: any(named: 'supplierUid'),
        totalAmount: any(named: 'totalAmount'),
        commissionAmount: any(named: 'commissionAmount'),
        supplierEarning: any(named: 'supplierEarning'),
      ),
    ).thenAnswer((_) async {});
    when(() => materialRepo.getMaterialById(any())).thenAnswer((_) async => material);
    when(() => materialRepo.removeMaterial(any())).thenAnswer((_) async {});
    when(
      () => materialRepo.recordInitialMaterialPrice(
        materialId: any(named: 'materialId'),
        price: any(named: 'price'),
        supplierUid: any(named: 'supplierUid'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => materialRepo.archiveMaterialPriceChange(
        materialId: any(named: 'materialId'),
        previousPrice: any(named: 'previousPrice'),
        newPrice: any(named: 'newPrice'),
        supplierUid: any(named: 'supplierUid'),
      ),
    ).thenAnswer((_) async {});
    when(() => cloudFunctions.callFunction(any(), any()))
        .thenAnswer((_) async => null);
    when(
      () => notificationService.notifyOrderAccepted(
        fieldUserUid: any(named: 'fieldUserUid'),
        orderId: any(named: 'orderId'),
        companyId: any(named: 'companyId'),
        materialName: any(named: 'materialName'),
        supplierName: any(named: 'supplierName'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => notificationService.notifyOrderRejected(
        fieldUserUid: any(named: 'fieldUserUid'),
        orderId: any(named: 'orderId'),
        companyId: any(named: 'companyId'),
        materialName: any(named: 'materialName'),
        supplierName: any(named: 'supplierName'),
        reason: any(named: 'reason'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => notificationService.notifyOrderDelivered(
        fieldUserUid: any(named: 'fieldUserUid'),
        orderId: any(named: 'orderId'),
        companyId: any(named: 'companyId'),
        materialName: any(named: 'materialName'),
        supplierName: any(named: 'supplierName'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => partnershipRepo.createRequest(
        companyId: any(named: 'companyId'),
        companyName: any(named: 'companyName'),
        supplierId: any(named: 'supplierId'),
        supplierName: any(named: 'supplierName'),
        initiatedBy: any(named: 'initiatedBy'),
        message: any(named: 'message'),
        supplierEmail: any(named: 'supplierEmail'),
        supplierCity: any(named: 'supplierCity'),
        supplierCategories: any(named: 'supplierCategories'),
        supplierRating: any(named: 'supplierRating'),
      ),
    ).thenAnswer((_) async => 'req-1');
    when(() => partnershipRepo.acceptRequest(any())).thenAnswer((_) async {});
    when(() => partnershipRepo.rejectRequest(any(), any())).thenAnswer((_) async {});
    when(() => partnershipRepo.withdrawRequest(any())).thenAnswer((_) async {});
    when(
      () => partnershipRepo.removePartnership(
        companyId: any(named: 'companyId'),
        supplierId: any(named: 'supplierId'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => storageService.uploadFile(
        path: any(named: 'path'),
        file: any(named: 'file'),
      ),
    ).thenAnswer((_) async => 'https://cdn/appeal.jpg');
  }

  SupplierViewModel createVm() {
    return SupplierViewModel(
      materialRepo,
      orderRepo,
      transactionRepo,
      storageService,
      priceHistoryRepo,
      cloudFunctions,
      userRepo,
      companyRepo,
      partnershipRepo,
      notificationService,
      firestore: fake,
      uploadImageBytes: ({
        required List<int> bytes,
        required String folder,
        String filename = 'upload.jpg',
      }) async =>
          uploadResult,
    );
  }

  Future<void> signIn() async {
    when(() => auth.user).thenReturn(user);
    viewModel.updateAuth(auth);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
  }

  setUp(() {
    fake = FakeFirebaseFirestore();
    materialRepo = MockMaterialRepository();
    orderRepo = MockOrderRepository();
    transactionRepo = MockTransactionRepository();
    storageService = MockStorageService();
    priceHistoryRepo = MockPriceHistoryRepository();
    cloudFunctions = MockCloudFunctionService();
    userRepo = MockUserRepository();
    companyRepo = MockCompanyRepository();
    partnershipRepo = MockPartnershipRequestRepository();
    notificationService = MockNotificationService();
    auth = MockAuthViewModel();
    uploadResult = 'https://cdn.example/proof.jpg';
    failRfqBidJobs = false;
    stubDefaults();
    bidJobsSub = fake.collection('rfq_bid_jobs').snapshots().listen((snap) {
      for (final doc in snap.docs) {
        if (doc.data()['status'] != 'pending') continue;
        if (failRfqBidJobs) {
          doc.reference.update({
            'status': 'error',
            'error': 'bid failed',
          });
        } else {
          doc.reference.update({'status': 'complete'});
        }
      }
    });
    viewModel = createVm();
  });

  tearDown(() async {
    await bidJobsSub.cancel();
    viewModel.dispose();
  });

  group('SupplierViewModel helpers', () {
    test('monthKey formats YYYY-MM', () {
      expect(
        SupplierViewModel.monthKey(DateTime.utc(2026, 9, 2)),
        '2026-09',
      );
    });

    test('materialById returns null for empty or unknown ids', () {
      expect(viewModel.materialById(''), isNull);
      expect(viewModel.materialById('mat-1'), isNull);
    });

    test('fetchMaterialById returns null for empty id without hitting repo', () async {
      expect(await viewModel.fetchMaterialById(''), isNull);
      verifyNever(() => materialRepo.getMaterialById(any()));
    });

    test('fetchMaterialById delegates to the repository', () async {
      expect(await viewModel.fetchMaterialById('mat-1'), same(material));
      verify(() => materialRepo.getMaterialById('mat-1')).called(1);
    });

    test('interestCategoriesFor uses companyType', () {
      expect(viewModel.interestCategoriesFor(company), ['Contractor']);
    });

    test('pastRequestStatusLabel maps removed and rejected states', () {
      expect(
        viewModel.pastRequestStatusLabel(_request(status: 'removed')),
        'Removed',
      );
      expect(
        viewModel.pastRequestStatusLabel(
          _request(status: 'rejected', initiatedBy: 'supplier'),
        ),
        'Declined by Them',
      );
      expect(
        viewModel.pastRequestStatusLabel(
          _request(status: 'rejected', initiatedBy: 'ceo'),
        ),
        'You Declined',
      );
    });

    test('companyNameFor is null until linked companies load', () {
      expect(viewModel.companyNameFor('co-1'), isNull);
    });
  });

  group('SupplierViewModel.updateAuth', () {
    test('loads the supplier session and profile', () async {
      await signIn();

      expect(viewModel.supplierUid, 'sup-1');
      expect(viewModel.profile?.name, 'Steel Co');
      expect(viewModel.status, 'active');
      verify(() => userRepo.watchUserDoc('sup-1')).called(1);
    });

    test('same uid updates profile without restarting session', () async {
      await signIn();
      clearInteractions(userRepo);
      when(() => auth.user).thenReturn(_user(status: 'pending'));

      viewModel.updateAuth(auth);

      expect(viewModel.status, 'pending');
      verifyNever(() => userRepo.watchUserDoc(any()));
    });

    test('null user clears supplier state', () async {
      await signIn();
      when(() => auth.user).thenReturn(null);

      viewModel.updateAuth(auth);

      expect(viewModel.supplierUid, isNull);
      expect(viewModel.companies, isEmpty);
      expect(viewModel.selectedCompanyId, isNull);
    });
  });

  group('SupplierViewModel notifications', () {
    test('saveNotificationPreferences fails when signed out', () async {
      expect(
        await viewModel.saveNotificationPreferences({'pushEnabled': false}),
        'Not signed in',
      );
    });

    test('saveNotificationPreferences success writes the user doc', () async {
      await signIn();
      final prefs = {'pushEnabled': false, 'newOrders': true};

      var savingOnFirst = false;
      var notifies = 0;
      viewModel.addListener(() {
        notifies++;
        if (notifies == 1) savingOnFirst = viewModel.notificationPrefsSaving;
      });

      expect(await viewModel.saveNotificationPreferences(prefs), isNull);
      expect(savingOnFirst, isTrue);
      expect(viewModel.notificationPrefsSaving, isFalse);
      expect(viewModel.notificationPrefs['pushEnabled'], isFalse);
      verify(
        () => userRepo.updateUserDoc('sup-1', {'notificationPreferences': prefs}),
      ).called(1);
    });

    test('saveNotificationPreferences failure returns the error', () async {
      await signIn();
      when(() => userRepo.updateUserDoc(any(), any())).thenThrow(
        Exception('prefs write failed'),
      );

      expect(
        await viewModel.saveNotificationPreferences({'pushEnabled': true}),
        'Exception: prefs write failed',
      );
      expect(viewModel.notificationPrefsSaving, isFalse);
    });

    test('loadNotificationPreferences reads stored flags', () async {
      await fake.collection('users').doc('sup-1').set({
        'notificationPreferences': {'pushEnabled': false, 'newOrders': true},
      });
      await signIn();
      await viewModel.loadNotificationPreferences();

      expect(viewModel.notificationPrefsLoaded, isTrue);
      expect(viewModel.notificationPrefs['pushEnabled'], isFalse);
      expect(viewModel.notificationPrefs['newOrders'], isTrue);
    });
  });

  group('SupplierViewModel profile', () {
    test('loadProfile success stores the user', () async {
      await signIn();
      await viewModel.loadProfile();
      expect(viewModel.profile?.email, 'steel@co.test');
      verify(() => userRepo.getUserDoc('sup-1')).called(1);
    });

    test('updateProfile writes fields and refreshes from cache', () async {
      await signIn();
      await viewModel.updateProfile({'city': 'Karachi'});
      verify(() => userRepo.updateUserDoc('sup-1', {'city': 'Karachi'})).called(1);
    });
  });

  group('SupplierViewModel invitations', () {
    test('acceptInvitation success selects the company', () async {
      await signIn();
      await viewModel.acceptInvitation('invite-1', 'co-1');

      expect(viewModel.isLoading, isFalse);
      expect(viewModel.selectedCompanyId, 'co-1');
      expect(viewModel.error, isNull);
      verify(
        () => cloudFunctions.callFunction('onInviteAccepted', {
          'token': 'invite-1',
          'companyId': 'co-1',
          'supplierUid': 'sup-1',
        }),
      ).called(1);
    });

    test('acceptInvitation failure sets error', () async {
      await signIn();
      when(() => cloudFunctions.callFunction(any(), any())).thenThrow(
        Exception('invite failed'),
      );

      await viewModel.acceptInvitation('invite-1', 'co-1');

      expect(viewModel.error, 'Exception: invite failed');
      expect(viewModel.isLoading, isFalse);
    });

    test('rejectInvitation updates the invitation document', () async {
      await fake.collection('invitations').doc('invite-1').set({
        'status': 'pending',
        'supplierUid': 'sup-1',
        'companyId': 'co-1',
      });
      await signIn();
      await viewModel.rejectInvitation('invite-1');

      final snap = await fake.collection('invitations').doc('invite-1').get();
      expect(snap.data()?['status'], 'rejected');
    });
  });

  group('SupplierViewModel materials', () {
    test('addMaterial writes both root and company materials', () async {
      await signIn();
      await viewModel.addMaterial(material, null, 'co-1');

      final rootSnap = await fake.collection('materials').doc('mat-1').get();
      final compSnap = await fake.collection('companies').doc('co-1').collection('materials').doc('mat-1').get();

      expect(rootSnap.exists, isTrue);
      expect(compSnap.exists, isTrue);
      verify(() => materialRepo.recordInitialMaterialPrice(materialId: 'mat-1', price: 1250.0, supplierUid: 'sup-1')).called(1);
    });

    test('deleteMaterial performs full deletion if no active orders', () async {
      await signIn();
      await fake.collection('materials').doc('mat-1').set(material.toMap());
      await fake.collection('companies').doc('co-1').collection('materials').doc('mat-1').set(material.toMap());

      await viewModel.deleteMaterial('mat-1', 'co-1');

      final rootSnap = await fake.collection('materials').doc('mat-1').get();
      final compSnap = await fake.collection('companies').doc('co-1').collection('materials').doc('mat-1').get();

      expect(rootSnap.exists, isFalse);
      expect(compSnap.exists, isFalse);
      expect(viewModel.successMessage, 'Material deleted successfully.');
    });

    test('deleteMaterial throws if material has active orders', () async {
      await signIn();
      await fake.collection('orders').doc('order-1').set(_order(status: 'pending').toMap());

      expect(
        () => viewModel.deleteMaterial('mat-1', 'co-1'),
        throwsA(isA<AppException>().having((e) => e.message, 'message', contains('used on 1 active order'))),
      );
    });
  });

  group('SupplierViewModel orders', () {
    test('acceptOrder updates status and notifies', () async {
      await signIn();
      await viewModel.loadOrders('co-1', null);
      await viewModel.acceptOrder('order-1', 'co-1');

      verify(() => orderRepo.updateStatus('order-1', 'co-1', 'accepted')).called(1);
      verify(() => notificationService.notifyOrderAccepted(
        fieldUserUid: 'field-1',
        orderId: 'order-1',
        companyId: 'co-1',
        materialName: 'OPC Cement',
        supplierName: 'Steel Co',
      )).called(1);
    });

    test('markDelivered updates status with timestamp', () async {
      await signIn();
      await viewModel.loadOrders('co-1', null);
      await viewModel.markDelivered('order-1', 'co-1');

      verify(() => orderRepo.updateStatus(
        'order-1',
        'co-1',
        'delivered',
        deliveredAt: any(named: 'deliveredAt'),
      )).called(1);
    });
  });

  group('SupplierViewModel partnership requests', () {
    test('sendPartnershipRequest creates request and notifies', () async {
      await signIn();
      final result = await viewModel.sendPartnershipRequest('co-1', message: 'Hello');

      expect(result, isTrue);
      verify(() => partnershipRepo.createRequest(
        companyId: 'co-1',
        companyName: 'Acme Builders',
        supplierId: 'sup-1',
        supplierName: 'Steel Co',
        initiatedBy: 'supplier',
        message: 'Hello',
        supplierEmail: 'steel@co.test',
        supplierCity: 'Lahore',
        supplierCategories: const [],
        supplierRating: 0.0,
      )).called(1);
    });
  });

  group('SupplierViewModel commission payments', () {
    test('submitCommissionPayment uploads file and creates proof doc', () async {
      await signIn();
      final mockFile = MockXFile();
      when(() => mockFile.readAsBytes()).thenAnswer((_) async => Uint8List(0));

      final success = await viewModel.submitCommissionPayment(
        amount: 50,
        method: 'Bank Transfer',
        screenshotFile: mockFile,
      );

      expect(success, isTrue);
      final proofs = await fake.collection('payment_proofs').get();
      expect(proofs.docs.length, 1);
      expect(proofs.docs.first.data()['amount'], 50);
      expect(proofs.docs.first.data()['screenshotUrl'], 'https://cdn.example/proof.jpg');
    });

    test('submitCommissionPayment fails for invalid amounts', () async {
      await signIn();
      final mockFile = MockXFile();
      final success = await viewModel.submitCommissionPayment(
        amount: -10,
        method: 'JazzCash',
        screenshotFile: mockFile,
      );
      expect(success, isFalse);
      expect(viewModel.error, 'Invalid amount');
    });
  });

  group('SupplierViewModel RFQ bidding', () {
    test('submitRfqBid creates job and waits for completion', () async {
      await signIn();
      await viewModel.submitRfqBid(
        rfqId: 'rfq-abc',
        bidPrice: 1200,
        deliveryTime: '2 days',
      );

      final jobs = await fake.collection('rfq_bid_jobs').get();
      expect(jobs.docs.length, 1);
      expect(jobs.docs.first.data()['status'], 'complete');
      expect(viewModel.successMessage, 'Bid submitted.');
    });

    test('submitRfqBid handles job error', () async {
      await signIn();
      failRfqBidJobs = true;
      
      await viewModel.submitRfqBid(
        rfqId: 'rfq-abc',
        bidPrice: 1200,
        deliveryTime: '2 days',
      );

      expect(viewModel.error, 'bid failed');
    });
  });
}
