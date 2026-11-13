import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/ui_kit.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/app_preferences.dart';
import 'app_preferences_controller.dart';

/// Interactive Design System Preview Screen (`/design-preview`, §4, §10 Phase 1).
/// Shows every token and reusable component in Light/Dark, ml/ta/en, and 1.0×/1.15× text.
class DesignPreviewScreen extends ConsumerStatefulWidget {
  const DesignPreviewScreen({super.key});

  @override
  ConsumerState<DesignPreviewScreen> createState() =>
      _DesignPreviewScreenState();
}

class _DesignPreviewScreenState extends ConsumerState<DesignPreviewScreen> {
  String _selectedFilter = 'Today';
  int _counterDemo = 123450;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppColors colors = context.colors;
    final AppPreferences prefs = ref.watch(appPreferencesProvider);
    final AppPreferencesController controller =
        ref.read(appPreferencesProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.designPreviewTitle),
        actions: <Widget>[
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.screenHorizontal),
            child: SyncStatusPill(
              status: SyncStatus.synced,
              label: l10n.syncStatusSynced,
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenHorizontal,
          AppSpacing.md,
          AppSpacing.screenHorizontal,
          AppSpacing.xxl,
        ),
        children: <Widget>[
          // Live Controls Bar
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Live Preview Controls', style: context.text.h2),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: <Widget>[
                    AppChip(
                      label: l10n.themeLight,
                      selected: prefs.themeMode == ThemeMode.light,
                      onTap: () => controller.setThemeMode(ThemeMode.light),
                    ),
                    AppChip(
                      label: l10n.themeDark,
                      selected: prefs.themeMode == ThemeMode.dark,
                      onTap: () => controller.setThemeMode(ThemeMode.dark),
                    ),
                    AppChip(
                      label: '1.15× Large Text',
                      selected: prefs.largeText,
                      onTap: () => controller.setLargeText(!prefs.largeText),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: <Widget>[
                    AppChip(
                      label: 'മലയാളം',
                      selected: prefs.locale.languageCode == 'ml',
                      onTap: () => controller.setLocale(const Locale('ml')),
                    ),
                    AppChip(
                      label: 'தமிழ்',
                      selected: prefs.locale.languageCode == 'ta',
                      onTap: () => controller.setLocale(const Locale('ta')),
                    ),
                    AppChip(
                      label: 'English',
                      selected: prefs.locale.languageCode == 'en',
                      onTap: () => controller.setLocale(const Locale('en')),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          // 1. Typography & MoneyText & TicketNumberText
          const SectionHeader(title: 'Typography, Money & Tickets'),
          const SizedBox(height: AppSpacing.sm),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Display ₹1,23,450', style: context.text.display),
                const SizedBox(height: AppSpacing.xs),
                Text('H1 Screen Title', style: context.text.h1),
                const SizedBox(height: AppSpacing.xs),
                Text('H2 Section Header', style: context.text.h2),
                const SizedBox(height: AppSpacing.xs),
                Text('Body 16sp regular text', style: context.text.body),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Caption 13sp muted meta info',
                  style: context.text.caption.copyWith(color: colors.inkMuted),
                ),
                const SizedBox(height: AppSpacing.md),
                Divider(color: colors.border),
                const SizedBox(height: AppSpacing.md),
                const Wrap(
                  spacing: AppSpacing.lg,
                  runSpacing: AppSpacing.sm,
                  children: <Widget>[
                    MoneyText.fromRupees(
                      rupees: 12450,
                      tone: MoneyTone.balanceDue,
                    ),
                    MoneyText.fromRupees(
                      rupees: 0,
                      tone: MoneyTone.settled,
                    ),
                    MoneyText.fromRupees(
                      rupees: 7500000,
                      tone: MoneyTone.prizeGold,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                const TicketNumberText(series: 'KR', number: '482913'),
                const SizedBox(height: AppSpacing.xs),
                const TicketNumberText(
                  series: 'KR',
                  number: '482913',
                  matchedSuffixDigits: 4,
                ),
                const SizedBox(height: AppSpacing.xs),
                const TicketNumberText(
                  series: 'WN',
                  number: '109482',
                  highlightFullTicket: true,
                  large: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          // 2. StatTile & Win Card
          SectionHeader(
            title: 'StatTiles & Win Highlight',
            actionLabel: '+₹5,000',
            onAction: () => setState(() => _counterDemo += 5000),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: <Widget>[
              Expanded(
                child: StatTile(
                  label: l10n.statInStock,
                  numericValue: 450,
                  deltaText: '5 books',
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: StatTile(
                  label: l10n.statDueFromSellers,
                  numericValue: _counterDemo,
                  isCurrency: true,
                  valueColor: colors.danger,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          AppCard(
            isWinHighlight: true,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                const TicketNumberText(
                  series: 'KR',
                  number: '482913',
                  matchedSuffixDigits: 4,
                ),
                MoneyText.fromRupees(
                  rupees: 5000,
                  tone: MoneyTone.prizeGold,
                  style: context.text.h2,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          // 3. Buttons
          const SectionHeader(title: 'Buttons (§4.5)'),
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: 'Primary Action (56dp)',
            leadingIcon: Icons.check_circle_outline,
            onPressed: () {
              AppSnackbar.show(
                context,
                message: 'Payment recorded (₹2,000)',
                undoLabel: l10n.undoAction,
                onUndo: () {},
              );
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: <Widget>[
              Expanded(
                child: AppButton(
                  label: 'Secondary Sheet',
                  variant: AppButtonVariant.secondary,
                  onPressed: () {
                    AppBottomSheet.show<void>(
                      context: context,
                      title: 'Sample Bottom Sheet',
                      subtitle: '28dp top radius + drag handle',
                      child: AppButton(
                        label: l10n.confirmAction,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: AppButton(
                  label: 'Danger Dialog',
                  variant: AppButtonVariant.danger,
                  onPressed: () {
                    ConfirmDialog.show(
                      context: context,
                      title: 'Delete Entry?',
                      message: 'This action cannot be undone.',
                      cancelLabel: l10n.cancelAction,
                      confirmLabel: l10n.confirmAction,
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          const Row(
            children: <Widget>[
              Expanded(
                child: AppButton(
                  label: 'Loading',
                  isLoading: true,
                  onPressed: null,
                ),
              ),
              SizedBox(width: AppSpacing.sm),
              Expanded(
                child: AppButton(
                  label: 'Disabled',
                  onPressed: null,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),

          // 4. Inputs, Chips & Seller Avatars
          const SectionHeader(title: 'Inputs, Chips & Avatars'),
          const SizedBox(height: AppSpacing.sm),
          FilterChipRow<String>(
            padding: EdgeInsets.zero,
            items: const <String>['Today', 'Tomorrow', 'Upcoming', 'Bumper'],
            selectedItem: _selectedFilter,
            labelBuilder: (String item) => item,
            onSelected: (String item) => setState(() => _selectedFilter = item),
          ),
          const SizedBox(height: AppSpacing.md),
          const AppTextField(
            label: 'Ticket Series & Number',
            hintText: 'KR 482900',
            helperText: 'Static label above field, 14dp radius',
            useMonoFont: true,
          ),
          const SizedBox(height: AppSpacing.md),
          const Wrap(
            spacing: AppSpacing.md,
            children: <Widget>[
              SellerAvatar(name: 'Ramesh Nair'),
              SellerAvatar(name: 'Abdul Salam'),
              SellerAvatar(name: 'Suresh Kumar'),
              SellerAvatar(name: 'Babu K'),
              SellerAvatar(name: 'Manikandan P'),
              SellerAvatar(name: 'Varghese T'),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),

          // 5. Skeleton & Empty State
          const SectionHeader(title: 'Skeleton & Empty State'),
          const SizedBox(height: AppSpacing.sm),
          const SkeletonLoader(height: 64),
          const SizedBox(height: AppSpacing.md),
          AppCard(
            child: EmptyState(
              title: l10n.stockEmptyTitle,
              message: l10n.stockEmptyBody,
              actionLabel: l10n.stockEmptyCta,
              onAction: () {},
            ),
          ),
        ],
      ),
    );
  }
}
