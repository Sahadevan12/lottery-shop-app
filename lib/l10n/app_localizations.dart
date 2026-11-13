import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ml.dart';
import 'app_localizations_ta.dart';

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

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
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
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ml'),
    Locale('ta')
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'LuckyLedger'**
  String get appName;

  /// No description provided for @chooseLanguageTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose your language'**
  String get chooseLanguageTitle;

  /// No description provided for @chooseLanguageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'You can change this anytime in Settings'**
  String get chooseLanguageSubtitle;

  /// No description provided for @languageMalayalam.
  ///
  /// In en, this message translates to:
  /// **'മലയാളം'**
  String get languageMalayalam;

  /// No description provided for @languageMalayalamSub.
  ///
  /// In en, this message translates to:
  /// **'Malayalam'**
  String get languageMalayalamSub;

  /// No description provided for @languageTamil.
  ///
  /// In en, this message translates to:
  /// **'தமிழ்'**
  String get languageTamil;

  /// No description provided for @languageTamilSub.
  ///
  /// In en, this message translates to:
  /// **'Tamil'**
  String get languageTamilSub;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageEnglishSub.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglishSub;

  /// No description provided for @continueAction.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueAction;

  /// No description provided for @getStartedAction.
  ///
  /// In en, this message translates to:
  /// **'Get started'**
  String get getStartedAction;

  /// No description provided for @nextAction.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get nextAction;

  /// No description provided for @skipAction.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skipAction;

  /// No description provided for @cancelAction.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancelAction;

  /// No description provided for @confirmAction.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirmAction;

  /// No description provided for @saveAction.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get saveAction;

  /// No description provided for @deleteAction.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get deleteAction;

  /// No description provided for @retryAction.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retryAction;

  /// No description provided for @undoAction.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undoAction;

  /// No description provided for @seeAllAction.
  ///
  /// In en, this message translates to:
  /// **'See all'**
  String get seeAllAction;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search...'**
  String get searchHint;

  /// No description provided for @welcomeSlide1Title.
  ///
  /// In en, this message translates to:
  /// **'Track your ticket stock'**
  String get welcomeSlide1Title;

  /// No description provided for @welcomeSlide1Body.
  ///
  /// In en, this message translates to:
  /// **'Add ticket books in seconds and see what is in stock, with sellers, or sold.'**
  String get welcomeSlide1Body;

  /// No description provided for @welcomeSlide2Title.
  ///
  /// In en, this message translates to:
  /// **'Manage your sellers\' khata'**
  String get welcomeSlide2Title;

  /// No description provided for @welcomeSlide2Body.
  ///
  /// In en, this message translates to:
  /// **'Issue tickets on credit, record returns and payments, and always know the exact balance due.'**
  String get welcomeSlide2Body;

  /// No description provided for @welcomeSlide3Title.
  ///
  /// In en, this message translates to:
  /// **'Find winners in 10 seconds'**
  String get welcomeSlide3Title;

  /// No description provided for @welcomeSlide3Body.
  ///
  /// In en, this message translates to:
  /// **'Enter the 3 PM draw result once to spot every winning ticket and who sold it.'**
  String get welcomeSlide3Body;

  /// No description provided for @legalDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'This app is an independent business tool for lottery retailers. It is not affiliated with the Kerala State Lotteries Department or any government body. It does not sell lottery tickets. Always verify results with the official Kerala State Lotteries website.'**
  String get legalDisclaimer;

  /// No description provided for @verifyOfficialResultNote.
  ///
  /// In en, this message translates to:
  /// **'Verify with official result'**
  String get verifyOfficialResultNote;

  /// No description provided for @loginTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to your shop'**
  String get loginTitle;

  /// No description provided for @loginSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter your 10-digit mobile number and 6-digit PIN'**
  String get loginSubtitle;

  /// No description provided for @phoneLabel.
  ///
  /// In en, this message translates to:
  /// **'Mobile number'**
  String get phoneLabel;

  /// No description provided for @phoneHint.
  ///
  /// In en, this message translates to:
  /// **'98765 43210'**
  String get phoneHint;

  /// No description provided for @phonePrefix.
  ///
  /// In en, this message translates to:
  /// **'+91'**
  String get phonePrefix;

  /// No description provided for @pinLabel.
  ///
  /// In en, this message translates to:
  /// **'6-digit PIN'**
  String get pinLabel;

  /// No description provided for @signInAction.
  ///
  /// In en, this message translates to:
  /// **'Sign in / Continue'**
  String get signInAction;

  /// No description provided for @forgotPinAction.
  ///
  /// In en, this message translates to:
  /// **'Forgot PIN?'**
  String get forgotPinAction;

  /// No description provided for @forgotPinDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset your PIN'**
  String get forgotPinDialogTitle;

  /// No description provided for @forgotPinDialogBody.
  ///
  /// In en, this message translates to:
  /// **'Please contact LuckyLedger Retailer Support with your registered mobile number and shop agent code to reset your PIN.'**
  String get forgotPinDialogBody;

  /// No description provided for @contactSupportClose.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get contactSupportClose;

  /// No description provided for @invalidPhoneError.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid 10-digit mobile number'**
  String get invalidPhoneError;

  /// No description provided for @invalidPinError.
  ///
  /// In en, this message translates to:
  /// **'Enter a 6-digit numeric PIN'**
  String get invalidPinError;

  /// No description provided for @shopSetupTitle.
  ///
  /// In en, this message translates to:
  /// **'Set up your shop'**
  String get shopSetupTitle;

  /// No description provided for @shopSetupSubtitle.
  ///
  /// In en, this message translates to:
  /// **'We will create default weekly lotteries and prize templates for your shop.'**
  String get shopSetupSubtitle;

  /// No description provided for @shopNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Shop name'**
  String get shopNameLabel;

  /// No description provided for @shopNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Sri Lakshmi Agencies'**
  String get shopNameHint;

  /// No description provided for @ownerNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Owner name'**
  String get ownerNameLabel;

  /// No description provided for @ownerNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Ramesh Nair'**
  String get ownerNameHint;

  /// No description provided for @districtLabel.
  ///
  /// In en, this message translates to:
  /// **'District'**
  String get districtLabel;

  /// No description provided for @districtHint.
  ///
  /// In en, this message translates to:
  /// **'Select district'**
  String get districtHint;

  /// No description provided for @agentCodeLabel.
  ///
  /// In en, this message translates to:
  /// **'Lottery agent / retailer code (optional)'**
  String get agentCodeLabel;

  /// No description provided for @agentCodeHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. EKM-4821'**
  String get agentCodeHint;

  /// No description provided for @shopNameRequiredError.
  ///
  /// In en, this message translates to:
  /// **'Please enter your shop name'**
  String get shopNameRequiredError;

  /// No description provided for @ownerNameRequiredError.
  ///
  /// In en, this message translates to:
  /// **'Please enter the owner name'**
  String get ownerNameRequiredError;

  /// No description provided for @districtRequiredError.
  ///
  /// In en, this message translates to:
  /// **'Please select a district'**
  String get districtRequiredError;

  /// No description provided for @completeSetupAction.
  ///
  /// In en, this message translates to:
  /// **'Create shop & start'**
  String get completeSetupAction;

  /// No description provided for @districtThiruvananthapuram.
  ///
  /// In en, this message translates to:
  /// **'Thiruvananthapuram'**
  String get districtThiruvananthapuram;

  /// No description provided for @districtKollam.
  ///
  /// In en, this message translates to:
  /// **'Kollam'**
  String get districtKollam;

  /// No description provided for @districtPathanamthitta.
  ///
  /// In en, this message translates to:
  /// **'Pathanamthitta'**
  String get districtPathanamthitta;

  /// No description provided for @districtAlappuzha.
  ///
  /// In en, this message translates to:
  /// **'Alappuzha'**
  String get districtAlappuzha;

  /// No description provided for @districtKottayam.
  ///
  /// In en, this message translates to:
  /// **'Kottayam'**
  String get districtKottayam;

  /// No description provided for @districtIdukki.
  ///
  /// In en, this message translates to:
  /// **'Idukki'**
  String get districtIdukki;

  /// No description provided for @districtErnakulam.
  ///
  /// In en, this message translates to:
  /// **'Ernakulam'**
  String get districtErnakulam;

  /// No description provided for @districtThrissur.
  ///
  /// In en, this message translates to:
  /// **'Thrissur'**
  String get districtThrissur;

  /// No description provided for @districtPalakkad.
  ///
  /// In en, this message translates to:
  /// **'Palakkad'**
  String get districtPalakkad;

  /// No description provided for @districtMalappuram.
  ///
  /// In en, this message translates to:
  /// **'Malappuram'**
  String get districtMalappuram;

  /// No description provided for @districtKozhikode.
  ///
  /// In en, this message translates to:
  /// **'Kozhikode'**
  String get districtKozhikode;

  /// No description provided for @districtWayanad.
  ///
  /// In en, this message translates to:
  /// **'Wayanad'**
  String get districtWayanad;

  /// No description provided for @districtKannur.
  ///
  /// In en, this message translates to:
  /// **'Kannur'**
  String get districtKannur;

  /// No description provided for @districtKasaragod.
  ///
  /// In en, this message translates to:
  /// **'Kasaragod'**
  String get districtKasaragod;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navStock.
  ///
  /// In en, this message translates to:
  /// **'Stock'**
  String get navStock;

  /// No description provided for @navSellers.
  ///
  /// In en, this message translates to:
  /// **'Sellers'**
  String get navSellers;

  /// No description provided for @navResults.
  ///
  /// In en, this message translates to:
  /// **'Results'**
  String get navResults;

  /// No description provided for @navMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get navMore;

  /// No description provided for @greetingMorning.
  ///
  /// In en, this message translates to:
  /// **'Good morning, {name}'**
  String greetingMorning(String name);

  /// No description provided for @greetingAfternoon.
  ///
  /// In en, this message translates to:
  /// **'Good afternoon, {name}'**
  String greetingAfternoon(String name);

  /// No description provided for @greetingEvening.
  ///
  /// In en, this message translates to:
  /// **'Good evening, {name}'**
  String greetingEvening(String name);

  /// No description provided for @syncStatusSynced.
  ///
  /// In en, this message translates to:
  /// **'Synced ✓'**
  String get syncStatusSynced;

  /// No description provided for @syncStatusSyncing.
  ///
  /// In en, this message translates to:
  /// **'Syncing…'**
  String get syncStatusSyncing;

  /// No description provided for @syncStatusOffline.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get syncStatusOffline;

  /// No description provided for @statTotalTickets.
  ///
  /// In en, this message translates to:
  /// **'Total tickets'**
  String get statTotalTickets;

  /// No description provided for @statInStock.
  ///
  /// In en, this message translates to:
  /// **'In stock'**
  String get statInStock;

  /// No description provided for @statWithSellers.
  ///
  /// In en, this message translates to:
  /// **'With sellers'**
  String get statWithSellers;

  /// No description provided for @statSoldToday.
  ///
  /// In en, this message translates to:
  /// **'Sold today'**
  String get statSoldToday;

  /// No description provided for @statSold.
  ///
  /// In en, this message translates to:
  /// **'Sold'**
  String get statSold;

  /// No description provided for @statReturned.
  ///
  /// In en, this message translates to:
  /// **'Returned'**
  String get statReturned;

  /// No description provided for @statDueFromSellers.
  ///
  /// In en, this message translates to:
  /// **'Due from sellers'**
  String get statDueFromSellers;

  /// No description provided for @homeEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Your shop is ready'**
  String get homeEmptyTitle;

  /// No description provided for @homeEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Add today\'s ticket stock to start tracking sales, sellers, and winning numbers.'**
  String get homeEmptyBody;

  /// No description provided for @homeEmptyCta.
  ///
  /// In en, this message translates to:
  /// **'Go to Stock'**
  String get homeEmptyCta;

  /// No description provided for @stockEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No ticket stock yet'**
  String get stockEmptyTitle;

  /// No description provided for @stockEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Add your first ticket book range for this draw.'**
  String get stockEmptyBody;

  /// No description provided for @stockEmptyCta.
  ///
  /// In en, this message translates to:
  /// **'Add stock'**
  String get stockEmptyCta;

  /// No description provided for @createTodayDrawTitle.
  ///
  /// In en, this message translates to:
  /// **'Create today\'s draw'**
  String get createTodayDrawTitle;

  /// No description provided for @createTodayDrawBody.
  ///
  /// In en, this message translates to:
  /// **'Set up today\'s {lotteryName} draw to start adding ticket ranges.'**
  String createTodayDrawBody(String lotteryName);

  /// No description provided for @createDrawTitle.
  ///
  /// In en, this message translates to:
  /// **'Create draw'**
  String get createDrawTitle;

  /// No description provided for @newDrawChip.
  ///
  /// In en, this message translates to:
  /// **'+ New draw'**
  String get newDrawChip;

  /// No description provided for @drawSelectorToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get drawSelectorToday;

  /// No description provided for @drawSelectorTomorrow.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow'**
  String get drawSelectorTomorrow;

  /// No description provided for @drawSelectorBumper.
  ///
  /// In en, this message translates to:
  /// **'Bumper'**
  String get drawSelectorBumper;

  /// No description provided for @lotteryFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Lottery'**
  String get lotteryFieldLabel;

  /// No description provided for @drawDateFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Draw date'**
  String get drawDateFieldLabel;

  /// No description provided for @drawNumberFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Draw number (e.g. W-845)'**
  String get drawNumberFieldLabel;

  /// No description provided for @ticketPriceFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Selling price per ticket (₹)'**
  String get ticketPriceFieldLabel;

  /// No description provided for @prizeTemplateFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Prize structure template'**
  String get prizeTemplateFieldLabel;

  /// No description provided for @addStockTitle.
  ///
  /// In en, this message translates to:
  /// **'Add ticket stock'**
  String get addStockTitle;

  /// No description provided for @seriesFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Series (1–3 letters)'**
  String get seriesFieldLabel;

  /// No description provided for @seriesFieldHint.
  ///
  /// In en, this message translates to:
  /// **'KR'**
  String get seriesFieldHint;

  /// No description provided for @startNumberFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'From number (6 digits)'**
  String get startNumberFieldLabel;

  /// No description provided for @startNumberFieldHint.
  ///
  /// In en, this message translates to:
  /// **'482900'**
  String get startNumberFieldHint;

  /// No description provided for @endNumberFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'To number (6 digits)'**
  String get endNumberFieldLabel;

  /// No description provided for @endNumberFieldHint.
  ///
  /// In en, this message translates to:
  /// **'482999'**
  String get endNumberFieldHint;

  /// No description provided for @costPerTicketFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Purchase cost per ticket (₹)'**
  String get costPerTicketFieldLabel;

  /// No description provided for @costPerTicketFieldHint.
  ///
  /// In en, this message translates to:
  /// **'35'**
  String get costPerTicketFieldHint;

  /// No description provided for @addAnotherRangeLabel.
  ///
  /// In en, this message translates to:
  /// **'Add another range after saving'**
  String get addAnotherRangeLabel;

  /// No description provided for @quantityLabel.
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get quantityLabel;

  /// No description provided for @totalCostLabel.
  ///
  /// In en, this message translates to:
  /// **'Total cost'**
  String get totalCostLabel;

  /// No description provided for @ticketsCountLabel.
  ///
  /// In en, this message translates to:
  /// **'{count} tickets'**
  String ticketsCountLabel(String count);

  /// No description provided for @batchAddedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Added {count} tickets ({range})'**
  String batchAddedSuccess(String count, String range);

  /// No description provided for @deleteBatchTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this ticket batch?'**
  String get deleteBatchTitle;

  /// No description provided for @deleteBatchBody.
  ///
  /// In en, this message translates to:
  /// **'This will remove {range} ({count} tickets) from your stock.'**
  String deleteBatchBody(String range, String count);

  /// No description provided for @batchDeletedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Batch deleted'**
  String get batchDeletedSuccess;

  /// No description provided for @batchDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Batch tickets'**
  String get batchDetailTitle;

  /// No description provided for @filterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get filterAll;

  /// No description provided for @statusInStock.
  ///
  /// In en, this message translates to:
  /// **'In stock'**
  String get statusInStock;

  /// No description provided for @statusWithSeller.
  ///
  /// In en, this message translates to:
  /// **'With seller'**
  String get statusWithSeller;

  /// No description provided for @statusSold.
  ///
  /// In en, this message translates to:
  /// **'Sold'**
  String get statusSold;

  /// No description provided for @statusReturned.
  ///
  /// In en, this message translates to:
  /// **'Returned'**
  String get statusReturned;

  /// No description provided for @lotteriesTemplatesTitle.
  ///
  /// In en, this message translates to:
  /// **'Lotteries & Prize Templates'**
  String get lotteriesTemplatesTitle;

  /// No description provided for @lotteriesTemplatesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Edit weekly lotteries, bumper draws, and prize tiers'**
  String get lotteriesTemplatesSubtitle;

  /// No description provided for @lotteriesTab.
  ///
  /// In en, this message translates to:
  /// **'Lotteries'**
  String get lotteriesTab;

  /// No description provided for @prizeTemplatesTab.
  ///
  /// In en, this message translates to:
  /// **'Prize Templates'**
  String get prizeTemplatesTab;

  /// No description provided for @addLotteryAction.
  ///
  /// In en, this message translates to:
  /// **'Add lottery'**
  String get addLotteryAction;

  /// No description provided for @editLotteryTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit lottery'**
  String get editLotteryTitle;

  /// No description provided for @lotteryNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Lottery name'**
  String get lotteryNameLabel;

  /// No description provided for @lotteryCodeLabel.
  ///
  /// In en, this message translates to:
  /// **'Short code (e.g. W, KR)'**
  String get lotteryCodeLabel;

  /// No description provided for @isBumperLabel.
  ///
  /// In en, this message translates to:
  /// **'Bumper lottery'**
  String get isBumperLabel;

  /// No description provided for @sellersEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No sellers added yet'**
  String get sellersEmptyTitle;

  /// No description provided for @sellersEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Add walking sellers to track issued tickets and khata balances.'**
  String get sellersEmptyBody;

  /// No description provided for @sellersEmptyCta.
  ///
  /// In en, this message translates to:
  /// **'Add seller'**
  String get sellersEmptyCta;

  /// No description provided for @resultsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No draw results yet'**
  String get resultsEmptyTitle;

  /// No description provided for @resultsEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Enter the 3:00 PM draw results to check all your tickets in seconds.'**
  String get resultsEmptyBody;

  /// No description provided for @resultsEmptyCta.
  ///
  /// In en, this message translates to:
  /// **'Enter result'**
  String get resultsEmptyCta;

  /// No description provided for @moreTitle.
  ///
  /// In en, this message translates to:
  /// **'More & Settings'**
  String get moreTitle;

  /// No description provided for @settingsSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsSectionTitle;

  /// No description provided for @languageSettingLabel.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageSettingLabel;

  /// No description provided for @themeSettingLabel.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get themeSettingLabel;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @largeTextSettingLabel.
  ///
  /// In en, this message translates to:
  /// **'Large text (1.15×)'**
  String get largeTextSettingLabel;

  /// No description provided for @largeTextSettingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Easier reading in bright light'**
  String get largeTextSettingSubtitle;

  /// No description provided for @designPreviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Design System Preview'**
  String get designPreviewTitle;

  /// No description provided for @designPreviewSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Interactive token & component showcase (§4)'**
  String get designPreviewSubtitle;

  /// No description provided for @aboutSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'About & Legal'**
  String get aboutSectionTitle;

  /// No description provided for @logoutAction.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get logoutAction;

  /// No description provided for @logoutConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign out of LuckyLedger?'**
  String get logoutConfirmTitle;

  /// No description provided for @logoutConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Make sure any pending entries are synced before signing out.'**
  String get logoutConfirmBody;

  /// No description provided for @errorStockOverlap.
  ///
  /// In en, this message translates to:
  /// **'This ticket range overlaps with an existing batch in your stock.'**
  String get errorStockOverlap;

  /// No description provided for @errorStockOverlapDetail.
  ///
  /// In en, this message translates to:
  /// **'Overlaps with existing stock: {detail}'**
  String errorStockOverlapDetail(String detail);

  /// No description provided for @errorBatchInUse.
  ///
  /// In en, this message translates to:
  /// **'Cannot delete this batch because some tickets have already been issued or sold.'**
  String get errorBatchInUse;

  /// No description provided for @errorDrawNotOpen.
  ///
  /// In en, this message translates to:
  /// **'Stock can only be added while the draw is Upcoming.'**
  String get errorDrawNotOpen;

  /// No description provided for @errorDrawExists.
  ///
  /// In en, this message translates to:
  /// **'A draw for this lottery on this date already exists.'**
  String get errorDrawExists;

  /// No description provided for @errorNotFound.
  ///
  /// In en, this message translates to:
  /// **'The requested item was not found in your shop.'**
  String get errorNotFound;

  /// No description provided for @errorInvalidRange.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid series and 6-digit range (max 5,000 tickets, end ≥ start).'**
  String get errorInvalidRange;

  /// No description provided for @errorUnauthorized.
  ///
  /// In en, this message translates to:
  /// **'Please sign in again to continue.'**
  String get errorUnauthorized;

  /// No description provided for @errorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get errorGeneric;

  /// No description provided for @ticketRetentionNote.
  ///
  /// In en, this message translates to:
  /// **'Ticket-level detail is kept for 30 days after a draw closes'**
  String get ticketRetentionNote;
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
      <String>['en', 'ml', 'ta'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ml':
      return AppLocalizationsMl();
    case 'ta':
      return AppLocalizationsTa();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
