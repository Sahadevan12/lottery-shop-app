// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'LuckyLedger';

  @override
  String get chooseLanguageTitle => 'Choose your language';

  @override
  String get chooseLanguageSubtitle =>
      'You can change this anytime in Settings';

  @override
  String get languageMalayalam => 'മലയാളം';

  @override
  String get languageMalayalamSub => 'Malayalam';

  @override
  String get languageTamil => 'தமிழ்';

  @override
  String get languageTamilSub => 'Tamil';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageEnglishSub => 'English';

  @override
  String get continueAction => 'Continue';

  @override
  String get getStartedAction => 'Get started';

  @override
  String get nextAction => 'Next';

  @override
  String get skipAction => 'Skip';

  @override
  String get cancelAction => 'Cancel';

  @override
  String get confirmAction => 'Confirm';

  @override
  String get saveAction => 'Save';

  @override
  String get deleteAction => 'Delete';

  @override
  String get retryAction => 'Retry';

  @override
  String get undoAction => 'Undo';

  @override
  String get seeAllAction => 'See all';

  @override
  String get searchHint => 'Search...';

  @override
  String get welcomeSlide1Title => 'Track your ticket stock';

  @override
  String get welcomeSlide1Body =>
      'Add ticket books in seconds and see what is in stock, with sellers, or sold.';

  @override
  String get welcomeSlide2Title => 'Manage your sellers\' khata';

  @override
  String get welcomeSlide2Body =>
      'Issue tickets on credit, record returns and payments, and always know the exact balance due.';

  @override
  String get welcomeSlide3Title => 'Find winners in 10 seconds';

  @override
  String get welcomeSlide3Body =>
      'Enter the 3 PM draw result once to spot every winning ticket and who sold it.';

  @override
  String get legalDisclaimer =>
      'This app is an independent business tool for lottery retailers. It is not affiliated with the Kerala State Lotteries Department or any government body. It does not sell lottery tickets. Always verify results with the official Kerala State Lotteries website.';

  @override
  String get verifyOfficialResultNote => 'Verify with official result';

  @override
  String get loginTitle => 'Sign in to your shop';

  @override
  String get loginSubtitle =>
      'Enter your 10-digit mobile number and 6-digit PIN';

  @override
  String get phoneLabel => 'Mobile number';

  @override
  String get phoneHint => '98765 43210';

  @override
  String get phonePrefix => '+91';

  @override
  String get pinLabel => '6-digit PIN';

  @override
  String get signInAction => 'Sign in / Continue';

  @override
  String get forgotPinAction => 'Forgot PIN?';

  @override
  String get forgotPinDialogTitle => 'Reset your PIN';

  @override
  String get forgotPinDialogBody =>
      'Please contact LuckyLedger Retailer Support with your registered mobile number and shop agent code to reset your PIN.';

  @override
  String get contactSupportClose => 'Got it';

  @override
  String get invalidPhoneError => 'Enter a valid 10-digit mobile number';

  @override
  String get invalidPinError => 'Enter a 6-digit numeric PIN';

  @override
  String get shopSetupTitle => 'Set up your shop';

  @override
  String get shopSetupSubtitle =>
      'We will create default weekly lotteries and prize templates for your shop.';

  @override
  String get shopNameLabel => 'Shop name';

  @override
  String get shopNameHint => 'e.g. Sri Lakshmi Agencies';

  @override
  String get ownerNameLabel => 'Owner name';

  @override
  String get ownerNameHint => 'e.g. Ramesh Nair';

  @override
  String get districtLabel => 'District';

  @override
  String get districtHint => 'Select district';

  @override
  String get agentCodeLabel => 'Lottery agent / retailer code (optional)';

  @override
  String get agentCodeHint => 'e.g. EKM-4821';

  @override
  String get shopNameRequiredError => 'Please enter your shop name';

  @override
  String get ownerNameRequiredError => 'Please enter the owner name';

  @override
  String get districtRequiredError => 'Please select a district';

  @override
  String get completeSetupAction => 'Create shop & start';

  @override
  String get districtThiruvananthapuram => 'Thiruvananthapuram';

  @override
  String get districtKollam => 'Kollam';

  @override
  String get districtPathanamthitta => 'Pathanamthitta';

  @override
  String get districtAlappuzha => 'Alappuzha';

  @override
  String get districtKottayam => 'Kottayam';

  @override
  String get districtIdukki => 'Idukki';

  @override
  String get districtErnakulam => 'Ernakulam';

  @override
  String get districtThrissur => 'Thrissur';

  @override
  String get districtPalakkad => 'Palakkad';

  @override
  String get districtMalappuram => 'Malappuram';

  @override
  String get districtKozhikode => 'Kozhikode';

  @override
  String get districtWayanad => 'Wayanad';

  @override
  String get districtKannur => 'Kannur';

  @override
  String get districtKasaragod => 'Kasaragod';

  @override
  String get navHome => 'Home';

  @override
  String get navStock => 'Stock';

  @override
  String get navSellers => 'Sellers';

  @override
  String get navResults => 'Results';

  @override
  String get navMore => 'More';

  @override
  String greetingMorning(String name) {
    return 'Good morning, $name';
  }

  @override
  String greetingAfternoon(String name) {
    return 'Good afternoon, $name';
  }

  @override
  String greetingEvening(String name) {
    return 'Good evening, $name';
  }

  @override
  String get syncStatusSynced => 'Synced ✓';

  @override
  String get syncStatusSyncing => 'Syncing…';

  @override
  String get syncStatusOffline => 'Offline';

  @override
  String get statTotalTickets => 'Total tickets';

  @override
  String get statInStock => 'In stock';

  @override
  String get statWithSellers => 'With sellers';

  @override
  String get statSoldToday => 'Sold today';

  @override
  String get statSold => 'Sold';

  @override
  String get statReturned => 'Returned';

  @override
  String get statDueFromSellers => 'Due from sellers';

  @override
  String get homeEmptyTitle => 'Your shop is ready';

  @override
  String get homeEmptyBody =>
      'Add today\'s ticket stock to start tracking sales, sellers, and winning numbers.';

  @override
  String get homeEmptyCta => 'Go to Stock';

  @override
  String get stockEmptyTitle => 'No ticket stock yet';

  @override
  String get stockEmptyBody =>
      'Add your first ticket book range for this draw.';

  @override
  String get stockEmptyCta => 'Add stock';

  @override
  String get createTodayDrawTitle => 'Create today\'s draw';

  @override
  String createTodayDrawBody(String lotteryName) {
    return 'Set up today\'s $lotteryName draw to start adding ticket ranges.';
  }

  @override
  String get createDrawTitle => 'Create draw';

  @override
  String get newDrawChip => '+ New draw';

  @override
  String get drawSelectorToday => 'Today';

  @override
  String get drawSelectorTomorrow => 'Tomorrow';

  @override
  String get drawSelectorBumper => 'Bumper';

  @override
  String get lotteryFieldLabel => 'Lottery';

  @override
  String get drawDateFieldLabel => 'Draw date';

  @override
  String get drawNumberFieldLabel => 'Draw number (e.g. W-845)';

  @override
  String get ticketPriceFieldLabel => 'Selling price per ticket (₹)';

  @override
  String get prizeTemplateFieldLabel => 'Prize structure template';

  @override
  String get addStockTitle => 'Add ticket stock';

  @override
  String get seriesFieldLabel => 'Series (1–3 letters)';

  @override
  String get seriesFieldHint => 'KR';

  @override
  String get startNumberFieldLabel => 'From number (6 digits)';

  @override
  String get startNumberFieldHint => '482900';

  @override
  String get endNumberFieldLabel => 'To number (6 digits)';

  @override
  String get endNumberFieldHint => '482999';

  @override
  String get costPerTicketFieldLabel => 'Purchase cost per ticket (₹)';

  @override
  String get costPerTicketFieldHint => '35';

  @override
  String get addAnotherRangeLabel => 'Add another range after saving';

  @override
  String get quantityLabel => 'Quantity';

  @override
  String get totalCostLabel => 'Total cost';

  @override
  String ticketsCountLabel(String count) {
    return '$count tickets';
  }

  @override
  String batchAddedSuccess(String count, String range) {
    return 'Added $count tickets ($range)';
  }

  @override
  String get deleteBatchTitle => 'Delete this ticket batch?';

  @override
  String deleteBatchBody(String range, String count) {
    return 'This will remove $range ($count tickets) from your stock.';
  }

  @override
  String get batchDeletedSuccess => 'Batch deleted';

  @override
  String get batchDetailTitle => 'Batch tickets';

  @override
  String get filterAll => 'All';

  @override
  String get statusInStock => 'In stock';

  @override
  String get statusWithSeller => 'With seller';

  @override
  String get statusSold => 'Sold';

  @override
  String get statusReturned => 'Returned';

  @override
  String get lotteriesTemplatesTitle => 'Lotteries & Prize Templates';

  @override
  String get lotteriesTemplatesSubtitle =>
      'Edit weekly lotteries, bumper draws, and prize tiers';

  @override
  String get lotteriesTab => 'Lotteries';

  @override
  String get prizeTemplatesTab => 'Prize Templates';

  @override
  String get addLotteryAction => 'Add lottery';

  @override
  String get editLotteryTitle => 'Edit lottery';

  @override
  String get lotteryNameLabel => 'Lottery name';

  @override
  String get lotteryCodeLabel => 'Short code (e.g. W, KR)';

  @override
  String get isBumperLabel => 'Bumper lottery';

  @override
  String get sellersEmptyTitle => 'No sellers added yet';

  @override
  String get sellersEmptyBody =>
      'Add walking sellers to track issued tickets and khata balances.';

  @override
  String get sellersEmptyCta => 'Add seller';

  @override
  String get resultsEmptyTitle => 'No draw results yet';

  @override
  String get resultsEmptyBody =>
      'Enter the 3:00 PM draw results to check all your tickets in seconds.';

  @override
  String get resultsEmptyCta => 'Enter result';

  @override
  String get moreTitle => 'More & Settings';

  @override
  String get settingsSectionTitle => 'Settings';

  @override
  String get languageSettingLabel => 'Language';

  @override
  String get themeSettingLabel => 'Appearance';

  @override
  String get themeSystem => 'System default';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get largeTextSettingLabel => 'Large text (1.15×)';

  @override
  String get largeTextSettingSubtitle => 'Easier reading in bright light';

  @override
  String get designPreviewTitle => 'Design System Preview';

  @override
  String get designPreviewSubtitle =>
      'Interactive token & component showcase (§4)';

  @override
  String get aboutSectionTitle => 'About & Legal';

  @override
  String get logoutAction => 'Sign out';

  @override
  String get logoutConfirmTitle => 'Sign out of LuckyLedger?';

  @override
  String get logoutConfirmBody =>
      'Make sure any pending entries are synced before signing out.';

  @override
  String get errorStockOverlap =>
      'This ticket range overlaps with an existing batch in your stock.';

  @override
  String errorStockOverlapDetail(String detail) {
    return 'Overlaps with existing stock: $detail';
  }

  @override
  String get errorBatchInUse =>
      'Cannot delete this batch because some tickets have already been issued or sold.';

  @override
  String get errorDrawNotOpen =>
      'Stock can only be added while the draw is Upcoming.';

  @override
  String get errorDrawExists =>
      'A draw for this lottery on this date already exists.';

  @override
  String get errorNotFound => 'The requested item was not found in your shop.';

  @override
  String get errorInvalidRange =>
      'Enter a valid series and 6-digit range (max 5,000 tickets, end ≥ start).';

  @override
  String get errorUnauthorized => 'Please sign in again to continue.';

  @override
  String get errorGeneric => 'Something went wrong. Please try again.';

  @override
  String get ticketRetentionNote =>
      'Ticket-level detail is kept for 30 days after a draw closes';
}
