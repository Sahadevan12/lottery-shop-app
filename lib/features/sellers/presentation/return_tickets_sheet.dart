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
import '../domain/seller_entities.dart';
import 'sellers_controller.dart';

/// Return Unsold Tickets Sheet (§7.3, §8.4, Addition #2).
/// - Supports draws in `UPCOMING` or `RESULT_ENTERED` status.
/// - Modes: "By range" or "Tap to select" from the seller's `WITH_SELLER` tickets.
/// - On `TICKETS_NOT_WITH_SELLER` / `TICKETS_NOT_AVAILABLE`, shows a friendly message,
///   auto-refreshes the seller's tickets, and rebuilds the preview while keeping the sheet open.
class ReturnTicketsSheet extends ConsumerStatefulWidget {
  const ReturnTicketsSheet({
    super.key,
    required this.seller,
  });

  final SellerProfile seller;

  static Future<void> show({
    required BuildContext context,
    required SellerProfile seller,
  }) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return AppBottomSheet.show<void>(
      context: context,
      title: l10n.returnTicketsSheetTitle,
      subtitle: seller.name,
      child: ReturnTicketsSheet(seller: seller),
    );
  }

  @override
  ConsumerState<ReturnTicketsSheet> createState() => _ReturnTicketsSheetState();
}

class _ReturnTicketsSheetState extends ConsumerState<ReturnTicketsSheet> {
  final TextEditingController _seriesController = TextEditingController();
  final TextEditingController _startController = TextEditingController();
  final TextEditingController _endController = TextEditingController();

  String? _selectedDrawId;
  bool _byRangeMode = false;
  bool _isLoadingTickets = true;
  List<TicketItem> _sellerTickets = const <TicketItem>[];
  final Set<String> _tappedIds = <String>{};
  TicketRangePreview _rangePreview = const TicketRangePreview(
    totalCount: 0,
    rangesSummary: '',
  );
  int _previewGeneration = 0;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _refreshSellerTickets();
  }

  @override
  void dispose() {
    _seriesController.dispose();
    _startController.dispose();
    _endController.dispose();
    super.dispose();
  }

  Future<void> _refreshSellerTickets() async {
    setState(() => _isLoadingTickets = true);
    try {
      final List<TicketItem> allTickets = await ref
          .read(sellerRepositoryProvider)
          .fetchSellerTickets(
            widget.seller.id,
            limit: 200,
          );
      final List<TicketItem> withSeller = allTickets
          .where((TicketItem t) => t.status == TicketStatus.withSeller)
          .toList();
      if (mounted) {
        final Set<String> validIds =
            withSeller.map((TicketItem t) => t.id).toSet();
        _tappedIds.removeWhere((String id) => !validIds.contains(id));
        String? nextDrawId = _selectedDrawId;
        if (nextDrawId == null && withSeller.isNotEmpty) {
          nextDrawId = withSeller.first.drawId;
          _seriesController.text = withSeller.first.series;
        }
        setState(() {
          _sellerTickets = withSeller;
          _selectedDrawId = nextDrawId;
          _isLoadingTickets = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingTickets = false);
      }
    }
  }

  Future<void> _refreshRangePreview() async {
    final String? drawId = _selectedDrawId;
    final String series = _seriesController.text.trim().toUpperCase();
    final String start = _startController.text.trim();
    final String end = _endController.text.trim();
    if (drawId == null ||
        series.isEmpty ||
        start.length != 6 ||
        end.length != 6) {
      if (mounted) {
        setState(() {
          _rangePreview = const TicketRangePreview(
            totalCount: 0,
            rangesSummary: '',
          );
        });
      }
      return;
    }
    final int gen = ++_previewGeneration;
    try {
      final TicketRangePreview preview =
          await ref.read(stockRepositoryProvider).previewTickets(
                drawId: drawId,
                mode: 'RANGE',
                series: series,
                startNumber: start,
                endNumber: end,
                status: TicketStatus.withSeller,
                sellerId: widget.seller.id,
              );
      if (mounted && gen == _previewGeneration) {
        setState(() => _rangePreview = preview);
      }
    } catch (_) {
      // Keep previous preview on transient error.
    }
  }

  List<TicketItem> _ticketsForSelectedDraw() {
    if (_selectedDrawId == null) {
      return const <TicketItem>[];
    }
    return _sellerTickets
        .where((TicketItem t) => t.drawId == _selectedDrawId)
        .toList();
  }

  Future<void> _submit(LotteryDraw? draw) async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    if (draw == null) {
      setState(() => _statusMessage = l10n.errorNotFound);
      return;
    }

    final SellersController controller =
        ref.read(sellersControllerProvider.notifier);
    bool ok = false;
    int expectedCount = 0;

    if (_byRangeMode) {
      final String series = _seriesController.text.trim().toUpperCase();
      final String start = _startController.text.trim();
      final String end = _endController.text.trim();
      expectedCount = _rangePreview.totalCount;
      if (series.isEmpty ||
          start.length != 6 ||
          end.length != 6 ||
          expectedCount == 0) {
        setState(() => _statusMessage = l10n.errorInvalidRange);
        return;
      }
      ok = await controller.returnTicketsByRange(
        sellerId: widget.seller.id,
        drawId: draw.id,
        series: series,
        startNumber: start,
        endNumber: end,
      );
    } else {
      final List<TicketItem> selected = _ticketsForSelectedDraw()
          .where((TicketItem t) => _tappedIds.contains(t.id))
          .toList();
      if (selected.isEmpty) {
        setState(() => _statusMessage = l10n.errorInvalidRange);
        return;
      }
      expectedCount = selected.length;
      ok = await controller.returnTickets(
        sellerId: widget.seller.id,
        drawId: draw.id,
        ticketIds: selected.map((TicketItem t) => t.id).toList(),
      );
    }

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
        await _refreshSellerTickets();
        await _refreshRangePreview();
      }
      return;
    }

    AppSnackbar.show(
      context,
      message: l10n.ticketsReturnedSuccess(
        AppFormatters.count(expectedCount),
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

    final List<LotteryDraw> returnableDraws = stockState.draws
        .where((LotteryDraw d) => d.status != DrawStatus.closed)
        .toList();
    LotteryDraw? selectedDraw;
    for (final LotteryDraw d in returnableDraws) {
      if (d.id == _selectedDrawId) {
        selectedDraw = d;
        break;
      }
    }
    selectedDraw ??=
        returnableDraws.isNotEmpty ? returnableDraws.first : null;

    final List<TicketItem> drawTickets = _ticketsForSelectedDraw();
    final int count = _byRangeMode
        ? _rangePreview.totalCount
        : drawTickets.where((TicketItem t) => _tappedIds.contains(t.id)).length;
    final int creditPaise = count * (selectedDraw?.ticketPricePaise ?? 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (returnableDraws.isNotEmpty) ...<Widget>[
          SizedBox(
            height: AppSpacing.minTouchTarget,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: <Widget>[
                for (final LotteryDraw d in returnableDraws) ...<Widget>[
                  AppChip(
                    label:
                        '${d.lotteryName} (${AppFormatters.shortDate(d.drawDate)})',
                    selected: selectedDraw?.id == d.id,
                    onTap: () {
                      setState(() {
                        _selectedDrawId = d.id;
                        _tappedIds.clear();
                        _statusMessage = null;
                      });
                      _refreshRangePreview();
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
                label: l10n.returnModeBySelect,
                selected: !_byRangeMode,
                onTap: () => setState(() {
                  _byRangeMode = false;
                  _statusMessage = null;
                }),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: AppChip(
                label: l10n.returnModeByRange,
                selected: _byRangeMode,
                onTap: () {
                  setState(() {
                    _byRangeMode = true;
                    _statusMessage = null;
                  });
                  _refreshRangePreview();
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        if (_byRangeMode) ...<Widget>[
          AppTextField(
            label: l10n.seriesFieldLabel,
            controller: _seriesController,
            hintText: l10n.seriesFieldHint,
            useMonoFont: true,
            maxLength: 3,
            textCapitalization: TextCapitalization.characters,
            onChanged: (_) {
              setState(() => _statusMessage = null);
              _refreshRangePreview();
            },
          ),
          const SizedBox(height: AppSpacing.sm),
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
                  onChanged: (_) {
                    setState(() => _statusMessage = null);
                    _refreshRangePreview();
                  },
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
                  onChanged: (_) {
                    setState(() => _statusMessage = null);
                    _refreshRangePreview();
                  },
                ),
              ),
            ],
          ),
          if ((_rangePreview.rangesSummary ?? '').isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Text(
              '${l10n.nextTicketsPreviewLabel} ${_rangePreview.rangesSummary}',
              style: context.text.ticketMono.copyWith(color: colors.primary),
            ),
          ],
        ] else if (_isLoadingTickets)
          SkeletonLoader.list(itemCount: 2, itemHeight: 48)
        else if (drawTickets.isEmpty)
          Text(
            l10n.sellerTicketsEmptyTitle,
            style: context.text.caption.copyWith(color: colors.inkMuted),
          )
        else
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 168),
            child: SingleChildScrollView(
              child: Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: drawTickets.map((TicketItem t) {
                  final bool isChosen = _tappedIds.contains(t.id);
                  return AppChip(
                    label: '${t.series} ${t.number}',
                    selected: isChosen,
                    onTap: () => setState(() {
                      if (isChosen) {
                        _tappedIds.remove(t.id);
                      } else {
                        _tappedIds.add(t.id);
                      }
                      _statusMessage = null;
                    }),
                  );
                }).toList(),
              ),
            ),
          ),
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
              Text(
                l10n.ticketsCountLabel(AppFormatters.count(count)),
                style: context.text.h2,
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Text(
                    l10n.returnTotalCreditLabel,
                    style:
                        context.text.caption.copyWith(color: colors.inkMuted),
                  ),
                  MoneyText(
                    paise: creditPaise,
                    tone: MoneyTone.settled,
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
          label: l10n.confirmReturnTicketsAction,
          isLoading: sellersState.isSubmitting,
          onPressed: () => _submit(selectedDraw),
        ),
      ],
    );
  }
}
