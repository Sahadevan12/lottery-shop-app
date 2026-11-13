import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_theme.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/results/presentation/results_placeholder_screen.dart';
import '../features/sellers/presentation/sellers_screen.dart';
import '../features/settings/presentation/more_screen.dart';
import '../features/stock/presentation/stock_screen.dart';
import '../l10n/app_localizations.dart';

/// 5-Tab Bottom Navigation Shell (§4.7 #2).
/// Tabs: Home, Stock, Sellers, Results, More. Icons + labels always visible.
class MainShellScreen extends StatefulWidget {
  const MainShellScreen({super.key});

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  int _currentIndex = 0;

  void _selectTab(int index) {
    if (_currentIndex == index) {
      return;
    }
    HapticFeedback.selectionClick();
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppColors colors = context.colors;

    final List<Widget> pages = <Widget>[
      HomeScreen(
        onGoToStock: () => _selectTab(1),
        onGoToSellers: () => _selectTab(2),
      ),
      const StockScreen(),
      const SellersScreen(),
      const ResultsPlaceholderScreen(),
      const MoreScreen(),
    ];

    final List<({IconData icon, IconData activeIcon, String label})> items =
        <({IconData icon, IconData activeIcon, String label})>[
      (
        icon: Icons.home_outlined,
        activeIcon: Icons.home_rounded,
        label: l10n.navHome,
      ),
      (
        icon: Icons.inventory_2_outlined,
        activeIcon: Icons.inventory_2_rounded,
        label: l10n.navStock,
      ),
      (
        icon: Icons.people_outline_rounded,
        activeIcon: Icons.people_rounded,
        label: l10n.navSellers,
      ),
      (
        icon: Icons.emoji_events_outlined,
        activeIcon: Icons.emoji_events_rounded,
        label: l10n.navResults,
      ),
      (
        icon: Icons.menu_rounded,
        activeIcon: Icons.menu_open_rounded,
        label: l10n.navMore,
      ),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: pages,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border(
            top: BorderSide(
              color: colors.border,
              width: AppSpacing.borderWidth,
            ),
          ),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 64,
            child: Row(
              children: List<Widget>.generate(items.length, (int index) {
                final item = items[index];
                final bool selected = index == _currentIndex;
                final Color fg = selected ? colors.primary : colors.inkMuted;

                return Expanded(
                  child: Semantics(
                    button: true,
                    selected: selected,
                    label: item.label,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _selectTab(index),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Icon(
                            selected ? item.activeIcon : item.icon,
                            color: fg,
                            size: 24,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.text.caption.copyWith(
                              color: fg,
                              fontWeight: selected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}
