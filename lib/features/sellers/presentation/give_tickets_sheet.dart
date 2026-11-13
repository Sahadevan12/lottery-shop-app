import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/rpc_error_mapper.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/ui_kit.dart';
import '../../../core/utils/formatters.dart';
import '../../../l10n/app_localizations.dart';
import '../../stock/domain/stock_entities.dart';
import '../../stock/presentation/stock_controller.dart';
import '../domain/ledger_math.dart';
import '../domain/seller_entities.dart';
import 'sellers_controller.dart';

/// Give Tickets to Seller Sheet (§7.2, §8.4, A.3, Addition #2).
/// - Active sellers only.
/// - Mode "By count" auto-picks next N `IN_STOCK` tickets and previews the ranges.
/// - Mode "By range" selects exact `[series, start..end]` `IN_STOCK` tickets.
/// - On `TICKETS_NOT_AVAILABLE`, shows a friendly message, auto-refreshes the draw's
///   ticket list, and rebuilds the preview while keeping the sheet open.
class GiveTicketsSheet extends ConsumerStatefulWidget {
  const GiveTicketsSheet({
    super.key,
    this.initialSeller,
    this.initialDraw,
  });

  final SellerProfile? initialSeller;
  final LotteryDraw? initialDraw;

  static Future<void> show({
    required BuildContext context,
    SellerProfile? initialSeller,
    LotteryDraw? initialDraw,
  }) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return AppBottomSheet.show<void>(
      context: context,
      title: l10n.giveTicketsSheetTitle,
      subtitle: initialSeller?.name,
      child: GiveTicketsSheet(
        initialSeller: initialSeller,
        initialDraw: initialDraw,
      ),
    );
  }

  @override
  ConsumerState<GiveTicketsSheet> createState() => _GiveTicketsSheetState();
}

class _GiveTicketsSheetState extends ConsumerState<GiveTicketsSheet> {
  final TextEditingController _countController =
      TextEditingController(text: '25');
  final TextEditingController _seriesController = TextEditingController();
  final TextEditingController _startController = TextEditingController();
  final TextEditingController _endController = TextEditingController();

  String? _selectedSellerId;
  String? _selectedDrawId;
  bool _byCountMode = true;
  bool _isLoadingTickets = false;
  List<TicketItem> _drawTickets = const <TicketItem>[];
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _selectedSellerId = widget.initialSeller?.id;
    final StockState stockState = ref.read(stockControllerProvider);
    final List<LotteryDraw> openDraws = stockState.draws
        .where((LotteryDraw d) => d.status == DrawStatus.upcoming)
        .toList();
    final LotteryDraw? defaultDraw = widget.initialDraw ??
        (stockState.selectedDraw?.status == DrawStatus.upcoming
            ? stockState.selectedDraw
            : (openDraws.isNotEmpty ? openDraws.first : null));
    _selectedDrawId = defaultDraw?.id;
    _seriesController.text = (defaultDraw?.lotteryCode ?? 'KR').toUpperCase();
    if (_selectedDrawId != null) {
      _refreshDrawTickets(_selectedDrawId!);
    }
  }

  @override
  void dispose() {
    _countController.dispose();
    _seriesController.dispose();
    _startController.dispose();
    _endController.dispose();
    super.dispose();
  }

  Future<void> _refreshDrawTickets(String drawId) async {
    setState(() => _isLoadingTickets = true);
    try {
      final List<TicketItem> tickets =
          await ref.read(stockRepositoryProvider).fetchTicketsForDraw(drawId);
      if (mounted) {
        setState(() {
          _drawTickets = tickets;
          _isLoadingTickets = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingTickets = false);
      }
    }
  }

  LotteryDraw? _currentDraw(List<LotteryDraw> draws) {
    for (final LotteryDraw d in draws) {
      if (d.id == _selectedDrawId) {
        return d;
      }
    }
    return null;
  }

  List<TicketItem>? _previewSelection() {
    if (_byCountMode) {
      final int count = int.tryParse(_countController.text.trim()) ?? 0;
      final String seriesFilter = _seriesController.text.trim();
      return LedgerMath.pickNextInStockTickets(
        tickets: _drawTickets,
        count: count,
        seriesFilter: seriesFilter.isEmpty ? null : seriesFilter,
      );
    }
    return LedgerMath.selectTicketsInRange(
      tickets: _drawTickets,
      series: _seriesController.text,
      startNumber: _startController.text,
      endNumber: _endController.text,
      requiredStatus: TicketStatus.inStock,
    );
  }

  Future<void> _submit(LotteryDraw? draw) async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String? sellerId = _selectedSellerId;
    if (sellerId == null || draw == null) {
      setState(() => _statusMessage = l10n.errorNotFound);
      return;
    }

    final List<TicketItem>? selected = _previewSelection();
    if (selected == null || selected.isEmpty) {
      setState(
        () => _statusMessage =
            _byCountMode ? l10n.notEnoughStockError : l10n.errorInvalidRange,
      );
      return;
    }

    final bool ok = await ref
        .read(sellersControllerProvider.notifier)
        .issueTickets(
          sellerId: sellerId,
          drawId: draw.id,
          ticketIds: selected.map((TicketItem t) => t.id).toList(),
        );

    if (!mounted) {
      return;
    }

    if (!ok) {
      final String? rawErr = ref.read(sellersControllerProvider).errorMessage;
      setState(() {
        _statusMessage = RpcErrorMapper.toLocalizedMessage(
          rawErr ?? '',
          l10n,
        );
      });
      if (RpcErrorMapper.isTicketAvailabilityConflict(rawErr ?? '')) {
        await _refreshDrawTickets(draw.id);
      }
      return;
    }

    AppSnackbar.show(
      context,
      message: l10n.ticketsIssuedSuccess(
        AppFormatters.count(selected.length),
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppColors colors = context.colors;
    final SellersState sellersState = ref.watch(sellersControllerProvider);
    final StockState stockState = ref.watch(stockControllerProvider);

    final List<SellerSummary> activeSellers = sellersState.activeSellers;
    final List<LotteryDraw> openDraws = stockState.draws
        .where((LotteryDraw d) => d.status == DrawStatus.upcoming)
        .toList();
    final LotteryDraw? draw = _currentDraw(openDraws);
    final List<TicketItem>? preview = _previewSelection();
    final int count = preview?.length ?? 0;
    final int totalPaise = count * (draw?.ticketPricePaise ?? 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (widget.initialSeller == null) ...<Widget>[
          Text(l10n.selectSellerLabel, style: context.text.label),
          const SizedBox(height: AppSpacing.xs),
          SizedBox(
            height: AppSpacing.minTouchTarget,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: <Widget>[
                for (final SellerSummary s in activeSellers) ...<Widget>[
                  AppChip(
                    label: s.seller.name,
                    selected: _selectedSellerId == s.seller.id,
                    onTap: () => setState(() {
                      _selectedSellerId = s.seller.id;
                      _statusMessage = null;
                    }),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        if (openDraws.isNotEmpty) ...<Widget>[
          SizedBox(
            height: AppSpacing.minTouchTarget,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: <Widget>[
                for (final LotteryDraw d in openDraws) ...<Widget>[
                  AppChip(
                    label:
                        '${d.lotteryName} (${AppFormatters.shortDate(d.drawDate)})',
                    badgeText: d.drawNumber,
                    selected: _selectedDrawId == d.id,
                    onTap: () {
                      setState(() {
                        _selectedDrawId = d.id;
                        _seriesController.text =
                            (d.lotteryCode ?? 'KR').toUpperCase();
                        _statusMessage = null;
                      });
                      _refreshDrawTickets(d.id);
                    },
                  ),
                  const SizedBox(width: AppSpacing.sm),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        Row(
          children: <Widget>[
            Expanded(
              child: AppChip(
                label: l10n.issueModeByCount,
                selected: _byCountMode,
                onTap: () => setState(() {
                  _byCountMode = true;
                  _statusMessage = null;
                }),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: AppChip(
                label: l10n.issueModeByRange,
                selected: !_byCountMode,
                onTap: () => setState(() {
                  _byCountMode = false;
                  _statusMessage = null;
                }),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        if (_byCountMode) ...<Widget>[
          Row(
            children: <Widget>[
              Expanded(
                flex: 3,
                child: AppTextField(
                  label: l10n.ticketCountToGiveLabel,
                  controller: _countController,
                  hintText: l10n.ticketCountToGiveHint,
                  keyboardType: TextInputType.number,
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  onChanged: (_) => setState(() => _statusMessage = null),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                flex: 2,
                child: AppTextField(
                  label: l10n.seriesFieldLabel,
                  controller: _seriesController,
                  hintText: l10n.seriesFieldHint,
                  useMonoFont: true,
                  maxLength: 3,
                  textCapitalization: TextCapitalization.characters,
                  onChanged: (_) => setState(() => _statusMessage = null),
                ),
              ),
            ],
          ),
          if (preview != null && preview.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Text(
              '${l10n.nextTicketsPreviewLabel} ${LedgerMath.summarizeTicketRanges(preview)}',
              style: context.text.ticketMono.copyWith(color: colors.primary),
            ),
          ],
        ] else ...<Widget>[
          AppTextField(
            label: l10n.seriesFieldLabel,
            controller: _seriesController,
            hintText: l10n.seriesFieldHint,
            useMonoFont: true,
            maxLength: 3,
            textCapitalization: TextCapitalization.characters,
            onChanged: (_) => setState(() => _statusMessage = null),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: <Widget>[
              Expanded(
                child: AppTextField(
                  label: l10n.startNumberFieldLabel,
                  controller: _startController,
                  hintText: l10n.startNumberFieldHint,
                  useMonoFont: true,
                  maxLength: 6,
                  keyboardType: TextInputType.number,
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  onChanged: (_) => setState(() => _statusMessage = null),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: AppTextField(
                  label: l10n.endNumberFieldLabel,
                  controller: _endController,
                  hintText: l10n.endNumberFieldHint,
                  useMonoFont: true,
                  maxLength: 6,
                  keyboardType: TextInputType.number,
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  onChanged: (_) => setState(() => _statusMessage = null),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        AppCard(
          backgroundColor: colors.surfaceAlt,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    l10n.quantityLabel,
                    style:
                        context.text.caption.copyWith(color: colors.inkMuted),
                  ),
                  Text(
                    _isLoadingTickets
                        ? '…'
                        : l10n.ticketsCountLabel(AppFormatters.count(count)),
                    style: context.text.h2,
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Text(
                    l10n.issueTotalAmountLabel,
                    style:
                        context.text.caption.copyWith(color: colors.inkMuted),
                  ),
                  MoneyText(
                    paise: totalPaise,
                    tone: MoneyTone.balanceDue,
                    style: context.text.h2,
                  ),
                ],
              ),
            ],
          ),
        ),
        if (_statusMessage != null) ...<Widget>[
          const SizedBox(height: AppSpacing.sm),
          Text(
            _statusMessage!,
            style: context.text.caption.copyWith(color: colors.danger),
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
        AppButton(
          label: l10n.confirmGiveTicketsAction,
          isLoading: sellersState.isSubmitting,
          onPressed: () => _submit(draw),
        ),
      ],
    );
  }
}
