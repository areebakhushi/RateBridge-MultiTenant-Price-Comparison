import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

// Constants & Models
import 'constants/route_names.dart';
import 'theme/ratebridge_theme.dart';
import 'models/material_model.dart';
import 'models/chat_thread_model.dart';

// ViewModels
import 'viewmodels/auth_viewmodel.dart';

// Localization
import 'l10n/app_localizations.dart';

// Auth Views
import 'views/auth/splash_view.dart';
import 'views/auth/role_selection_view.dart';
import 'views/auth/login_view.dart';
import 'views/auth/register_ceo_view.dart';
import 'views/auth/register_supplier_view.dart';
import 'views/auth/register_field_user_view.dart';
import 'views/auth/forgot_password_view.dart';
import 'views/auth/invite_landing_view.dart';
import 'views/auth/status_screens.dart';

// CEO Views
import 'theme/ceo_theme.dart';
import 'views/ceo/ceo_dashboard_view.dart';
import 'views/ceo/ceo_pending_view.dart';
import 'views/ceo/ceo_appeal_view.dart';
import 'views/ceo/ceo_invite_hub_view.dart';
import 'views/ceo/ceo_supplier_marketplace_view.dart';
import 'views/ceo/ceo_join_requests_view.dart';
import 'views/ceo/ceo_my_suppliers_view.dart';
import 'views/ceo/ceo_field_users_view.dart';
import 'views/ceo/ceo_orders_view.dart';
import 'views/ceo/ceo_subscription_view.dart';
import 'views/ceo/ceo_company_profile_view.dart';
import 'views/ceo/rfq/ceo_rfq_list_view.dart';
import 'views/ceo/rfq/create_rfq_view.dart';
import 'views/ceo/rfq/rfq_detail_view.dart';
import 'views/ceo/ceo_dispute_list_view.dart';
import 'views/ceo/ceo_notifications_view.dart';

// Field User Views
import 'views/field_user/shell/field_shell_view.dart';
import 'views/field_user/marketplace/field_marketplace_view.dart';
import 'views/field_user/marketplace/field_search_view.dart';
import 'views/field_user/field_categories_view.dart';
import 'views/field_user/field_recently_viewed_view.dart';
import 'views/field_user/compare/field_compare_view.dart';
import 'views/field_user/orders/field_place_order_view.dart';
import 'views/field_user/orders/field_orders_view.dart';
import 'views/field_user/orders/field_order_detail_view.dart';
import 'views/field_user/orders/field_weight_report_view.dart';
import 'views/field_user/orders/field_rate_supplier_view.dart';
import 'views/field_user/orders/field_my_disputes_view.dart';
import 'views/shared/dispute_record_detail_view.dart';
import 'views/field_user/chat/field_chat_list_view.dart';
import 'views/field_user/chat/field_chat_thread_view.dart';
import 'views/field_user/chat/field_chat_thread_args.dart';
import 'views/field_user/notifications/field_notifications_view.dart';
import 'views/field_user/profile/field_profile_view.dart';
import 'views/field_user/suppliers/field_supplier_profile_view.dart';
import 'views/field_user/trends/field_price_trends_view.dart';
import 'views/field_user/field_page_transition.dart';
import 'models/material_listing.dart';
import 'models/order_model.dart';

// Supplier Views
import 'views/supplier/supplier_dashboard_view.dart';
import 'views/supplier/supplier_pending_view.dart';
import 'views/supplier/supplier_appeal_view.dart';
import 'views/supplier/supplier_materials_view.dart';
import 'views/supplier/supplier_material_detail_view.dart';
import 'views/supplier/supplier_add_material_view.dart';
import 'views/supplier/supplier_edit_material_view.dart';
import 'views/supplier/supplier_orders_view.dart';
import 'views/supplier/supplier_my_disputes_view.dart';
import 'views/supplier/supplier_chat_view.dart';
import 'views/supplier/supplier_chat_thread_view.dart';
import 'views/supplier/supplier_ratings_view.dart';
import 'views/supplier/supplier_earnings_view.dart';
import 'views/supplier/supplier_profile_view.dart';
import 'views/supplier/partnerships/supplier_partnerships_hub_view.dart';
import 'views/supplier/supplier_company_directory_view.dart';
import 'views/supplier/supplier_notifications_view.dart';
import 'views/supplier/rfq/supplier_rfq_list_view.dart';
import 'views/supplier/rfq/submit_bid_view.dart';
import 'theme/supplier_theme.dart';
import 'theme/field_theme.dart';

// Admin Views
import 'views/admin/admin_dashboard_view.dart';
import 'views/admin/admin_notifications_view.dart';
import 'views/admin/admin_ceo_management_view.dart';
import 'views/admin/admin_categories_view.dart';
import 'views/admin/admin_payment_queue_view.dart';
import 'views/admin/admin_subscription_view.dart';
import 'views/admin/admin_dispute_list_view.dart';
import 'views/admin/admin_audit_log_view.dart';
import 'views/admin/admin_appeals_view.dart';

class RateBridgeApp extends StatefulWidget {
  const RateBridgeApp({super.key});

  @override
  State<RateBridgeApp> createState() => _RateBridgeAppState();
}

class _RateBridgeAppState extends State<RateBridgeApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();

    // Imperative push/pop keep their own stack. Reflecting them into the
    // browser URL makes GoRouter rebuild from that URL as a single page, so
    // Back can no longer return to the previous screen.
    GoRouter.optionURLReflectsImperativeAPIs = false;

    _router = GoRouter(
      initialLocation: RouteNames.splash,
      refreshListenable: Provider.of<AuthViewModel>(context, listen: false),
      routes: [
        GoRoute(
          path: RouteNames.splash,
          builder: (context, state) => const SplashView(),
        ),
        GoRoute(
          path: RouteNames.roleSelection,
          builder: (context, state) => const RoleSelectionView(),
        ),
        GoRoute(
          path: RouteNames.login,
          builder: (context, state) => const LoginView(),
        ),
        GoRoute(
          path: RouteNames.registerCEO,
          builder: (context, state) => const RegisterCeoView(),
        ),
        GoRoute(
          path: RouteNames.registerSupplier,
          builder: (context, state) => const RegisterSupplierView(),
        ),
        GoRoute(
          path: RouteNames.registerFieldUser,
          builder: (context, state) => const RegisterFieldUserView(),
        ),
        GoRoute(
          path: RouteNames.forgotPassword,
          builder: (context, state) => const ForgotPasswordView(),
        ),
        GoRoute(
          path: RouteNames.inviteLanding,
          builder:
              (context, state) => InviteLandingView(
                companyId: state.uri.queryParameters['companyId'] ?? '',
                code: state.pathParameters['token'] ?? '',
              ),
        ),

        GoRoute(
          path: RouteNames.pendingApproval,
          builder: (context, state) => const PendingApprovalView(),
        ),
        GoRoute(
          path: RouteNames.suspended,
          builder: (context, state) => const SuspendedView(),
        ),
        GoRoute(
          path: RouteNames.rejected,
          builder: (context, state) => const RejectedView(),
        ),

        GoRoute(
          path: RouteNames.ceoDashboard,
          builder: (context, state) => CeoTheme.wrap(const CeoDashboardView()),
        ),
        GoRoute(
          path: RouteNames.ceoPending,
          builder: (context, state) => CeoTheme.wrap(const CeoPendingView()),
        ),
        GoRoute(
          path: RouteNames.ceoAppeal,
          builder: (context, state) => CeoTheme.wrap(const CeoAppealView()),
        ),
        GoRoute(
          path: RouteNames.ceoInvite,
          builder: (context, state) => CeoTheme.wrap(const CeoInviteHubView()),
        ),
        GoRoute(
          path: RouteNames.ceoMarketplace,
          builder:
              (context, state) =>
                  CeoTheme.wrap(const CeoSupplierMarketplaceView()),
        ),
        GoRoute(
          path: RouteNames.ceoJoinRequests,
          builder:
              (context, state) => CeoTheme.wrap(const CeoJoinRequestsView()),
        ),
        GoRoute(
          path: RouteNames.ceoMySuppliers,
          builder:
              (context, state) => CeoTheme.wrap(const CeoMySuppliersView()),
        ),
        GoRoute(
          path: RouteNames.ceoFieldUsers,
          builder: (context, state) => CeoTheme.wrap(const CeoFieldUsersView()),
        ),
        GoRoute(
          path: RouteNames.ceoOrders,
          builder: (context, state) {
            final tab =
                int.tryParse(state.uri.queryParameters['tab'] ?? '0') ?? 0;
            return CeoTheme.wrap(CeoOrdersView(initialTab: tab));
          },
        ),
        GoRoute(
          path: RouteNames.ceoSubscription,
          builder:
              (context, state) => CeoTheme.wrap(const CeoSubscriptionView()),
        ),
        GoRoute(
          path: RouteNames.ceoProfile,
          builder:
              (context, state) => CeoTheme.wrap(const CeoCompanyProfileView()),
        ),
        GoRoute(
          path: RouteNames.ceoRfqs,
          builder: (context, state) => CeoTheme.wrap(const CeoRfqListView()),
        ),
        GoRoute(
          path: RouteNames.ceoCreateRfq,
          builder: (context, state) => CeoTheme.wrap(const CreateRfqView()),
        ),
        GoRoute(
          path: RouteNames.ceoRfqDetail,
          builder:
              (context, state) => CeoTheme.wrap(
                RfqDetailView(rfqId: state.pathParameters['rfqId'] ?? ''),
              ),
        ),
        GoRoute(
          path: RouteNames.ceoDisputes,
          builder:
              (context, state) => CeoTheme.wrap(const CeoDisputeListView()),
        ),
        GoRoute(
          path: RouteNames.ceoDisputeDetail,
          builder: (context, state) => CeoTheme.wrap(
            DisputeRecordDetailView(
              disputeId: state.pathParameters['disputeId'] ?? '',
              audience: DisputeDetailAudience.ceo,
            ),
          ),
        ),
        GoRoute(
          path: RouteNames.ceoNotifications,
          builder:
              (context, state) => CeoTheme.wrap(const CeoNotificationsView()),
        ),

        GoRoute(
          path: RouteNames.fieldHome,
          builder: (context, state) {
            final tab =
                int.tryParse(state.uri.queryParameters['tab'] ?? '') ?? 0;
            return FieldTheme.wrap(
              FieldShellView(initialTabIndex: tab.clamp(0, 4)),
            );
          },
        ),
        GoRoute(
          path: RouteNames.fieldRfqs,
          builder:
              (context, state) =>
                  FieldTheme.wrap(const CeoRfqListView(fieldUser: true)),
        ),
        GoRoute(
          path: RouteNames.fieldCreateRfq,
          builder:
              (context, state) =>
                  FieldTheme.wrap(const CreateRfqView(fieldUser: true)),
        ),
        GoRoute(
          path: RouteNames.fieldRfqDetail,
          builder:
              (context, state) => FieldTheme.wrap(
                RfqDetailView(rfqId: state.pathParameters['rfqId'] ?? ''),
              ),
        ),
        GoRoute(
          path: RouteNames.fieldMarketplace,
          pageBuilder:
              (context, state) => fieldTransitionPage(
                key: state.pageKey,
                child: FieldMarketplaceView(
                  initialCategory: state.uri.queryParameters['category'],
                ),
              ),
        ),
        GoRoute(
          path: RouteNames.fieldCategory,
          pageBuilder: (context, state) {
            final categoryName = RouteNames.pathParam(
              state.pathParameters['categoryName'],
            );
            return fieldTransitionPage(
              key: state.pageKey,
              child: FieldMarketplaceView(initialCategory: categoryName),
            );
          },
        ),
        GoRoute(
          path: RouteNames.fieldSearch,
          pageBuilder:
              (context, state) => fieldTransitionPage(
                key: state.pageKey,
                child: const FieldSearchView(),
              ),
        ),
        GoRoute(
          path: RouteNames.fieldCategories,
          pageBuilder:
              (context, state) => fieldTransitionPage(
                key: state.pageKey,
                child: const FieldCategoriesView(),
              ),
        ),
        GoRoute(
          path: RouteNames.fieldRecentlyViewed,
          pageBuilder:
              (context, state) => fieldTransitionPage(
                key: state.pageKey,
                child: const FieldRecentlyViewedView(),
              ),
        ),
        GoRoute(
          path: RouteNames.fieldCompare,
          pageBuilder: (context, state) {
            final materialName = RouteNames.pathParam(
              state.pathParameters['materialId'],
              state.extra,
            );
            return fieldTransitionPage(
              key: state.pageKey,
              child: FieldCompareView(materialName: materialName),
            );
          },
        ),
        GoRoute(
          path: RouteNames.fieldTrend,
          pageBuilder: (context, state) {
            final materialId = RouteNames.pathParam(
              state.pathParameters['matId'],
            );
            final supplierUid = RouteNames.pathParam(
              state.pathParameters['supplierUid'],
            );
            return fieldTransitionPage(
              key: state.pageKey,
              child: FieldPriceTrendsView(
                materialId: materialId,
                supplierUid: supplierUid,
              ),
            );
          },
        ),
        GoRoute(
          path: RouteNames.fieldPriceTrends,
          pageBuilder: (context, state) {
            final materialName = RouteNames.pathParam(
              state.pathParameters['materialName'],
              state.extra,
            );
            return fieldTransitionPage(
              key: state.pageKey,
              child: FieldPriceTrendsView(
                materialId: materialName,
                supplierUid: '_',
              ),
            );
          },
        ),
        GoRoute(
          path: RouteNames.fieldPlaceOrder,
          pageBuilder: (context, state) {
            final listing = state.extra as MaterialListing;
            final address = state.uri.queryParameters['address'];
            final quantity = double.tryParse(
              state.uri.queryParameters['quantity'] ?? '',
            );
            return fieldTransitionPage(
              key: state.pageKey,
              child: FieldPlaceOrderView(
                material: listing,
                initialAddress: address,
                initialQuantity: quantity,
              ),
            );
          },
        ),
        GoRoute(
          path: RouteNames.fieldOrders,
          pageBuilder:
              (context, state) => fieldTransitionPage(
                key: state.pageKey,
                child: const FieldOrdersView(),
              ),
        ),
        GoRoute(
          path: RouteNames.fieldOrderDetail,
          pageBuilder: (context, state) {
            final orderId = state.pathParameters['orderId'];
            final order =
                state.extra is OrderModel ? state.extra as OrderModel : null;
            return fieldTransitionPage(
              key: state.pageKey,
              child: FieldOrderDetailView(order: order, orderId: orderId),
            );
          },
        ),
        GoRoute(
          path: RouteNames.fieldWeightReport,
          pageBuilder: (context, state) {
            final orderId = state.pathParameters['orderId'];
            final order =
                state.extra is OrderModel ? state.extra as OrderModel : null;
            return fieldTransitionPage(
              key: state.pageKey,
              child: FieldWeightReportView(order: order, orderId: orderId),
            );
          },
        ),
        GoRoute(
          path: RouteNames.fieldRateSupplier,
          pageBuilder:
              (context, state) => fieldTransitionPage(
                key: state.pageKey,
                child: FieldRateSupplierView(order: state.extra as OrderModel),
              ),
        ),
        GoRoute(
          path: RouteNames.fieldChat,
          pageBuilder:
              (context, state) => fieldTransitionPage(
                key: state.pageKey,
                child: const FieldChatListView(),
              ),
        ),
        GoRoute(
          path: RouteNames.fieldChatThread,
          pageBuilder: (context, state) {
            final args = state.extra as FieldChatThreadArgs?;
            final pathSupplierUid = state.pathParameters['orderId'];
            return fieldTransitionPage(
              key: state.pageKey,
              child: FieldChatThreadView(
                supplierUid: args?.supplierUid ?? pathSupplierUid ?? '',
                supplierName: args?.supplierName ?? '',
                orderId: args?.orderId,
              ),
            );
          },
        ),
        GoRoute(
          path: RouteNames.fieldNotifications,
          pageBuilder:
              (context, state) => fieldTransitionPage(
                key: state.pageKey,
                child: const FieldNotificationsView(),
              ),
        ),
        GoRoute(
          path: RouteNames.fieldProfile,
          pageBuilder:
              (context, state) => fieldTransitionPage(
                key: state.pageKey,
                child: const FieldProfileView(),
              ),
        ),
        GoRoute(
          path: RouteNames.fieldMyDisputes,
          pageBuilder:
              (context, state) => fieldTransitionPage(
                key: state.pageKey,
                child: const FieldMyDisputesView(),
              ),
        ),
        GoRoute(
          path: RouteNames.fieldDisputeDetail,
          pageBuilder:
              (context, state) => fieldTransitionPage(
                key: state.pageKey,
                child: DisputeRecordDetailView(
                  disputeId: state.pathParameters['disputeId'] ?? '',
                  audience: DisputeDetailAudience.field,
                ),
              ),
        ),
        GoRoute(
          path: RouteNames.fieldSupplierProfile,
          pageBuilder:
              (context, state) => fieldTransitionPage(
                key: state.pageKey,
                child: FieldSupplierProfileView(
                  supplierUid: state.pathParameters['supplierUid'] ?? '',
                ),
              ),
        ),

        GoRoute(
          path: RouteNames.supplierDashboard,
          builder:
              (context, state) =>
                  SupplierTheme.wrap(const SupplierDashboardView()),
        ),
        GoRoute(
          path: RouteNames.supplierPending,
          builder:
              (context, state) =>
                  SupplierTheme.wrap(const SupplierPendingView()),
        ),
        GoRoute(
          path: RouteNames.supplierAppeal,
          builder:
              (context, state) =>
                  SupplierTheme.wrap(const SupplierAppealView()),
        ),
        GoRoute(
          path: RouteNames.supplierMaterials,
          builder:
              (context, state) =>
                  SupplierTheme.wrap(const SupplierMaterialsView()),
        ),
        GoRoute(
          path: RouteNames.supplierMaterialDetail,
          builder: (context, state) {
            final extra = state.extra;
            return SupplierTheme.wrap(
              SupplierMaterialDetailView(
                materialId: state.pathParameters['matId'] ?? '',
                initialMaterial: extra is MaterialModel ? extra : null,
              ),
            );
          },
        ),
        GoRoute(
          path: RouteNames.supplierAddMaterial,
          builder:
              (context, state) =>
                  SupplierTheme.wrap(const SupplierAddMaterialView()),
        ),
        GoRoute(
          path: RouteNames.supplierEditMaterial,
          builder:
              (context, state) => SupplierTheme.wrap(
                SupplierEditMaterialView(
                  material: state.extra as MaterialModel,
                ),
              ),
        ),
        GoRoute(
          path: RouteNames.supplierOrders,
          builder: (context, state) {
            final tab =
                int.tryParse(state.uri.queryParameters['tab'] ?? '') ?? 0;
            return SupplierTheme.wrap(SupplierOrdersView(initialTabIndex: tab));
          },
        ),
        GoRoute(
          path: RouteNames.supplierRfqs,
          builder:
              (context, state) =>
                  SupplierTheme.wrap(const SupplierRfqListView()),
        ),
        GoRoute(
          path: RouteNames.supplierSubmitBid,
          builder:
              (context, state) => SupplierTheme.wrap(
                SubmitBidView(rfqId: state.pathParameters['rfqId'] ?? ''),
              ),
        ),
        GoRoute(
          path: RouteNames.supplierChat,
          builder:
              (context, state) => SupplierTheme.wrap(const SupplierChatView()),
        ),
        GoRoute(
          path: RouteNames.supplierChatThread,
          builder: (context, state) {
            final thread = state.extra as ChatThreadModel?;
            if (thread == null) {
              return SupplierTheme.wrap(
                const Scaffold(body: Center(child: Text('Chat not found'))),
              );
            }
            return SupplierTheme.wrap(SupplierChatThreadView(thread: thread));
          },
        ),
        GoRoute(
          path: RouteNames.supplierRatings,
          builder:
              (context, state) =>
                  SupplierTheme.wrap(const SupplierRatingsView()),
        ),
        GoRoute(
          path: RouteNames.supplierEarnings,
          builder:
              (context, state) =>
                  SupplierTheme.wrap(const SupplierEarningsView()),
        ),
        GoRoute(
          path: RouteNames.supplierProfile,
          builder:
              (context, state) =>
                  SupplierTheme.wrap(const SupplierProfileView()),
        ),
        GoRoute(
          path: RouteNames.supplierMyDisputes,
          builder:
              (context, state) =>
                  SupplierTheme.wrap(const SupplierMyDisputesView()),
        ),
        GoRoute(
          path: RouteNames.supplierPartnershipRequests,
          redirect:
              (context, state) => '${RouteNames.supplierMyCompanies}?tab=1',
        ),
        GoRoute(
          path: RouteNames.supplierCompanyDirectory,
          builder:
              (context, state) =>
                  SupplierTheme.wrap(const SupplierCompanyDirectoryView()),
        ),
        GoRoute(
          path: RouteNames.supplierMyCompanies,
          builder: (context, state) {
            final tab =
                int.tryParse(state.uri.queryParameters['tab'] ?? '0') ?? 0;
            return SupplierTheme.wrap(
              SupplierPartnershipsHubView(initialTab: tab),
            );
          },
        ),
        GoRoute(
          path: RouteNames.supplierNotifications,
          builder:
              (context, state) =>
                  SupplierTheme.wrap(const SupplierNotificationsView()),
        ),

        GoRoute(
          path: RouteNames.adminDashboard,
          builder:
              (context, state) => AdminTheme.wrap(const AdminDashboardView()),
        ),
        GoRoute(
          path: RouteNames.adminNotifications,
          builder:
              (context, state) =>
                  AdminTheme.wrap(const AdminNotificationsView()),
        ),
        GoRoute(
          path: RouteNames.adminCompanies,
          builder:
              (context, state) =>
                  AdminTheme.wrap(const AdminCeoManagementView()),
        ),
        GoRoute(
          path: RouteNames.adminCategories,
          builder:
              (context, state) => AdminTheme.wrap(const AdminCategoriesView()),
        ),
        GoRoute(
          path: RouteNames.adminPayments,
          builder:
              (context, state) =>
                  AdminTheme.wrap(const AdminPaymentQueueView()),
        ),
        GoRoute(
          path: RouteNames.adminSubscription,
          builder:
              (context, state) =>
                  AdminTheme.wrap(const AdminSubscriptionView()),
        ),
        GoRoute(
          path: RouteNames.adminDisputes,
          builder:
              (context, state) => AdminTheme.wrap(const AdminDisputeListView()),
        ),
        GoRoute(
          path: RouteNames.adminAuditLogs,
          builder:
              (context, state) => AdminTheme.wrap(const AdminAuditLogView()),
        ),
        GoRoute(
          path: '/admin/appeals',
          builder: (context, state) => AdminTheme.wrap(const AdminAppealsView()),
        ),
      ],
      redirect: (context, state) {
        final authVM = Provider.of<AuthViewModel>(context, listen: false);
        final path = state.matchedLocation;
        final isPublic =
            path == RouteNames.login ||
            path == RouteNames.registerCEO ||
            path == RouteNames.registerSupplier ||
            path == RouteNames.registerFieldUser ||
            path == RouteNames.forgotPassword ||
            path.startsWith('/invite') ||
            path == RouteNames.splash ||
            path == RouteNames.roleSelection;

        if (authVM.status == AuthStatus.loading) return null;
        if (authVM.user == null) return isPublic ? null : RouteNames.login;

        final role = authVM.user!.role
            .toLowerCase()
            .replaceAll(' ', '')
            .replaceAll('_', '');
        final status = (authVM.user!.status ?? 'pending').toLowerCase();

        if (status == 'pending') {
          if (path != RouteNames.pendingApproval &&
              path != RouteNames.ceoPending &&
              path != RouteNames.supplierPending) {
            if (role == 'ceo') return RouteNames.ceoPending;
            if (role == 'supplier') return RouteNames.supplierPending;
            return RouteNames.pendingApproval;
          }
          return null;
        }

        if (status == 'suspended') {
          return path == RouteNames.suspended ? null : RouteNames.suspended;
        }

        if (status == 'rejected') {
          if (path != RouteNames.rejected &&
              path != RouteNames.ceoPending &&
              path != RouteNames.supplierPending &&
              path != RouteNames.supplierAppeal &&
              path != RouteNames.ceoAppeal) {
            if (role == 'ceo') return RouteNames.ceoPending;
            if (role == 'supplier') return RouteNames.supplierPending;
            return RouteNames.rejected;
          }
          return null;
        }

        String homeForRole() {
          if (role == 'admin' || role == 'administrator') {
            return RouteNames.adminDashboard;
          }
          if (role == 'ceo') return RouteNames.ceoDashboard;
          if (role == 'supplier') return RouteNames.supplierDashboard;
          return RouteNames.fieldHome;
        }

        if (path == RouteNames.adminDisputes &&
            role != 'admin' &&
            role != 'administrator') {
          return homeForRole();
        }
        if (path.startsWith('/ceo/disputes') && role != 'ceo') {
          return homeForRole();
        }
        if (path.startsWith('/field/disputes') && role != 'fielduser') {
          return homeForRole();
        }
        if (path == RouteNames.supplierMyDisputes && role != 'supplier') {
          return homeForRole();
        }

        if (isPublic) {
          if (role == 'admin') return RouteNames.adminDashboard;
          if (role == 'ceo') return RouteNames.ceoDashboard;
          if (role == 'supplier') return RouteNames.supplierDashboard;
          if (role == 'fielduser') return RouteNames.fieldHome;
        }

        return null;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'RATEBRIDGE',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.light,
      locale: const Locale('en'),
      theme: RateBridgeTheme.light(),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en', '')],
      routerConfig: _router,
    );
  }
}
