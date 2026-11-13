import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/ui_kit.dart';
import '../../../l10n/app_localizations.dart';
import '../../settings/domain/app_preferences.dart';
import '../../settings/presentation/app_preferences_controller.dart';

/// Onboarding Step 2 — Welcome Screen (§2, §8.1 #2).
/// - 3 swipeable slides (illustration + headline + one-line description)
/// - Mandatory legal disclaimer at bottom (§2)
/// - Instant language switch pill in top bar (§4.7 #8)
/// - Single primary CTA at bottom: "Get started"
class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({
    super.key,
    required this.onGetStarted,
  });

  final VoidCallback onGetStarted;

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppColors colors = context.colors;
    final AppPreferences prefs = ref.watch(appPreferencesProvider);
    final AppPreferencesController prefsController =
        ref.read(appPreferencesProvider.notifier);

    final List<({IconData icon, String title, String body, bool isGold})>
        slides = <({IconData icon, String title, String body, bool isGold})>[
      (
        icon: Icons.inventory_2_outlined,
        title: l10n.welcomeSlide1Title,
        body: l10n.welcomeSlide1Body,
        isGold: false,
      ),
      (
        icon: Icons.menu_book_rounded,
        title: l10n.welcomeSlide2Title,
        body: l10n.welcomeSlide2Body,
        isGold: false,
      ),
      (
        icon: Icons.emoji_events_outlined,
        title: l10n.welcomeSlide3Title,
        body: l10n.welcomeSlide3Body,
        isGold: true,
      ),
    ];

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenHorizontal,
            AppSpacing.md,
            AppSpacing.screenHorizontal,
            AppSpacing.xl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // Top bar: brand name + instant language switcher
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text(
                    l10n.appName,
                    style: context.text.h2.copyWith(color: colors.primary),
                  ),
                  Wrap(
                    spacing: AppSpacing.xs,
                    children: <Widget>[
                      for (final (String code, String label) in <(String, String)>[
                        ('ml', 'മല'),
                        ('ta', 'தமி'),
                        ('en', 'EN'),
                      ])
                        AppChip(
                          label: label,
                          selected: prefs.locale.languageCode == code,
                          onTap: () => prefsController.setLocale(Locale(code)),
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),

              // 3 Swipeable slides
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: slides.length,
                  onPageChanged: (int idx) =>
                      setState(() => _currentIndex = idx),
                  itemBuilder: (BuildContext context, int index) {
                    final slide = slides[index];
                    final Color accent =
                        slide.isGold ? colors.gold : colors.primary;
                    final Color softBg = slide.isGold
                        ? colors.goldSoft
                        : colors.primary.withValues(alpha: 0.08);

                    return Center(
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Container(
                              width: 84,
                              height: 84,
                              decoration: BoxDecoration(
                                color: softBg,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: accent.withValues(alpha: 0.35),
                                  width: AppSpacing.borderWidth,
                                ),
                              ),
                              child: Icon(
                                slide.icon,
                                size: 40,
                                color: accent,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            Text(
                              slide.title,
                              textAlign: TextAlign.center,
                              style: context.text.h1,
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              slide.body,
                              textAlign: TextAlign.center,
                              style: context.text.body.copyWith(
                                color: colors.inkMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Slide indicator dots
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List<Widget>.generate(slides.length, (int i) {
                  final bool active = i == _currentIndex;
                  return AnimatedContainer(
                    duration: AppSpacing.motionFast,
                    margin: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xs,
                    ),
                    width: active ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: active ? colors.primary : colors.border,
                      borderRadius: BorderRadius.circular(
                        AppSpacing.chipRadius,
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Mandatory Legal Disclaimer (§2)
              AppCard(
                padding: const EdgeInsets.all(AppSpacing.md),
                backgroundColor: colors.surfaceAlt,
                child: Text(
                  l10n.legalDisclaimer,
                  style: context.text.caption.copyWith(color: colors.inkMuted),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Primary Action
              AppButton(
                label: l10n.getStartedAction,
                trailingIcon: Icons.arrow_forward_rounded,
                onPressed: () async {
                  await prefsController.completeWelcome();
                  widget.onGetStarted();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
