// All named routes for go_router
class RouteNames {
  RouteNames._();

  // Auth
  static const String splash = '/';
  static const String roleSelection = '/role-selection';
  static const String login = '/login';
  static const String registerCEO = '/register/ceo';
  static const String registerSupplier = '/register/supplier';
  static const String registerFieldUser = '/register/field-user';
  static const String forgotPassword = '/forgot-password';
  static const String inviteLanding = '/invite/:token';

  // Account Status
  static const String pendingApproval = '/account/pending';
  static const String suspended = '/account/suspended';
  static const String rejected = '/account/rejected';

  // Admin
  static const String adminDashboard = '/admin/dashboard';
  static const String adminCompanies = '/admin/companies';
  static const String adminCategories = '/admin/categories';
  static const String adminPayments = '/admin/payments';
  static const String adminSubscription = '/admin/subscriptions';
  static const String adminDisputes = '/admin/disputes';
  static const String adminAuditLogs = '/admin/audit-logs';
  static const String adminNotifications = '/admin/notifications';
  static const String adminAppeals = '/admin/appeals';

  // CEO
  static const String ceoDashboard = '/ceo/dashboard';
  static const String ceoPending = '/ceo/pending';
  static const String ceoAppeal = '/ceo/appeal';
  static const String ceoMarketplace = '/ceo/marketplace';
  static const String ceoJoinRequests = '/ceo/join-requests';
  static const String ceoInvite = '/ceo/invite';
  static const String ceoMySuppliers = '/ceo/suppliers';
  static const String ceoFieldUsers = '/ceo/field-users';
  static const String ceoOrders = '/ceo/orders';
  static const String ceoSubscription = '/ceo/subscription';
  static const String ceoProfile = '/ceo/profile';
  static const String ceoRfqs = '/ceo/rfqs';
  static const String ceoCreateRfq = '/ceo/rfqs/create';
  static const String ceoRfqDetail = '/ceo/rfqs/:rfqId';
  static const String ceoDisputes = '/ceo/disputes';
  static const String ceoDisputeDetail = '/ceo/disputes/:disputeId';
  static const String ceoNotifications = '/ceo/notifications';

  // Supplier
  static const String supplierDashboard = '/supplier/dashboard';
  static const String supplierPending = '/supplier/pending';
  static const String supplierAppeal = '/supplier/appeal';
  static const String supplierMaterials = '/supplier/materials';
  static const String supplierMaterialDetail = '/supplier/materials/:matId';
  static const String supplierAddMaterial = '/supplier/add-material';
  static const String supplierEditMaterial = '/supplier/edit-material/:matId';
  static const String supplierOrders = '/supplier/orders';
  static const String supplierRfqs = '/supplier/rfqs';
  static const String supplierSubmitBid = '/supplier/rfqs/:rfqId/bid';
  static const String supplierChat = '/supplier/chat';
  static const String supplierChatThread = '/supplier/chat/:orderId';
  static const String supplierRatings = '/supplier/ratings';
  static const String supplierEarnings = '/supplier/earnings';
  static const String supplierPartnershipRequests =
      '/supplier/partnership-requests';
  static const String supplierCompanyDirectory = '/supplier/companies';
  static const String supplierMyCompanies = '/supplier/my-companies';
  static const String supplierProfile = '/supplier/profile';
  static const String supplierMyDisputes = '/supplier/disputes';
  static const String supplierNotifications = '/supplier/notifications';

  // Field User
  static const String fieldHome = '/field/home';
  static const String fieldCategory = '/field/category/:categoryName';
  static const String fieldSearch = '/field/search';
  static const String fieldCompare = '/field/compare/:materialId';
  static const String fieldCompareRates = '/field/compare-rates';
  static const String fieldMarketplace = '/field/marketplace';
  static const String fieldCategories = '/field/categories';
  static const String fieldRecentlyViewed = '/field/recently-viewed';
  static const String fieldTrend = '/field/trend/:matId/:supplierUid';
  static const String fieldPriceTrends = '/field/price-trends/:materialName';
  static const String fieldSupplierProfile = '/field/supplier/:supplierUid';
  static const String fieldPlaceOrder = '/field/place-order';
  static const String fieldOrders = '/field/orders';
  static const String fieldOrderDetail = '/field/order/:orderId';
  static const String fieldWeightReport = '/field/weight-report/:orderId';
  static const String fieldChat = '/field/chat';
  static const String fieldChatThread = '/field/chat/:orderId';
  static const String fieldRateSupplier = '/field/rate/:orderId';
  static const String fieldNotifications = '/field/notifications';
  static const String fieldProfile = '/field/profile';
  static const String fieldMyDisputes = '/field/disputes';
  static const String fieldDisputeDetail = '/field/disputes/:disputeId';
  static const String fieldRfqs = '/field/rfqs';
  static const String fieldCreateRfq = '/field/rfqs/create';
  static const String fieldRfqDetail = '/field/rfqs/:rfqId';

  static String encodeParam(String value) => Uri.encodeComponent(value);

  /// GoRouter already decodes path params. Decoding again throws on names
  /// like "Cement 10%" ("Illegal percent encoding in URI").
  static String decodeParam(String value) {
    if (value.isEmpty || !value.contains('%')) return value;
    try {
      return Uri.decodeComponent(value);
    } on ArgumentError {
      return value;
    }
  }

  static String pathParam(String? raw, [Object? extra]) {
    if (extra is String && extra.trim().isNotEmpty) return extra;
    return decodeParam(raw ?? '');
  }

  static String fieldCompareOf(String materialName) =>
      fieldCompare.replaceFirst(':materialId', encodeParam(materialName));
}
