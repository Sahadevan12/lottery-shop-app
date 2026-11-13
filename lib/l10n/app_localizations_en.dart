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
  String get verifyOfficialResultNote =>
      'Verify with official Kerala State Lotteries result before paying out.';

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

  @override
  String get errorTicketsNotAvailable =>
      'Some selected tickets are no longer available in stock. Refreshing list…';

  @override
  String get errorTicketsNotWithSeller =>
      'Some selected tickets are not currently with this seller. Refreshing list…';

  @override
  String get errorInvalidAmount =>
      'Enter a valid amount between ₹1 and ₹10,00,000.';

  @override
  String get errorNotReversible =>
      'Only payment, prize-paid, and adjustment entries can be reversed.';

  @override
  String get errorAlreadyReversed => 'This entry has already been reversed.';

  @override
  String get errorLedgerImmutable =>
      'Ledger entries cannot be edited or deleted directly. Use Reverse instead.';

  @override
  String get errorPriceLocked =>
      'Ticket price cannot be changed after ledger entries exist for this draw.';

  @override
  String get errorSellerInactive =>
      'Cannot issue tickets to an inactive seller.';

  @override
  String get sellersScreenTitle => 'Sellers & Khata';

  @override
  String get sellersSearchHint => 'Search seller name or area';

  @override
  String get sortHighestDue => 'Highest due';

  @override
  String get sortName => 'Name';

  @override
  String get sortRecent => 'Recent';

  @override
  String get filterInactive => 'Inactive';

  @override
  String get sellerInactiveBadge => 'Inactive';

  @override
  String get sellerSettledLabel => 'Settled';

  @override
  String get sellerAdvanceLabel => 'Advance credit';

  @override
  String ticketsWithSellerCount(String count) {
    return '$count with seller';
  }

  @override
  String get addSellerAction => 'Add seller';

  @override
  String get editSellerTitle => 'Edit seller';

  @override
  String get sellerNameLabel => 'Seller name';

  @override
  String get sellerNameHint => 'e.g. Rajan';

  @override
  String get sellerNameRequiredError => 'Please enter the seller\'s name';

  @override
  String get sellerAreaLabel => 'Area / route (optional)';

  @override
  String get sellerAreaHint => 'e.g. Aluva Market';

  @override
  String get sellerSavedSuccess => 'Seller saved';

  @override
  String get deactivateSellerAction => 'Deactivate seller';

  @override
  String get reactivateSellerAction => 'Reactivate seller';

  @override
  String get deactivateSellerTitle => 'Deactivate this seller?';

  @override
  String get deactivateSellerBody =>
      'Inactive sellers are hidden from ticket issue pickers, while their khata history stays intact.';

  @override
  String get sellerDeactivatedSuccess => 'Seller deactivated';

  @override
  String get sellerReactivatedSuccess => 'Seller reactivated';

  @override
  String get deleteSellerTitle => 'Delete this seller?';

  @override
  String get deleteSellerBody =>
      'This seller has no ledger history and will be removed permanently.';

  @override
  String get sellerDeletedSuccess => 'Seller deleted';

  @override
  String get sellerBalanceDueLabel => 'Balance due (tap for breakdown)';

  @override
  String get giveTicketsShortAction => 'Give tickets';

  @override
  String get takeReturnAction => 'Take return';

  @override
  String get recordPaymentShortAction => 'Record payment';

  @override
  String get sellerTabLedger => 'Ledger';

  @override
  String get sellerTabTickets => 'Tickets';

  @override
  String get sellerTabWins => 'Wins';

  @override
  String get ledgerEmptyTitle => 'No khata entries yet';

  @override
  String get ledgerEmptyBody =>
      'Issue tickets or record a payment to start this seller\'s khata.';

  @override
  String get sellerTicketsEmptyTitle => 'No tickets with this seller';

  @override
  String get sellerTicketsEmptyBody =>
      'Use \'Give tickets\' to issue tickets on credit.';

  @override
  String get sellerWinsEmptyTitle => 'No winning tickets yet';

  @override
  String get sellerWinsEmptyBody =>
      'Winning tickets sold by this seller will appear here after draw results are checked.';

  @override
  String get ledgerTypeIssue => 'Tickets issued';

  @override
  String get ledgerTypeReturn => 'Unsold returned';

  @override
  String get ledgerTypePayment => 'Payment received';

  @override
  String get ledgerTypePrizePaid => 'Prize paid by seller';

  @override
  String get ledgerTypeAdjustment => 'Reversal adjustment';

  @override
  String get paymentMethodCash => 'Cash';

  @override
  String get paymentMethodUpi => 'UPI';

  @override
  String get paymentMethodOther => 'Other';

  @override
  String get reversedChipLabel => 'Reversed';

  @override
  String get reversalOfLabel => 'Reverses earlier entry';

  @override
  String get reverseEntryAction => 'Reverse entry';

  @override
  String get reverseEntryTitle => 'Reverse this khata entry?';

  @override
  String get reverseEntryBody =>
      'This adds a matching adjustment entry to cancel out the amount. Ledger history remains auditable.';

  @override
  String get entryReversedSuccess => 'Entry reversed';

  @override
  String get giveTicketsSheetTitle => 'Give tickets to seller';

  @override
  String get selectSellerLabel => 'Seller';

  @override
  String get issueModeByCount => 'By count';

  @override
  String get issueModeByRange => 'By range';

  @override
  String get ticketCountToGiveLabel => 'Number of tickets to give';

  @override
  String get ticketCountToGiveHint => 'e.g. 50';

  @override
  String get nextTicketsPreviewLabel => 'Auto-selected next IN_STOCK tickets:';

  @override
  String get notEnoughStockError => 'Not enough IN_STOCK tickets in this draw';

  @override
  String get issueTotalAmountLabel => 'Khata debit amount';

  @override
  String get confirmGiveTicketsAction => 'Confirm & issue tickets';

  @override
  String ticketsIssuedSuccess(String count) {
    return 'Issued $count tickets';
  }

  @override
  String get returnTicketsSheetTitle => 'Take unsold return';

  @override
  String get returnModeByRange => 'By range';

  @override
  String get returnModeBySelect => 'Tap to select';

  @override
  String get returnTotalCreditLabel => 'Khata credit amount';

  @override
  String get confirmReturnTicketsAction => 'Confirm return';

  @override
  String ticketsReturnedSuccess(String count) {
    return 'Returned $count tickets';
  }

  @override
  String get recordPaymentSheetTitle => 'Record payment / prize paid';

  @override
  String get entryKindPayment => 'Payment collected';

  @override
  String get entryKindPrizePaid => 'Prize paid by seller';

  @override
  String get amountRupeesLabel => 'Amount (₹)';

  @override
  String get amountRupeesHint => 'e.g. 1500';

  @override
  String get paymentMethodLabel => 'Payment method';

  @override
  String get noteOptionalLabel => 'Note (optional)';

  @override
  String get noteOptionalHint => 'e.g. Morning collection';

  @override
  String get advanceWarningTitle => 'Exceeds current balance due';

  @override
  String advanceWarningBody(String advance) {
    return 'This payment is higher than what the seller currently owes and will record an advance credit of $advance.';
  }

  @override
  String get confirmAdvanceAction => 'Record with advance';

  @override
  String paymentRecordedSuccess(String amount) {
    return 'Recorded $amount';
  }

  @override
  String get balanceBreakdownTitle => 'How this balance is calculated';

  @override
  String get breakdownPerDrawSection => 'By draw';

  @override
  String get breakdownPaymentsSection => 'Payments & adjustments';

  @override
  String breakdownIssuedRow(String count) {
    return 'Issued ($count tickets)';
  }

  @override
  String breakdownReturnedRow(String count) {
    return 'Returned ($count tickets)';
  }

  @override
  String get breakdownPrizePaidRow => 'Prizes paid by seller';

  @override
  String get breakdownDrawSubtotal => 'Draw subtotal';

  @override
  String get breakdownPaymentsTotal => 'Total payments received';

  @override
  String get breakdownAdjustmentsTotal => 'Reversals & adjustments';

  @override
  String get breakdownGrandTotal => 'Net balance due';

  @override
  String get shareStatementAction => 'Share statement';

  @override
  String get sellerStatementTitle => 'Seller Khata Statement';

  @override
  String get counterSaleAction => 'Counter sale range';

  @override
  String get counterSaleSheetTitle => 'Counter sales (by range)';

  @override
  String get counterSaleModeMark => 'Mark as counter sold';

  @override
  String get counterSaleModeUnmark => 'Unmark to in-stock';

  @override
  String get confirmCounterSaleAction => 'Update counter sales';

  @override
  String counterSaleUpdatedSuccess(String count) {
    return 'Updated $count tickets';
  }

  @override
  String get enterResultsTitle => 'Enter draw results';

  @override
  String get editResultsTitle => 'Edit draw results';

  @override
  String resultsDrawTimeNote(String time) {
    return 'Results can be entered after $time IST on draw date.';
  }

  @override
  String get autoConsolationNote =>
      'Consolation prizes are auto-matched from the 1st prize number across all other series.';

  @override
  String get addWinningNumberAction => 'Add number';

  @override
  String get fullTicketHint => 'e.g. KR 482910';

  @override
  String get last4DigitsHint => '4 digits (e.g. 2910)';

  @override
  String get last3DigitsHint => '3 digits (e.g. 910)';

  @override
  String get invalidFullTicketError =>
      'Enter series + 6 digits (e.g. KR 482910)';

  @override
  String get invalidLast4Error => 'Enter exactly 4 digits';

  @override
  String get invalidLast3Error => 'Enter exactly 3 digits';

  @override
  String get duplicateEntryError => 'Duplicate winning number in this tier';

  @override
  String get saveAndCheckResultsAction => 'Save & check winners';

  @override
  String resultsSavedSuccess(String count) {
    return 'Results saved! Found $count winning tickets';
  }

  @override
  String get claimedWinAffectedTitle => 'Claimed wins will be affected';

  @override
  String claimedWinAffectedBody(String tickets) {
    return 'Updating these results will remove or change prizes for already claimed tickets: $tickets. Proceed anyway?';
  }

  @override
  String get forceUpdateResultsAction => 'Update anyway';

  @override
  String winnersFoundHeadline(String count) {
    return '$count winning tickets found!';
  }

  @override
  String get noWinnersFoundTitle => 'No winning tickets in your stock';

  @override
  String get noWinnersFoundSubtitle =>
      'None of your tickets for this draw matched the entered results.';

  @override
  String get resultsNotEnteredTitle => 'Results not entered yet';

  @override
  String get resultsNotEnteredSubtitle =>
      'Enter the official draw results after 3 PM to match all winning tickets in your stock.';

  @override
  String get totalPrizeWonLabel => 'Total prize won';

  @override
  String get soldByCounterBadge => 'Counter sale';

  @override
  String soldBySellerBadge(String name) {
    return 'Sold by $name';
  }

  @override
  String get soldByUnsoldBadge => 'Unsold';

  @override
  String get claimStatusUnclaimed => 'Unclaimed';

  @override
  String get claimStatusPaidToCustomer => 'Paid to customer';

  @override
  String get claimStatusClaimedFromOffice => 'Claimed from office';

  @override
  String get claimStatusUnsoldWin => 'Unsold win';

  @override
  String get claimStatusUpdatedSuccess => 'Claim status updated';

  @override
  String get shareWinnerPosterAction => 'Share winner poster';

  @override
  String get winnerPosterTitle => 'Winning Tickets';

  @override
  String get winnerPosterVerifyNote => 'Verify with official result';

  @override
  String get winnerPosterFooter => 'Generated by LuckyLedger';

  @override
  String get closeDrawAction => 'Close draw';

  @override
  String get closeDrawConfirmTitle => 'Close this draw?';

  @override
  String closeDrawConfirmBody(String count) {
    return '$count tickets still with sellers will become Sold by Seller. Results and stock for this draw will be locked.';
  }

  @override
  String get closeDrawConfirmZeroBody =>
      'Results and stock for this draw will be locked. You cannot edit them afterwards.';

  @override
  String get drawClosedSuccess => 'Draw closed and summary saved';

  @override
  String get drawSummaryLabel => 'Draw summary';

  @override
  String get sellerWinsEmptySubtitle =>
      'Winning tickets sold by this seller will appear here after draw results are entered.';

  @override
  String get errorDrawBeforeTime =>
      'Results cannot be saved before the draw time on draw date.';

  @override
  String get errorDrawClosed => 'This draw is already closed.';

  @override
  String get errorInvalidResultEntry =>
      'Please check the winning number format.';

  @override
  String get errorDuplicateResultEntry =>
      'Duplicate winning number in the same prize tier.';

  @override
  String get errorClaimedWinAffected =>
      'A claimed winning ticket would be affected by this change.';

  @override
  String get errorInvalidClaimStatus => 'Invalid claim status for this ticket.';
}
