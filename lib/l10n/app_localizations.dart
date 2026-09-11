import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('en')];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'RateBridge'**
  String get appName;

  /// No description provided for @welcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome Back,'**
  String get welcomeBack;

  /// No description provided for @comparePrices.
  ///
  /// In en, this message translates to:
  /// **'Compare Prices'**
  String get comparePrices;

  /// No description provided for @searchMaterials.
  ///
  /// In en, this message translates to:
  /// **'Search materials, brands or suppliers...'**
  String get searchMaterials;

  /// No description provided for @voiceSearch.
  ///
  /// In en, this message translates to:
  /// **'Voice Search'**
  String get voiceSearch;

  /// No description provided for @placeOrder.
  ///
  /// In en, this message translates to:
  /// **'Place Order'**
  String get placeOrder;

  /// No description provided for @myOrders.
  ///
  /// In en, this message translates to:
  /// **'My Orders'**
  String get myOrders;

  /// No description provided for @deleteSelected.
  ///
  /// In en, this message translates to:
  /// **'Delete Selected'**
  String get deleteSelected;

  /// No description provided for @selectAll.
  ///
  /// In en, this message translates to:
  /// **'Select All'**
  String get selectAll;

  /// No description provided for @clearAll.
  ///
  /// In en, this message translates to:
  /// **'Clear All'**
  String get clearAll;

  /// No description provided for @deleteConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete {count} items?'**
  String deleteConfirmTitle(int count);

  /// No description provided for @deleteConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete these items? This action cannot be undone.'**
  String get deleteConfirmMessage;

  /// No description provided for @clearHistoryConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear History?'**
  String get clearHistoryConfirmTitle;

  /// No description provided for @clearHistoryConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'This will remove the selected history from your account.'**
  String get clearHistoryConfirmMessage;

  /// No description provided for @deleteSuccess.
  ///
  /// In en, this message translates to:
  /// **'Items deleted successfully'**
  String get deleteSuccess;

  /// No description provided for @deleteError.
  ///
  /// In en, this message translates to:
  /// **'Unable to delete items. Please try again.'**
  String get deleteError;

  /// No description provided for @supplierDashboard.
  ///
  /// In en, this message translates to:
  /// **'Supplier Dashboard'**
  String get supplierDashboard;

  /// No description provided for @addMaterial.
  ///
  /// In en, this message translates to:
  /// **'Add Material'**
  String get addMaterial;

  /// No description provided for @priceHistory.
  ///
  /// In en, this message translates to:
  /// **'Price History'**
  String get priceHistory;

  /// No description provided for @aiRecommendation.
  ///
  /// In en, this message translates to:
  /// **'AI Recommendation'**
  String get aiRecommendation;

  /// No description provided for @aiInsight.
  ///
  /// In en, this message translates to:
  /// **'AI Price Insight'**
  String get aiInsight;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @subscription.
  ///
  /// In en, this message translates to:
  /// **'Subscription'**
  String get subscription;

  /// No description provided for @upgrade.
  ///
  /// In en, this message translates to:
  /// **'Upgrade Plan'**
  String get upgrade;

  /// No description provided for @aiLocked.
  ///
  /// In en, this message translates to:
  /// **'AI Features Locked'**
  String get aiLocked;

  /// No description provided for @aiLockedDesc.
  ///
  /// In en, this message translates to:
  /// **'Upgrade your subscription to unlock AI-powered features'**
  String get aiLockedDesc;

  /// No description provided for @upgradeNow.
  ///
  /// In en, this message translates to:
  /// **'Upgrade Now'**
  String get upgradeNow;

  /// No description provided for @deliveryConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm Delivery'**
  String get deliveryConfirm;

  /// No description provided for @rateSupplier.
  ///
  /// In en, this message translates to:
  /// **'Rate Supplier'**
  String get rateSupplier;

  /// No description provided for @orderPlaced.
  ///
  /// In en, this message translates to:
  /// **'Order Placed Successfully'**
  String get orderPlaced;

  /// No description provided for @orderAccepted.
  ///
  /// In en, this message translates to:
  /// **'Order Accepted'**
  String get orderAccepted;

  /// No description provided for @orderDelivered.
  ///
  /// In en, this message translates to:
  /// **'Order Delivered'**
  String get orderDelivered;

  /// No description provided for @orderConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Order Confirmed'**
  String get orderConfirmed;

  /// No description provided for @orderRejected.
  ///
  /// In en, this message translates to:
  /// **'Order Rejected'**
  String get orderRejected;

  /// No description provided for @appealSubmit.
  ///
  /// In en, this message translates to:
  /// **'Submit Appeal'**
  String get appealSubmit;

  /// No description provided for @joinRequest.
  ///
  /// In en, this message translates to:
  /// **'Send Join Request'**
  String get joinRequest;

  /// No description provided for @inviteSupplier.
  ///
  /// In en, this message translates to:
  /// **'Invite Supplier'**
  String get inviteSupplier;

  /// No description provided for @companyDirectory.
  ///
  /// In en, this message translates to:
  /// **'Company Directory'**
  String get companyDirectory;

  /// No description provided for @earnings.
  ///
  /// In en, this message translates to:
  /// **'My Earnings'**
  String get earnings;

  /// No description provided for @commission.
  ///
  /// In en, this message translates to:
  /// **'Platform Commission'**
  String get commission;

  /// No description provided for @commissionNote.
  ///
  /// In en, this message translates to:
  /// **'2% platform fee applied on order total'**
  String get commissionNote;

  /// No description provided for @priceNormal.
  ///
  /// In en, this message translates to:
  /// **'Normal Price'**
  String get priceNormal;

  /// No description provided for @selectCategory.
  ///
  /// In en, this message translates to:
  /// **'Select Category'**
  String get selectCategory;

  /// No description provided for @selectBrand.
  ///
  /// In en, this message translates to:
  /// **'Select Brand'**
  String get selectBrand;

  /// No description provided for @selectGrade.
  ///
  /// In en, this message translates to:
  /// **'Select Grade'**
  String get selectGrade;

  /// No description provided for @enterQuantity.
  ///
  /// In en, this message translates to:
  /// **'Enter Quantity'**
  String get enterQuantity;

  /// No description provided for @deliveryAddress.
  ///
  /// In en, this message translates to:
  /// **'Delivery Address'**
  String get deliveryAddress;

  /// No description provided for @orderNotes.
  ///
  /// In en, this message translates to:
  /// **'Order Notes (optional)'**
  String get orderNotes;

  /// No description provided for @totalAmount.
  ///
  /// In en, this message translates to:
  /// **'Total Amount'**
  String get totalAmount;

  /// No description provided for @confirmOrder.
  ///
  /// In en, this message translates to:
  /// **'Confirm Order'**
  String get confirmOrder;

  /// No description provided for @cancelOrder.
  ///
  /// In en, this message translates to:
  /// **'Cancel Order'**
  String get cancelOrder;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get signOut;

  /// No description provided for @deleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete Account'**
  String get deleteAccount;

  /// No description provided for @languageSettings.
  ///
  /// In en, this message translates to:
  /// **'Language Settings'**
  String get languageSettings;

  /// No description provided for @changeLanguage.
  ///
  /// In en, this message translates to:
  /// **'Change Language'**
  String get changeLanguage;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'An error occurred'**
  String get error;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @noData.
  ///
  /// In en, this message translates to:
  /// **'No data available'**
  String get noData;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @accept.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get accept;

  /// No description provided for @reject.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get reject;

  /// No description provided for @pending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get pending;

  /// No description provided for @active.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get active;

  /// No description provided for @inactive.
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get inactive;

  /// No description provided for @verified.
  ///
  /// In en, this message translates to:
  /// **'Verified'**
  String get verified;

  /// No description provided for @free.
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get free;

  /// No description provided for @basic.
  ///
  /// In en, this message translates to:
  /// **'Basic'**
  String get basic;

  /// No description provided for @premium.
  ///
  /// In en, this message translates to:
  /// **'Premium'**
  String get premium;

  /// No description provided for @dashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get dashboard;

  /// No description provided for @materials.
  ///
  /// In en, this message translates to:
  /// **'Materials'**
  String get materials;

  /// No description provided for @orders.
  ///
  /// In en, this message translates to:
  /// **'Orders'**
  String get orders;

  /// No description provided for @chat.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get chat;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @suppliers.
  ///
  /// In en, this message translates to:
  /// **'Suppliers'**
  String get suppliers;

  /// No description provided for @categories.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get categories;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @filter.
  ///
  /// In en, this message translates to:
  /// **'Filter'**
  String get filter;

  /// No description provided for @sort.
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get sort;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @apply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get apply;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @submit.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get submit;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @overall.
  ///
  /// In en, this message translates to:
  /// **'Overall'**
  String get overall;

  /// No description provided for @quality.
  ///
  /// In en, this message translates to:
  /// **'Quality'**
  String get quality;

  /// No description provided for @packaging.
  ///
  /// In en, this message translates to:
  /// **'Packaging'**
  String get packaging;

  /// No description provided for @quantity.
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get quantity;

  /// No description provided for @rating.
  ///
  /// In en, this message translates to:
  /// **'Rating'**
  String get rating;

  /// No description provided for @reviews.
  ///
  /// In en, this message translates to:
  /// **'Reviews'**
  String get reviews;

  /// No description provided for @noReviews.
  ///
  /// In en, this message translates to:
  /// **'No reviews yet'**
  String get noReviews;

  /// No description provided for @feedbackOptional.
  ///
  /// In en, this message translates to:
  /// **'Leave a comment (optional)'**
  String get feedbackOptional;

  /// No description provided for @thankYouFeedback.
  ///
  /// In en, this message translates to:
  /// **'Thank you for your feedback!'**
  String get thankYouFeedback;

  /// No description provided for @orderPending.
  ///
  /// In en, this message translates to:
  /// **'Order is pending supplier response'**
  String get orderPending;

  /// No description provided for @awaitingApproval.
  ///
  /// In en, this message translates to:
  /// **'Awaiting Approval'**
  String get awaitingApproval;

  /// No description provided for @approvalPending.
  ///
  /// In en, this message translates to:
  /// **'Your account is pending CEO approval'**
  String get approvalPending;

  /// No description provided for @accountRejected.
  ///
  /// In en, this message translates to:
  /// **'Account Rejected'**
  String get accountRejected;

  /// No description provided for @submitAppealDesc.
  ///
  /// In en, this message translates to:
  /// **'Provide additional information for CEO review'**
  String get submitAppealDesc;

  /// No description provided for @oneAppealOnly.
  ///
  /// In en, this message translates to:
  /// **'You may only submit one appeal per rejection'**
  String get oneAppealOnly;

  /// No description provided for @inviteCode.
  ///
  /// In en, this message translates to:
  /// **'Invite Code'**
  String get inviteCode;

  /// No description provided for @copyCode.
  ///
  /// In en, this message translates to:
  /// **'Copy Code'**
  String get copyCode;

  /// No description provided for @regenerateCode.
  ///
  /// In en, this message translates to:
  /// **'Regenerate Code'**
  String get regenerateCode;

  /// No description provided for @aiUnavailable.
  ///
  /// In en, this message translates to:
  /// **'AI recommendations temporarily unavailable. Please try again in a moment.'**
  String get aiUnavailable;

  /// No description provided for @aiRateLimit.
  ///
  /// In en, this message translates to:
  /// **'AI service is busy. Please wait a minute and try again.'**
  String get aiRateLimit;

  /// No description provided for @voiceListening.
  ///
  /// In en, this message translates to:
  /// **'Listening...'**
  String get voiceListening;

  /// No description provided for @voiceError.
  ///
  /// In en, this message translates to:
  /// **'Could not recognize speech. Try again.'**
  String get voiceError;

  /// No description provided for @micPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Microphone permission required for voice search'**
  String get micPermissionDenied;

  /// No description provided for @priceHistoryInsufficient.
  ///
  /// In en, this message translates to:
  /// **'3+ months of price data needed for AI insight'**
  String get priceHistoryInsufficient;

  /// No description provided for @noOrdersYet.
  ///
  /// In en, this message translates to:
  /// **'No orders yet'**
  String get noOrdersYet;

  /// No description provided for @chatLocked.
  ///
  /// In en, this message translates to:
  /// **'Order complete — chat is read-only'**
  String get chatLocked;

  /// No description provided for @sendMessage.
  ///
  /// In en, this message translates to:
  /// **'Send a message'**
  String get sendMessage;

  /// No description provided for @typeMessage.
  ///
  /// In en, this message translates to:
  /// **'Type a message...'**
  String get typeMessage;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @yesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get yesterday;

  /// No description provided for @daysAgo.
  ///
  /// In en, this message translates to:
  /// **'{days} days ago'**
  String daysAgo(int days);

  /// No description provided for @rsAmount.
  ///
  /// In en, this message translates to:
  /// **'Rs. {amount}'**
  String rsAmount(String amount);

  /// No description provided for @planExpiresIn.
  ///
  /// In en, this message translates to:
  /// **'Plan expires in {days} days'**
  String planExpiresIn(int days);

  /// No description provided for @pendingOrdersAlert.
  ///
  /// In en, this message translates to:
  /// **'You have {count} pending orders'**
  String pendingOrdersAlert(int count);

  /// No description provided for @invited.
  ///
  /// In en, this message translates to:
  /// **'Invited'**
  String get invited;

  /// No description provided for @requests.
  ///
  /// In en, this message translates to:
  /// **'Requests'**
  String get requests;

  /// No description provided for @invite.
  ///
  /// In en, this message translates to:
  /// **'Invite'**
  String get invite;

  /// No description provided for @marketplace.
  ///
  /// In en, this message translates to:
  /// **'Marketplace'**
  String get marketplace;

  /// No description provided for @searchSuppliers.
  ///
  /// In en, this message translates to:
  /// **'Search vendors, materials...'**
  String get searchSuppliers;

  /// No description provided for @sendInvitation.
  ///
  /// In en, this message translates to:
  /// **'Send Invitation'**
  String get sendInvitation;

  /// No description provided for @inviteConfirmDesc.
  ///
  /// In en, this message translates to:
  /// **'Invite {name} to join your procurement network?'**
  String inviteConfirmDesc(String name);

  /// No description provided for @invitationSent.
  ///
  /// In en, this message translates to:
  /// **'Invitation sent successfully'**
  String get invitationSent;

  /// No description provided for @linked.
  ///
  /// In en, this message translates to:
  /// **'Linked'**
  String get linked;

  /// No description provided for @alreadyLinked.
  ///
  /// In en, this message translates to:
  /// **'Supplier is already linked to your workspace.'**
  String get alreadyLinked;

  /// No description provided for @billing.
  ///
  /// In en, this message translates to:
  /// **'Billing'**
  String get billing;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
