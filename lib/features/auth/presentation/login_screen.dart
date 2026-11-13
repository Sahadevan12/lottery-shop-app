import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/rpc_error_mapper.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/ui_kit.dart';
import '../../../core/utils/validators.dart';
import '../../../l10n/app_localizations.dart';
import 'auth_controller.dart';

/// Login Screen (§6.2, §8.1 #3).
/// - Phone number (`+91` prefix fixed) + 6-digit PIN with large numeric keypad UI.
/// - "Forgot PIN?" shows "Contact support" bottom sheet for MVP.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final TextEditingController _phoneController = TextEditingController();
  String _pin = '';
  String? _phoneError;
  String? _pinError;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  void _onDigitTap(String digit) {
    if (_pin.length >= 6) {
      return;
    }
    HapticFeedback.lightImpact();
    setState(() {
      _pin += digit;
      _pinError = null;
    });
  }

  void _onBackspace() {
    if (_pin.isEmpty) {
      return;
    }
    HapticFeedback.selectionClick();
    setState(() {
      _pin = _pin.substring(0, _pin.length - 1);
      _pinError = null;
    });
  }

  Future<void> _submit() async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String phone = _phoneController.text;
    final bool validPhone = AppValidators.isValidPhone(phone);
    final bool validPin = AppValidators.isValidPin(_pin);

    setState(() {
      _phoneError = validPhone ? null : l10n.invalidPhoneError;
      _pinError = validPin ? null : l10n.invalidPinError;
    });

    if (!validPhone || !validPin) {
      return;
    }

    final bool ok = await ref
        .read(authControllerProvider.notifier)
        .signInWithPhoneAndPin(phone: phone, pin: _pin);

    if (!ok && mounted) {
      final String? rawErr = ref.read(authControllerProvider).errorMessage;
      AppSnackbar.show(
        context,
        message: RpcErrorMapper.toLocalizedMessage(rawErr ?? '', l10n),
        isError: true,
      );
    }
  }

  void _showForgotPinSheet(AppLocalizations l10n) {
    AppBottomSheet.show<void>(
      context: context,
      title: l10n.forgotPinDialogTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            l10n.forgotPinDialogBody,
            style: context.text.body.copyWith(color: context.colors.inkMuted),
          ),
          const SizedBox(height: AppSpacing.xl),
          AppButton(
            label: l10n.contactSupportClose,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
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
              Text(l10n.loginTitle, style: context.text.h1),
              const SizedBox(height: AppSpacing.xs),
              Text(
                l10n.loginSubtitle,
                style: context.text.body.copyWith(color: colors.inkMuted),
              ),
              const SizedBox(height: AppSpacing.xl),

              // Phone Field (+91 prefix fixed)
              AppTextField(
                label: l10n.phoneLabel,
                controller: _phoneController,
                hintText: l10n.phoneHint,
                prefixText: l10n.phonePrefix,
                errorText: _phoneError,
                keyboardType: TextInputType.phone,
                maxLength: 10,
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.digitsOnly,
                ],
                onChanged: (_) {
                  if (_phoneError != null) {
                    setState(() => _phoneError = null);
                  }
                },
              ),
              const SizedBox(height: AppSpacing.lg),

              // 6-digit PIN Indicator Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text(
                    l10n.pinLabel,
                    style: context.text.label.copyWith(color: colors.ink),
                  ),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _showForgotPinSheet(l10n),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.xs,
                      ),
                      child: Text(
                        l10n.forgotPinAction,
                        style: context.text.caption.copyWith(
                          color: colors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),

              // 6-digit PIN Boxes
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List<Widget>.generate(6, (int index) {
                  final bool isFilled = index < _pin.length;
                  final bool isCurrent = index == _pin.length;
                  return Container(
                    width: 48,
                    height: 52,
                    decoration: BoxDecoration(
                      color: colors.surfaceAlt,
                      borderRadius:
                          BorderRadius.circular(AppSpacing.inputRadius),
                      border: Border.all(
                        color: _pinError != null
                            ? colors.danger
                            : (isCurrent ? colors.primary : colors.border),
                        width: isCurrent ? 1.5 : AppSpacing.borderWidth,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: isFilled
                        ? Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: colors.ink,
                              shape: BoxShape.circle,
                            ),
                          )
                        : null,
                  );
                }),
              ),
              if (_pinError != null) ...<Widget>[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  _pinError!,
                  style: context.text.caption.copyWith(color: colors.danger),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),

              // Large Numeric Keypad UI (§8.1 #3)
              _PinKeypad(
                onDigitTap: _onDigitTap,
                onBackspace: _onBackspace,
              ),
              const SizedBox(height: AppSpacing.xl),

              // Primary Sign In Action
              AppButton(
                label: l10n.signInAction,
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

class _PinKeypad extends StatelessWidget {
  const _PinKeypad({
    required this.onDigitTap,
    required this.onBackspace,
  });

  final ValueChanged<String> onDigitTap;
  final VoidCallback onBackspace;

  @override
  Widget build(BuildContext context) {
    final List<List<String>> rows = <List<String>>[
      <String>['1', '2', '3'],
      <String>['4', '5', '6'],
      <String>['7', '8', '9'],
      <String>['', '0', '⌫'],
    ];

    return Column(
      children: rows.map((List<String> row) {
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Row(
            children: row.map((String keyLabel) {
              if (keyLabel.isEmpty) {
                return const Expanded(child: SizedBox(height: 52));
              }
              final bool isBackspace = keyLabel == '⌫';
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xs,
                  ),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: isBackspace
                        ? onBackspace
                        : () => onDigitTap(keyLabel),
                    child: Container(
                      height: 52,
                      decoration: BoxDecoration(
                        color: context.colors.surface,
                        borderRadius: BorderRadius.circular(
                          AppSpacing.buttonRadius,
                        ),
                        border: Border.all(
                          color: context.colors.border,
                          width: AppSpacing.borderWidth,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: isBackspace
                          ? Icon(
                              Icons.backspace_outlined,
                              size: 20,
                              color: context.colors.ink,
                            )
                          : Text(
                              keyLabel,
                              style: context.text.h2,
                            ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      }).toList(),
    );
  }
}
