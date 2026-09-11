// MVVM: ViewModel — business logic only
import 'dart:async';
import 'package:flutter/material.dart';
import '../models/order_model.dart';
import '../models/rating_model.dart';
import '../repositories/order_repository.dart';
import '../repositories/transaction_repository.dart';
import '../services/cloud_function_service.dart';
import '../constants/app_constants.dart';
import 'auth_viewmodel.dart';

class OrderViewModel extends ChangeNotifier {
  final OrderRepository _orderRepo;
  final TransactionRepository _transactionRepo;
  final CloudFunctionService _cloudFunctions;

  List<OrderModel> _orders = [];
  bool _isLoading = false;
  bool _isOrderPlaced = false;
  bool _isRatingSubmitted = false;
  String? _error;
  double _calculatedTotal = 0.0;
  bool? _hasExistingRating;
  StreamSubscription? _ordersSubscription;

  OrderViewModel(this._orderRepo, this._transactionRepo, this._cloudFunctions);

  void updateAuth(AuthViewModel auth) {
    notifyListeners();
  }

  List<OrderModel> get orders => _orders;
  bool get isLoading => _isLoading;
  bool get isOrderPlaced => _isOrderPlaced;
  bool get isRatingSubmitted => _isRatingSubmitted;
  String? get error => _error;
  double get calculatedTotal => _calculatedTotal;
  bool? get hasExistingRating => _hasExistingRating;

  void updateQuantity(int qty, double unitPrice) {
    _calculatedTotal = qty * unitPrice;
    notifyListeners();
  }

  Future<void> placeOrder(OrderModel order) async {
    _isLoading = true;
    _error = null;
    _isOrderPlaced = false;
    notifyListeners();
    try {
      await _orderRepo.submitOrder(order);
      _isOrderPlaced = true;
    } catch(e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> confirmDelivery(String orderId, String companyId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final order = await _orderRepo.getOrderById(orderId);
      if (order == null) throw Exception("Order not found");

      // 1. Update Order Status to Confirmed
      await _orderRepo.updateStatus(orderId, companyId, 'confirmed', confirmedAt: DateTime.now());

      // 2. Generate Commission Record (2%)
      // This uses a deterministic ID internally to prevent duplicates
      final commissionAmount = order.totalAmount * AppConstants.commissionRate;
      final supplierEarning = order.totalAmount - commissionAmount;

      await _transactionRepo.createUnsettledCommissionTransaction(
        orderId: orderId,
        companyId: companyId,
        supplierUid: order.supplierId,
        totalAmount: order.totalAmount,
        commissionAmount: commissionAmount,
        supplierEarning: supplierEarning,
      );
      
    } catch(e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> acceptOrder(String orderId, String companyId) async {
    await _updateOrderStatus(orderId, companyId, 'accepted');
  }

  Future<void> rejectOrder(String orderId, String companyId, String reason) async {
    await _updateOrderStatus(orderId, companyId, 'rejected', reason: reason);
  }

  Future<void> markDelivered(String orderId, String companyId) async {
    await _updateOrderStatus(orderId, companyId, 'delivered', deliveredAt: DateTime.now());
  }

  Future<void> cancelOrder(String orderId, String companyId) async {
    await _updateOrderStatus(orderId, companyId, 'cancelled');
  }

  Future<void> _updateOrderStatus(
    String orderId,
    String companyId,
    String status, {
    String? reason,
    DateTime? deliveredAt,
    DateTime? confirmedAt,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      await _orderRepo.updateStatus(orderId, companyId, status, 
        reason: reason, deliveredAt: deliveredAt, confirmedAt: confirmedAt);
    } catch(e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void loadCompanyOrders(String companyId, {String? statusFilter}) {
    _ordersSubscription?.cancel();
    _isLoading = true;
    notifyListeners();
    _ordersSubscription = _orderRepo
      .watchCompanyOrders(companyId, statusFilter ?? 'All')
      .listen((orders) {
        _orders = orders;
        _isLoading = false;
        notifyListeners();
      }, onError: (e) {
        _error = e.toString();
        _isLoading = false;
        notifyListeners();
      });
  }

  void loadSupplierOrders(String supplierUid, String companyId, {String? statusFilter}) {
    _ordersSubscription?.cancel();
    _isLoading = true;
    notifyListeners();
    _ordersSubscription = _orderRepo
      .watchSupplierOrders(supplierUid, companyId, statusFilter ?? 'All')
      .listen((orders) {
        _orders = orders;
        _isLoading = false;
        notifyListeners();
      }, onError: (e) {
        _error = e.toString();
        _isLoading = false;
        notifyListeners();
      });
  }

  void loadFieldUserOrders(String fieldUserUid, String companyId, {String? statusFilter}) {
    _ordersSubscription?.cancel();
    _isLoading = true;
    notifyListeners();
    _ordersSubscription = _orderRepo
      .watchFieldUserOrders(fieldUserUid, companyId, statusFilter ?? 'All')
      .listen((orders) {
        _orders = orders;
        _isLoading = false;
        notifyListeners();
      }, onError: (e) {
        _error = e.toString();
        _isLoading = false;
        notifyListeners();
      });
  }

  Future<void> submitRating(String orderId, String companyId, RatingModel rating) async {
    _isLoading = true;
    _isRatingSubmitted = false;
    _error = null;
    notifyListeners();
    try {
      await _orderRepo.submitRating(orderId, companyId, rating);
      await _orderRepo.updateSupplierAvgRating(rating.supplierUid);
      _isRatingSubmitted = true;
    } catch(e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Hides a single order from the current user's view (soft delete).
  Future<void> hideOrder(String orderId, String userId) async {
    try {
      await _orderRepo.hideOrderForUser(orderId, userId);
      _orders.removeWhere((o) => o.orderId == orderId);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Hides multiple orders from the current user's view.
  Future<void> hideOrders(List<String> orderIds, String userId) async {
    try {
      await _orderRepo.hideOrdersForUser(orderIds, userId);
      _orders.removeWhere((o) => orderIds.contains(o.orderId));
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  @override
  void dispose() {
    _ordersSubscription?.cancel();
    super.dispose();
  }
}
