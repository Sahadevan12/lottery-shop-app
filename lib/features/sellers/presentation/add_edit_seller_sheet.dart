import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/rpc_error_mapper.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/ui_kit.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/seller_entities.dart';
import 'sellers_controller.dart';

/// Add or Edit Seller Bottom Sheet (§8.4).
class AddEditSellerSheet extends ConsumerStatefulWidget {
  const AddEditSellerSheet({
    super.key,
    this.existingSeller,
  });

  final SellerProfile? existingSeller;

  static Future<bool?> show({
    required BuildContext context,
    SellerProfile? existingSeller,
  }) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return AppBottomSheet.show<bool>(
      context: context,
      title: existingSeller == null
          ? l10n.addSellerAction
          : l10n.editSellerTitle,
      child: AddEditSellerSheet(existingSeller: existingSeller),
    );
  }

  @override
  ConsumerState<AddEditSellerSheet> createState() => _AddEditSellerSheetState();
}

class _AddEditSellerSheetState extends ConsumerState<AddEditSellerSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _areaController;

  String? _validationError;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.existingSeller?.name ?? '',
    );
    _phoneController = TextEditingController(
      text: widget.existingSeller?.phone ?? '',
    );
    _areaController = TextEditingController(
      text: widget.existingSeller?.area ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _areaController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _validationError = l10n.sellerNameRequiredError);
      return;
    }

    final bool ok = await ref
        .read(sellersControllerProvider.notifier)
        .saveSeller(
          id: widget.existingSeller?.id,
          name: name,
          phone: _phoneController.text.trim(),
          area: _areaController.text.trim(),
        );

    if (!mounted) {
      return;
    }

    if (!ok) {
      final String? rawErr = ref.read(sellersControllerProvider).errorMessage;
      setState(() {
        _validationError = RpcErrorMapper.toLocalizedMessage(
          rawErr ?? '',
          l10n,
        );
      });
      return;
    }

    AppSnackbar.show(context, message: l10n.sellerSavedSuccess);
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppColors colors = context.colors;
    final SellersState state = ref.watch(sellersControllerProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        AppTextField(
          label: l10n.sellerNameLabel,
          controller: _nameController,
          hintText: l10n.sellerNameHint,
          textCapitalization: TextCapitalization.words,
          onChanged: (_) {
            if (_validationError != null) {
              setState(() => _validationError = null);
            }
          },
        ),
        const SizedBox(height: AppSpacing.lg),
        AppTextField(
          label: l10n.phoneLabel,
          controller: _phoneController,
          hintText: l10n.phoneHint,
          keyboardType: TextInputType.phone,
          maxLength: 10,
          inputFormatters: <TextInputFormatter>[
            FilteringTextInputFormatter.digitsOnly,
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        AppTextField(
          label: l10n.sellerAreaLabel,
          controller: _areaController,
          hintText: l10n.sellerAreaHint,
          textCapitalization: TextCapitalization.words,
        ),
        if (_validationError != null) ...<Widget>[
          const SizedBox(height: AppSpacing.sm),
          Text(
            _validationError!,
            style: context.text.caption.copyWith(color: colors.danger),
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
        AppButton(
          label: l10n.saveAction,
          isLoading: state.isSubmitting,
          onPressed: _submit,
        ),
      ],
    );
  }
}
