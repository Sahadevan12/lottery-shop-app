import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/ui_kit.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/presentation/auth_controller.dart';
import '../domain/app_preferences.dart';
import 'app_preferences_controller.dart';

/// More & Settings Screen — Tab 5 (§2, §8.7).
/// Includes language switch, theme override, large text (1.15×) toggle,
/// link to `/design-preview`, legal disclaimer, and sign out.
class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppColors colors = context.colors;
    final AppPreferences prefs = ref.watch(appPreferencesProvider);
    final AppPreferencesController controller =
        ref.read(appPreferencesProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.moreTitle),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenHorizontal,
          AppSpacing.md,
          AppSpacing.screenHorizontal,
          AppSpacing.xxl,
        ),
        children: <Widget>[
          SectionHeader(title: l10n.settingsSectionTitle),
          const SizedBox(height: AppSpacing.sm),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  l10n.languageSettingLabel,
                  style: context.text.label.copyWith(color: colors.inkMuted),
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: <Widget>[
                    AppChip(
                      label: l10n.languageMalayalam,
                      selected: prefs.locale.languageCode == 'ml',
                      onTap: () => controller.setLocale(const Locale('ml')),
                    ),
                    AppChip(
                      label: l10n.languageTamil,
                      selected: prefs.locale.languageCode == 'ta',
                      onTap: () => controller.setLocale(const Locale('ta')),
                    ),
                    AppChip(
                      label: l10n.languageEnglish,
                      selected: prefs.locale.languageCode == 'en',
                      onTap: () => controller.setLocale(const Locale('en')),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                Divider(color: colors.border),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  l10n.themeSettingLabel,
                  style: context.text.label.copyWith(color: colors.inkMuted),
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: <Widget>[
                    AppChip(
                      label: l10n.themeSystem,
                      selected: prefs.themeMode == ThemeMode.system,
                      onTap: () => controller.setThemeMode(ThemeMode.system),
                    ),
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
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                Divider(color: colors.border),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            l10n.largeTextSettingLabel,
                            style: context.text.bodyMedium,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            l10n.largeTextSettingSubtitle,
                            style: context.text.caption.copyWith(
                              color: colors.inkMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch.adaptive(
                      value: prefs.largeText,
                      activeTrackColor: colors.primary,
                      onChanged: controller.setLargeText,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppCard(
            onTap: () => context.push('/lotteries-templates'),
            child: Row(
              children: <Widget>[
                Icon(Icons.confirmation_number_outlined, color: colors.primary),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        l10n.lotteriesTemplatesTitle,
                        style: context.text.bodyMedium,
                      ),
                      Text(
                        l10n.lotteriesTemplatesSubtitle,
                        style: context.text.caption.copyWith(
                          color: colors.inkMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: colors.inkMuted),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AppCard(
            onTap: () => context.push('/design-preview'),
            child: Row(
              children: <Widget>[
                Icon(Icons.palette_outlined, color: colors.primary),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        l10n.designPreviewTitle,
                        style: context.text.bodyMedium,
                      ),
                      Text(
                        l10n.designPreviewSubtitle,
                        style: context.text.caption.copyWith(
                          color: colors.inkMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: colors.inkMuted),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          SectionHeader(title: l10n.aboutSectionTitle),
          const SizedBox(height: AppSpacing.sm),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Icon(
                      Icons.verified_user_outlined,
                      size: 20,
                      color: colors.primary,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      l10n.appName,
                      style: context.text.bodyMedium,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  l10n.legalDisclaimer,
                  style: context.text.caption.copyWith(color: colors.inkMuted),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          AppButton(
            label: l10n.logoutAction,
            variant: AppButtonVariant.danger,
            leadingIcon: Icons.logout_rounded,
            onPressed: () async {
              final bool confirmed = await ConfirmDialog.show(
                context: context,
                title: l10n.logoutConfirmTitle,
                message: l10n.logoutConfirmBody,
                cancelLabel: l10n.cancelAction,
                confirmLabel: l10n.logoutAction,
              );
              if (confirmed) {
                await ref.read(authControllerProvider.notifier).signOut();
              }
            },
          ),
        ],
      ),
    );
  }
}
