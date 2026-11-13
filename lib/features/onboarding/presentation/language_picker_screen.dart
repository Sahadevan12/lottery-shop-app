import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/ui_kit.dart';
import '../../../l10n/app_localizations.dart';
import '../../settings/domain/app_preferences.dart';
import '../../settings/presentation/app_preferences_controller.dart';

/// Onboarding Step 1 — Language Picker Screen (§8.1 #1).
/// Three large cards: മലയാളം / தமிழ் / English. Shown first, before anything else.
class LanguagePickerScreen extends ConsumerWidget {
  const LanguagePickerScreen({
    super.key,
    required this.onCompleted,
  });

  final VoidCallback onCompleted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppColors colors = context.colors;
    final AppPreferences prefs = ref.watch(appPreferencesProvider);
    final AppPreferencesController controller =
        ref.read(appPreferencesProvider.notifier);

    final List<({String code, String primary, String secondary})> languages =
        <({String code, String primary, String secondary})>[
      (
        code: 'ml',
        primary: l10n.languageMalayalam,
        secondary: l10n.languageMalayalamSub,
      ),
      (
        code: 'ta',
        primary: l10n.languageTamil,
        secondary: l10n.languageTamilSub,
      ),
      (
        code: 'en',
        primary: l10n.languageEnglish,
        secondary: l10n.languageEnglishSub,
      ),
    ];

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenHorizontal,
            AppSpacing.xxl,
            AppSpacing.screenHorizontal,
            AppSpacing.xl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                l10n.appName,
                style: context.text.label.copyWith(
                  color: colors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                l10n.chooseLanguageTitle,
                style: context.text.h1,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                l10n.chooseLanguageSubtitle,
                style: context.text.body.copyWith(color: colors.inkMuted),
              ),
              const SizedBox(height: AppSpacing.xl),
              Expanded(
                child: ListView.separated(
                  itemCount: languages.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.md),
                  itemBuilder: (BuildContext context, int index) {
                    final item = languages[index];
                    final bool isSelected =
                        prefs.locale.languageCode == item.code;
                    return AppCard(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      borderColor: isSelected ? colors.primary : colors.border,
                      backgroundColor: isSelected
                          ? colors.primary.withValues(alpha: 0.06)
                          : colors.surface,
                      onTap: () => controller.setLocale(
                        Locale(item.code),
                        markPicked: false,
                      ),
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  item.primary,
                                  style: context.text.h1.copyWith(
                                    color: isSelected
                                        ? colors.primary
                                        : colors.ink,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.xs),
                                Text(
                                  item.secondary,
                                  style: context.text.caption.copyWith(
                                    color: colors.inkMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            isSelected
                                ? Icons.check_circle_rounded
                                : Icons.radio_button_unchecked_rounded,
                            color: isSelected ? colors.primary : colors.inkFaint,
                            size: 28,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                label: l10n.continueAction,
                trailingIcon: Icons.arrow_forward_rounded,
                onPressed: () async {
                  await controller.setLocale(
                    prefs.locale,
                    markPicked: true,
                  );
                  onCompleted();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
