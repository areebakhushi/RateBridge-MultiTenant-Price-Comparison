// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'RateBridge';

  @override
  String get welcomeBack => 'Welcome Back,';

  @override
  String get comparePrices => 'Compare Prices';

  @override
  String get searchMaterials => 'Search materials, brands or suppliers...';

  @override
  String get voiceSearch => 'Voice Search';

  @override
  String get placeOrder => 'Place Order';

  @override
  String get myOrders => 'My Orders';

  @override
  String get deleteSelected => 'Delete Selected';

  @override
  String get selectAll => 'Select All';

  @override
  String get clearAll => 'Clear All';

  @override
  String deleteConfirmTitle(int count) {
    return 'Delete $count items?';
  }

  @override
  String get deleteConfirmMessage =>
      'Are you sure you want to delete these items? This action cannot be undone.';

  @override
  String get clearHistoryConfirmTitle => 'Clear History?';

  @override
  String get clearHistoryConfirmMessage =>
      'This will remove the selected history from your account.';

  @override
  String get deleteSuccess => 'Items deleted successfully';

  @override
  String get deleteError => 'Unable to delete items. Please try again.';

  @override
  String get supplierDashboard => 'Supplier Dashboard';

  @override
  String get addMaterial => 'Add Material';

  @override
  String get priceHistory => 'Price History';

  @override
  String get aiRecommendation => 'AI Recommendation';

  @override
  String get aiInsight => 'AI Price Insight';

  @override
  String get notifications => 'Notifications';

  @override
  String get subscription => 'Subscription';

  @override
  String get upgrade => 'Upgrade Plan';

  @override
  String get aiLocked => 'AI Features Locked';

  @override
  String get aiLockedDesc =>
      'Upgrade your subscription to unlock AI-powered features';

  @override
  String get upgradeNow => 'Upgrade Now';

  @override
  String get deliveryConfirm => 'Confirm Delivery';

  @override
  String get rateSupplier => 'Rate Supplier';

  @override
  String get orderPlaced => 'Order Placed Successfully';

  @override
  String get orderAccepted => 'Order Accepted';

  @override
  String get orderDelivered => 'Order Delivered';

  @override
  String get orderConfirmed => 'Order Confirmed';

  @override
  String get orderRejected => 'Order Rejected';

  @override
  String get appealSubmit => 'Submit Appeal';

  @override
  String get joinRequest => 'Send Join Request';

  @override
  String get inviteSupplier => 'Invite Supplier';

  @override
  String get companyDirectory => 'Company Directory';

  @override
  String get earnings => 'My Earnings';

  @override
  String get commission => 'Platform Commission';

  @override
  String get commissionNote => '2% platform fee applied on order total';

  @override
  String get priceNormal => 'Normal Price';

  @override
  String get selectCategory => 'Select Category';

  @override
  String get selectBrand => 'Select Brand';

  @override
  String get selectGrade => 'Select Grade';

  @override
  String get enterQuantity => 'Enter Quantity';

  @override
  String get deliveryAddress => 'Delivery Address';

  @override
  String get orderNotes => 'Order Notes (optional)';

  @override
  String get totalAmount => 'Total Amount';

  @override
  String get confirmOrder => 'Confirm Order';

  @override
  String get cancelOrder => 'Cancel Order';

  @override
  String get signOut => 'Sign Out';

  @override
  String get deleteAccount => 'Delete Account';

  @override
  String get languageSettings => 'Language Settings';

  @override
  String get changeLanguage => 'Change Language';

  @override
  String get english => 'English';

  @override
  String get loading => 'Loading...';

  @override
  String get error => 'An error occurred';

  @override
  String get retry => 'Retry';

  @override
  String get noData => 'No data available';

  @override
  String get save => 'Save';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get edit => 'Edit';

  @override
  String get accept => 'Accept';

  @override
  String get reject => 'Reject';

  @override
  String get pending => 'Pending';

  @override
  String get active => 'Active';

  @override
  String get inactive => 'Inactive';

  @override
  String get verified => 'Verified';

  @override
  String get free => 'Free';

  @override
  String get basic => 'Basic';

  @override
  String get premium => 'Premium';

  @override
  String get dashboard => 'Dashboard';

  @override
  String get materials => 'Materials';

  @override
  String get orders => 'Orders';

  @override
  String get chat => 'Chat';

  @override
  String get profile => 'Profile';

  @override
  String get settings => 'Settings';

  @override
  String get suppliers => 'Suppliers';

  @override
  String get categories => 'Categories';

  @override
  String get search => 'Search';

  @override
  String get filter => 'Filter';

  @override
  String get sort => 'Sort';

  @override
  String get clear => 'Clear';

  @override
  String get apply => 'Apply';

  @override
  String get close => 'Close';

  @override
  String get back => 'Back';

  @override
  String get next => 'Next';

  @override
  String get submit => 'Submit';

  @override
  String get confirm => 'Confirm';

  @override
  String get overall => 'Overall';

  @override
  String get quality => 'Quality';

  @override
  String get packaging => 'Packaging';

  @override
  String get quantity => 'Quantity';

  @override
  String get rating => 'Rating';

  @override
  String get reviews => 'Reviews';

  @override
  String get noReviews => 'No reviews yet';

  @override
  String get feedbackOptional => 'Leave a comment (optional)';

  @override
  String get thankYouFeedback => 'Thank you for your feedback!';

  @override
  String get orderPending => 'Order is pending supplier response';

  @override
  String get awaitingApproval => 'Awaiting Approval';

  @override
  String get approvalPending => 'Your account is pending CEO approval';

  @override
  String get accountRejected => 'Account Rejected';

  @override
  String get submitAppealDesc =>
      'Provide additional information for CEO review';

  @override
  String get oneAppealOnly => 'You may only submit one appeal per rejection';

  @override
  String get inviteCode => 'Invite Code';

  @override
  String get copyCode => 'Copy Code';

  @override
  String get regenerateCode => 'Regenerate Code';

  @override
  String get aiUnavailable =>
      'AI recommendations temporarily unavailable. Please try again in a moment.';

  @override
  String get aiRateLimit =>
      'AI service is busy. Please wait a minute and try again.';

  @override
  String get voiceListening => 'Listening...';

  @override
  String get voiceError => 'Could not recognize speech. Try again.';

  @override
  String get micPermissionDenied =>
      'Microphone permission required for voice search';

  @override
  String get priceHistoryInsufficient =>
      '3+ months of price data needed for AI insight';

  @override
  String get noOrdersYet => 'No orders yet';

  @override
  String get chatLocked => 'Order complete — chat is read-only';

  @override
  String get sendMessage => 'Send a message';

  @override
  String get typeMessage => 'Type a message...';

  @override
  String get today => 'Today';

  @override
  String get yesterday => 'Yesterday';

  @override
  String daysAgo(int days) {
    return '$days days ago';
  }

  @override
  String rsAmount(String amount) {
    return 'Rs. $amount';
  }

  @override
  String planExpiresIn(int days) {
    return 'Plan expires in $days days';
  }

  @override
  String pendingOrdersAlert(int count) {
    return 'You have $count pending orders';
  }

  @override
  String get invited => 'Invited';

  @override
  String get requests => 'Requests';

  @override
  String get invite => 'Invite';

  @override
  String get marketplace => 'Marketplace';

  @override
  String get searchSuppliers => 'Search vendors, materials...';

  @override
  String get sendInvitation => 'Send Invitation';

  @override
  String inviteConfirmDesc(String name) {
    return 'Invite $name to join your procurement network?';
  }

  @override
  String get invitationSent => 'Invitation sent successfully';

  @override
  String get linked => 'Linked';

  @override
  String get alreadyLinked => 'Supplier is already linked to your workspace.';

  @override
  String get billing => 'Billing';
}
