import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/rpc_error_mapper.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/ui_kit.dart';
import '../../../core/utils/app_constants.dart';
import '../../../l10n/app_localizations.dart';
import '../../settings/presentation/app_preferences_controller.dart';
import 'auth_controller.dart';

/// Shop Setup Screen (First Login Only, §8.1 #4).
/// - Shop name, owner name, district (14 Kerala districts), agent code (optional).
/// - Calls `create_shop_with_defaults` to create shop + default lotteries + prize template.
class ShopSetupScreen extends ConsumerStatefulWidget {
  const ShopSetupScreen({super.key});

  @override
  ConsumerState<ShopSetupScreen> createState() => _ShopSetupScreenState();
}

class _ShopSetupScreenState extends ConsumerState<ShopSetupScreen> {
  final TextEditingController _shopNameController = TextEditingController();
  final TextEditingController _ownerNameController = TextEditingController();
  final TextEditingController _agentCodeController = TextEditingController();

  String? _selectedDistrict;
  String? _shopNameError;
  String? _ownerNameError;
  String? _districtError;

  @override
  void dispose() {
    _shopNameController.dispose();
    _ownerNameController.dispose();
    _agentCodeController.dispose();
    super.dispose();
  }

  String _localizedDistrictName(String districtKey, AppLocalizations l10n) {
    switch (districtKey) {
      case 'Thiruvananthapuram':
        return l10n.districtThiruvananthapuram;
      case 'Kollam':
        return l10n.districtKollam;
      case 'Pathanamthitta':
        return l10n.districtPathanamthitta;
      case 'Alappuzha':
        return l10n.districtAlappuzha;
      case 'Kottayam':
        return l10n.districtKottayam;
      case 'Idukki':
        return l10n.districtIdukki;
      case 'Ernakulam':
        return l10n.districtErnakulam;
      case 'Thrissur':
        return l10n.districtThrissur;
      case 'Palakkad':
        return l10n.districtPalakkad;
      case 'Malappuram':
        return l10n.districtMalappuram;
      case 'Kozhikode':
        return l10n.districtKozhikode;
      case 'Wayanad':
        return l10n.districtWayanad;
      case 'Kannur':
        return l10n.districtKannur;
      case 'Kasaragod':
        return l10n.districtKasaragod;
      default:
        return districtKey;
    }
  }

  void _openDistrictPicker(AppLocalizations l10n) {
    AppBottomSheet.show<void>(
      context: context,
      title: l10n.districtLabel,
      child: Column(
        children: AppConstants.keralaDistrictKeys.map((String key) {
          final bool isSelected = key == _selectedDistrict;
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: AppCard(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              borderColor:
                  isSelected ? context.colors.primary : context.colors.border,
              onTap: () {
                setState(() {
                  _selectedDistrict = key;
                  _districtError = null;
                });
                Navigator.of(context).pop();
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text(
                    _localizedDistrictName(key, l10n),
                    style: context.text.bodyMedium,
                  ),
                  if (isSelected)
                    Icon(
                      Icons.check_circle_rounded,
                      color: context.colors.primary,
                      size: 20,
                    ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Future<void> _submit() async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String shopName = _shopNameController.text.trim();
    final String ownerName = _ownerNameController.text.trim();

    setState(() {
      _shopNameError = shopName.isEmpty ? l10n.shopNameRequiredError : null;
      _ownerNameError = ownerName.isEmpty ? l10n.ownerNameRequiredError : null;
      _districtError =
          _selectedDistrict == null ? l10n.districtRequiredError : null;
    });

    if (shopName.isEmpty || ownerName.isEmpty || _selectedDistrict == null) {
      return;
    }

    final String lang = ref.read(appPreferencesProvider).locale.languageCode;
    final bool ok = await ref
        .read(authControllerProvider.notifier)
        .completeShopSetup(
          name: shopName,
          ownerName: ownerName,
          district: _selectedDistrict!,
          agentCode: _agentCodeController.text,
          language: lang,
        );

    if (!ok && mounted) {
      final String? rawErr = ref.read(authControllerProvider).errorMessage;
      AppSnackbar.show(
        context,
        message: RpcErrorMapper.toLocalizedMessage(rawErr ?? '', l10n),
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppColors colors = context.colors;
    final AuthState authState = ref.watch(authControllerProvider);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenHorizontal,
            AppSpacing.xl,
            AppSpacing.screenHorizontal,
            AppSpacing.xl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Expanded(
                    child: Text(l10n.shopSetupTitle, style: context.text.h1),
                  ),
                  IconButton(
                    tooltip: l10n.signOutAction,
                    onPressed: () {
                      ref.read(authControllerProvider.notifier).signOut();
                    },
                    icon: Icon(
                      Icons.logout_rounded,
                      color: colors.inkMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                l10n.shopSetupSubtitle,
                style: context.text.body.copyWith(color: colors.inkMuted),
              ),
              const SizedBox(height: AppSpacing.xl),
              AppTextField(
                label: l10n.shopNameLabel,
                controller: _shopNameController,
                hintText: l10n.shopNameHint,
                errorText: _shopNameError,
                textCapitalization: TextCapitalization.words,
                onChanged: (_) {
                  if (_shopNameError != null) {
                    setState(() => _shopNameError = null);
                  }
                },
              ),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                label: l10n.ownerNameLabel,
                controller: _ownerNameController,
                hintText: l10n.ownerNameHint,
                errorText: _ownerNameError,
                textCapitalization: TextCapitalization.words,
                onChanged: (_) {
                  if (_ownerNameError != null) {
                    setState(() => _ownerNameError = null);
                  }
                },
              ),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                label: l10n.districtLabel,
                hintText: l10n.districtHint,
                errorText: _districtError,
                readOnly: true,
                controller: TextEditingController(
                  text: _selectedDistrict == null
                      ? ''
                      : _localizedDistrictName(_selectedDistrict!, l10n),
                ),
                suffixIcon: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: colors.inkMuted,
                ),
                onTap: () => _openDistrictPicker(l10n),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                label: l10n.agentCodeLabel,
                controller: _agentCodeController,
                hintText: l10n.agentCodeHint,
                textCapitalization: TextCapitalization.characters,
              ),
              const SizedBox(height: AppSpacing.xxl),
              AppButton(
                label: l10n.completeSetupAction,
                isLoading: authState.isLoading,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
