import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../constants/app_constants.dart';
import '../../constants/route_names.dart';
import '../../models/material_listing.dart';
import '../../models/material_model.dart';
import '../../models/order_model.dart';
import '../../models/supplier_model.dart';
import '../../repositories/company_repository.dart';
import '../../repositories/order_repository.dart';
import '../../repositories/transaction_repository.dart';
import '../../repositories/material_repository.dart';
import '../../services/notification_service.dart';
import '../../services/plan_limit_service.dart';
import '../../utils/app_exception.dart';
import '../../views/field_user/orders/field_order_status.dart';

/// Order placement, listing, detail, and weight reporting for field users.
class FieldOrdersViewModel extends ChangeNotifier {
  final OrderRepository _orderRepo;
  final TransactionRepository _transactionRepo;
  final CompanyRepository _companyRepo;
  final MaterialRepository _materialRepo;
  final NotificationService _notificationService;
  final Future<void> Function(String companyId) _ensureActiveOrderCapacity;
  final void Function({
    required String path,
    required Map<String, String> queryParameters,
    required MaterialListing extra,
  })? _navigateToPlaceOrder;
  final void Function(String message)? _showReorderError;

  bool _isSubmitting = false;
  bool _isLoadingOrders = false;
  String? _errorMessage;
  List<OrderModel> _orders = [];
  StreamSubscription<List<OrderModel>>? _ordersSubscription;

  FieldOrdersViewModel(
    this._orderRepo,
    this._transactionRepo,
    this._companyRepo,
    this._materialRepo,
    this._notificationService, {
    Future<void> Function(String companyId)? ensureActiveOrderCapacity,
    FirebaseFirestore? firestore,
    void Function({
      required String path,
      required Map<String, String> queryParameters,
      required MaterialListing extra,
    })? navigateToPlaceOrder,
    void Function(String message)? showReorderError,
  })  : _ensureActiveOrderCapacity = ensureActiveOrderCapacity ??
            ((companyId) => PlanLimitService.ensureActiveOrderCapacity(
                  firestore ?? FirebaseFirestore.instance,
                  companyId,
                )),
        _navigateToPlaceOrder = navigateToPlaceOrder,
        _showReorderError = showReorderError;

  bool get isSubmitting => _isSubmitting;
  bool get isLoadingOrders => _isLoadingOrders;
  String? get errorMessage => _errorMessage;
  List<OrderModel> get orders => _orders;
  List<OrderModel> get recentOrders => _orders.take(5).toList();

  int get pendingCount =>
      _orders.where((o) => FieldOrderStatus.isPending(o.status)).length;

  int get activeCount =>
      _orders.where((o) => FieldOrderStatus.isActive(o.status)).length;

  int get deliveredCount =>
      _orders.where((o) {
        final s = FieldOrderStatus.normalize(o.status);
        return s == 'delivered' || s == 'confirmed';
      }).length;

  int get historyCount =>
      _orders.where((o) => FieldOrderStatus.isHistory(o.status)).length;

  List<OrderModel> get activeOrders =>
      _orders
          .where((o) => FieldOrderStatus.isActive(o.status))
          .take(3)
          .toList();

  int? _requestedOrdersSubTab;

  bool get hasPendingOrdersSubTab => _requestedOrdersSubTab != null;

  /// 0 = pending, 1 = active, 2 = delivered, 3 = history. Consumed by [FieldOrdersView].
  void requestOrdersSubTab(int index) {
    _requestedOrdersSubTab = index.clamp(0, 3);
    notifyListeners();
  }

  int? consumeRequestedOrdersSubTab() {
    final value = _requestedOrdersSubTab;
    _requestedOrdersSubTab = null;
    return value;
  }

  List<OrderModel> ordersForTab(FieldOrderTab tab) {
    switch (tab) {
      case FieldOrderTab.pending:
        return _orders
            .where((o) => FieldOrderStatus.isPending(o.status))
            .toList();
      case FieldOrderTab.active:
        return _orders
            .where((o) => FieldOrderStatus.isActive(o.status))
            .toList();
      case FieldOrderTab.history:
        return _orders
            .where((o) => FieldOrderStatus.isHistory(o.status))
            .toList();
    }
  }

  void watchOrders(String fieldUserUid, String companyId) {
    _ordersSubscription?.cancel();
    _errorMessage = null;
    _isLoadingOrders = true;
    notifyListeners();
    _ordersSubscription = _orderRepo
        .watchFieldUserOrders(fieldUserUid, companyId, 'All', userId: fieldUserUid)
        .listen(
          (data) {
            _orders = data;
            _isLoadingOrders = false;
            notifyListeners();
          },
          onError: (e) {
            _errorMessage = e is AppException ? e.message : e.toString();
            _isLoadingOrders = false;
            notifyListeners();
          },
        );
  }

  OrderModel? findOrder(String orderId) {
    try {
      return _orders.firstWhere((o) => o.orderId == orderId);
    } catch (_) {
      return null;
    }
  }

  Future<OrderModel?> fetchOrder(String orderId) async {
    final cached = findOrder(orderId);
    if (cached != null) return cached;
    return fetchOrderFromServer(orderId);
  }

  Future<OrderModel?> fetchOrderFromServer(String orderId) async {
    try {
      return await _orderRepo.getOrderById(orderId);
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<SupplierModel?> fetchSupplier(String supplierId) async {
    try {
      return await _orderRepo.getSupplierById(supplierId);
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<bool> hasRatingForOrder(String orderId, String companyId) async {
    try {
      return await _orderRepo.hasRatingForOrder(orderId, companyId);
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> hasUserRatedOrder(String orderId, String userId) async {
    try {
      return await _orderRepo.hasRatingForOrderByUser(orderId, userId);
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> placeOrderFromListing({
    required String companyId,
    required String fieldUserUid,
    required String fieldUserName,
    String? fieldUserPhone,
    required MaterialListing material,
    required double quantity,
    required String deliveryAddress,
    required DateTime requiredDate,
    String? notes,
  }) async {
    return placeOrder(
      companyId: companyId,
      fieldUserUid: fieldUserUid,
      fieldUserName: fieldUserName,
      fieldUserPhone: fieldUserPhone,
      material: _materialFromListing(material),
      quantity: quantity,
      siteLocation: deliveryAddress,
      requiredDate: requiredDate,
      notes: notes,
    );
  }

  Future<bool> placeOrder({
    required String companyId,
    required String fieldUserUid,
    required String fieldUserName,
    String? fieldUserPhone,
    required MaterialModel material,
    required double quantity,
    required String siteLocation,
    required DateTime requiredDate,
    String? notes,
  }) async {
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final totalAmount = quantity * material.pricePerUnit;
      final commissionAmount = totalAmount * AppConstants.commissionRate;
      final supplierEarning = totalAmount - commissionAmount;

      // 1. Check auto-approval threshold
      final company = await _companyRepo.getCompanyById(companyId);
      final threshold = company?.autoApprovalThreshold ?? 0.0;

      // Count every non-terminal order across the whole company, not only
      // accepted orders belonging to the current field user.
      await _ensureActiveOrderCapacity(companyId);

      final isAutoApproved = threshold > 0 && totalAmount <= threshold;

      final initialStatus =
          isAutoApproved
              ? AppConstants.statusPending
              : AppConstants.statusPendingApproval;

      final order = OrderModel(
        orderId: DateTime.now().millisecondsSinceEpoch.toString(),
        companyId: companyId,
        fieldUserUid: fieldUserUid,
        supplierId: material.supplierId,
        materialId: material.id,
        materialName: material.name,
        supplierName: material.supplierName,
        fieldUserName: fieldUserName,
        fieldUserPhone: fieldUserPhone,
        quantity: quantity,
        unit: material.unit,
        unitPrice: material.pricePerUnit,
        totalAmount: totalAmount,
        commissionAmount: commissionAmount,
        supplierEarning: supplierEarning,
        deliveryAddress: siteLocation,
        siteLocation: siteLocation,
        status: initialStatus,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        requiredDate: requiredDate,
        notes: notes,
      );
      await _orderRepo.submitOrder(order);

      final ceoUid = await _orderRepo.resolveCeoUid(companyId);

      if (isAutoApproved) {
        // Notify supplier
        await _notificationService.notifyNewOrder(
          supplierId: order.supplierId,
          orderId: order.orderId,
          companyId: order.companyId,
          materialName: order.materialName,
          fieldUserName: order.fieldUserName,
        );
        // Notify CEO (Informational)
        if (ceoUid != null) {
          await _notificationService.notifyOrderAutoApproved(
            ceoUid: ceoUid,
            orderId: order.orderId,
            companyId: companyId,
            materialName: order.materialName,
            totalAmount: totalAmount,
          );
        }
      } else {
        if (ceoUid != null) {
          await _notificationService.notifyOrderPendingApproval(
            ceoUid: ceoUid,
            orderId: order.orderId,
            companyId: companyId,
            materialName: order.materialName,
            fieldUserName: order.fieldUserName,
          );
        } else {
          // Fallback if no CEO found (should not happen in proper team setup)
          await _orderRepo.updateStatus(
            order.orderId,
            companyId,
            AppConstants.statusPending,
          );
          await _notificationService.notifyNewOrder(
            supplierId: order.supplierId,
            orderId: order.orderId,
            companyId: order.companyId,
            materialName: order.materialName,
            fieldUserName: order.fieldUserName,
          );
        }
      }
      return true;
    } catch (e) {
      _errorMessage = e is AppException ? e.message : e.toString();
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  Future<bool> confirmDelivery({
    required String orderId,
    required String companyId,
  }) async {
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final order =
          findOrder(orderId) ?? await _orderRepo.getOrderById(orderId);
      if (order == null) {
        throw AppException('Order not found');
      }

      if (!FieldOrderStatus.canConfirmDelivery(order.status)) {
        throw AppException(
          'This order must be marked as delivered before you can confirm receipt.',
        );
      }

      final totalAmount = order.totalAmount;
      final commissionAmount = totalAmount * AppConstants.commissionRate;
      final supplierEarning = totalAmount - commissionAmount;

      await _orderRepo.updateStatus(
        orderId,
        companyId,
        AppConstants.statusConfirmed,
      );
      await _orderRepo.updateOrder(orderId, {
        'commissionAmount': commissionAmount,
        'supplierEarning': supplierEarning,
        'confirmedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Persist the unsettled commission row here. The Cloud Function is
      // idempotent (doc id comm_{orderId}) and must not be skipped just
      // because this client also wrote commissionAmount on the order.
      await _transactionRepo.createUnsettledCommissionTransaction(
        orderId: orderId,
        companyId: companyId,
        supplierUid: order.supplierId,
        totalAmount: totalAmount,
        commissionAmount: commissionAmount,
        supplierEarning: supplierEarning,
      );

      await _notificationService.notifyDeliveryConfirmed(
        supplierId: order.supplierId,
        orderId: orderId,
        companyId: companyId,
        materialName: order.materialName,
        fieldUserName: order.fieldUserName,
      );

      return true;
    } catch (e) {
      _errorMessage = e is AppException ? e.message : e.toString();
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  Future<bool> submitWeightReport({
    required String orderId,
    required String companyId,
    required double actualWeight,
    String? remarks,
  }) async {
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _orderRepo.submitWeightReport(
        orderId,
        actualWeight,
        remarks: remarks,
      );
      return true;
    } catch (e) {
      _errorMessage = e is AppException ? e.message : e.toString();
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  Future<bool> cancelOrder(String orderId, String companyId) async {
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final order =
          findOrder(orderId) ?? await _orderRepo.getOrderById(orderId);
      await _orderRepo.cancelOrder(orderId, companyId);
      if (order != null) {
        await _notificationService.notifyOrderCancelled(
          supplierId: order.supplierId,
          orderId: orderId,
          companyId: companyId,
          materialName: order.materialName,
          fieldUserName: order.fieldUserName,
        );
      }
      return true;
    } catch (e) {
      _errorMessage = e is AppException ? e.message : e.toString();
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  /// Bulk soft-delete orders for a user.
  Future<void> hideOrders(List<String> orderIds, String userId) async {
    try {
      await _orderRepo.hideOrdersForUser(orderIds, userId);
      // Local filter update happens via stream if watchOrders includes userId.
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> reorder(BuildContext context, OrderModel pastOrder) async {
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // 1. Fetch material to ensure it exists
      final material = await _materialRepo.getMaterialById(
        pastOrder.materialId,
      );
      if (material == null) {
        throw AppException(
          'This material is no longer available from the supplier.',
        );
      }

      // 2. Fetch supplier to ensure they are still active and linked
      final supplier = await _orderRepo.getSupplierById(pastOrder.supplierId);
      if (supplier == null || supplier.status.toLowerCase() != 'active') {
        throw AppException('The supplier is no longer active on the platform.');
      }

      // Check if still linked to company
      final isLinked = await _companyRepo.isSupplierLinked(
        pastOrder.companyId,
        pastOrder.supplierId,
      );
      if (!isLinked) {
        throw AppException(
          'This supplier is no longer linked to your company.',
        );
      }

      // 3. Convert to MaterialListing
      final listing = _listingFromMaterial(material, supplier);

      // 4. Navigate to place order screen
      if (_navigateToPlaceOrder != null) {
        _navigateToPlaceOrder!(
          path: RouteNames.fieldPlaceOrder,
          queryParameters: {
            'address': pastOrder.deliveryAddress,
            'quantity': pastOrder.quantity.toString(),
          },
          extra: listing,
        );
      } else if (context.mounted) {
        final uri = Uri(
          path: RouteNames.fieldPlaceOrder,
          queryParameters: {
            'address': pastOrder.deliveryAddress,
            'quantity': pastOrder.quantity.toString(),
          },
        );
        GoRouter.of(context).push(uri.toString(), extra: listing);
      }
    } catch (e) {
      _errorMessage = e is AppException ? e.message : e.toString();
      if (_showReorderError != null) {
        _showReorderError!(_errorMessage!);
      } else if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_errorMessage!), backgroundColor: Colors.red),
        );
      }
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  MaterialListing _listingFromMaterial(MaterialModel m, SupplierModel s) {
    return MaterialListing(
      id: m.id,
      materialName: m.name,
      supplierName: m.supplierName,
      supplierId: m.supplierId,
      pricePerUnit: m.pricePerUnit,
      unit: m.unit,
      category: m.category,
      city: m.originCity,
      supplierRating: s.rating,
      brand: m.brand,
      qualityGrade: m.qualityGrade,
      description: m.description,
      minOrderQuantity: m.minOrderQuantity,
      deliveryTime: m.deliveryTime,
      deliveryCoverageArea: m.deliveryCoverageArea,
      deliveryCharges: m.deliveryCharges,
      bulkDiscountAvailable: m.bulkDiscountAvailable,
      bulkDiscountDetails: m.bulkDiscountDetails,
    );
  }

  MaterialModel _materialFromListing(MaterialListing listing) {
    return MaterialModel(
      id: listing.id,
      name: listing.materialName,
      category: listing.category,
      pricePerUnit: listing.pricePerUnit,
      unit: listing.unit,
      specifications: '',
      qualityGrade: listing.qualityGrade ?? '',
      supplierId: listing.supplierId,
      supplierName: listing.supplierName,
      isCertified: false,
      originCity: listing.city ?? '',
      brand: listing.brand,
      minOrderQuantity: listing.minOrderQuantity,
      deliveryTime: listing.deliveryTime,
      description: listing.description,
      bulkDiscountAvailable: listing.bulkDiscountAvailable,
      bulkDiscountDetails: listing.bulkDiscountDetails,
      deliveryCoverageArea: listing.deliveryCoverageArea,
      deliveryCharges: listing.deliveryCharges,
    );
  }

  @override
  void dispose() {
    _ordersSubscription?.cancel();
    super.dispose();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
