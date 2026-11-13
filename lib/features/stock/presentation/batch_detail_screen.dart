import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/ui_kit.dart';
import '../../../l10n/app_localizations.dart';
import '../data/stock_repository.dart';
import '../domain/stock_entities.dart';
import 'mark_counter_sold_sheet.dart';
import 'stock_controller.dart';

/// Paginated Batch Ticket Grid Screen (§8.3, Phase 4 Audit #2).
/// Loads 200 tickets per page using server-side status/number filtering and `.range(...)`.
class BatchDetailScreen extends ConsumerStatefulWidget {
  const BatchDetailScreen({
    super.key,
    required this.batch,
  });

  final StockBatch batch;

  @override
  ConsumerState<BatchDetailScreen> createState() => _BatchDetailScreenState();
}

class _BatchDetailScreenState extends ConsumerState<BatchDetailScreen> {
  static const int _pageSize = 200;

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  TicketStatus? _selectedStatus;
  List<TicketItem> _tickets = <TicketItem>[];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadFirstPage();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_isLoadingMore || !_hasMore || !_scrollController.hasClients) {
      return;
    }
    final ScrollPosition pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 240) {
      _loadNextPage();
    }
  }

  Future<void> _loadFirstPage() async {
    setState(() {
      _isLoading = true;
      _hasMore = true;
    });
    try {
      final StockRepository repo = ref.read(stockRepositoryProvider);
      final List<TicketItem> page = await repo.fetchTicketsForBatch(
        widget.batch.id,
        status: _selectedStatus,
        searchNumber: _searchController.text,
        offset: 0,
        limit: _pageSize,
      );
      if (mounted) {
        setState(() {
          _tickets = page;
          _hasMore = page.length == _pageSize;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadNextPage() async {
    setState(() => _isLoadingMore = true);
    try {
      final StockRepository repo = ref.read(stockRepositoryProvider);
      final List<TicketItem> page = await repo.fetchTicketsForBatch(
        widget.batch.id,
        status: _selectedStatus,
        searchNumber: _searchController.text,
        offset: _tickets.length,
        limit: _pageSize,
      );
      if (mounted) {
        setState(() {
          _tickets = <TicketItem>[..._tickets, ...page];
          _hasMore = page.length == _pageSize;
          _isLoadingMore = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  Color _dotColor(TicketStatus status, AppColors colors) {
    switch (status) {
      case TicketStatus.inStock:
        return colors.primary;
      case TicketStatus.withSeller:
        return colors.warning;
      case TicketStatus.soldCounter:
      case TicketStatus.soldBySeller:
        return colors.success;
      case TicketStatus.returnedUnsold:
        return colors.inkFaint;
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppColors colors = context.colors;

    final List<TicketStatus?> filters = <TicketStatus?>[
      null,
      TicketStatus.inStock,
      TicketStatus.withSeller,
      TicketStatus.soldCounter,
      TicketStatus.returnedUnsold,
    ];

    String filterLabel(TicketStatus? st) {
      switch (st) {
        case null:
          return l10n.filterAll;
        case TicketStatus.inStock:
          return l10n.statusInStock;
        case TicketStatus.withSeller:
          return l10n.statusWithSeller;
        case TicketStatus.soldCounter:
        case TicketStatus.soldBySeller:
          return l10n.statusSold;
        case TicketStatus.returnedUnsold:
          return l10n.statusReturned;
      }
    }

    final LotteryDraw? draw = ref
        .watch(stockControllerProvider)
        .draws
        .cast<LotteryDraw?>()
        .firstWhere(
          (LotteryDraw? d) => d?.id == widget.batch.drawId,
          orElse: () => null,
        );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${widget.batch.series} ${widget.batch.startNumber}–${widget.batch.endNumber}',
          style: context.text.ticketMonoLarge,
        ),
        actions: <Widget>[
          if (draw != null && draw.status == DrawStatus.upcoming)
            IconButton(
              tooltip: l10n.counterSaleAction,
              icon: const Icon(Icons.storefront_outlined),
              onPressed: () async {
                await MarkCounterSoldSheet.show(
                  context: context,
                  draw: draw,
                  initialSeries: widget.batch.series,
                  initialStartNumber: widget.batch.startNumber,
                  initialEndNumber: widget.batch.endNumber,
                );
                await _loadFirstPage();
              },
            ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenHorizontal,
              AppSpacing.sm,
              AppSpacing.screenHorizontal,
              AppSpacing.sm,
            ),
            child: AppTextField(
              label: l10n.batchDetailTitle,
              controller: _searchController,
              hintText: l10n.searchHint,
              useMonoFont: true,
              keyboardType: TextInputType.number,
              onChanged: (_) => _loadFirstPage(),
            ),
          ),
          FilterChipRow<TicketStatus?>(
            items: filters,
            selectedItem: _selectedStatus,
            labelBuilder: filterLabel,
            onSelected: (TicketStatus? st) {
              setState(() => _selectedStatus = st);
              _loadFirstPage();
            },
          ),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: _isLoading
                ? Padding(
                    padding: AppSpacing.screenPadding,
                    child: SkeletonLoader.list(itemCount: 4, itemHeight: 56),
                  )
                : GridView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.screenHorizontal,
                      AppSpacing.xs,
                      AppSpacing.screenHorizontal,
                      AppSpacing.xxl,
                    ),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: AppSpacing.sm,
                      crossAxisSpacing: AppSpacing.sm,
                      childAspectRatio: 2.8,
                    ),
                    itemCount: _tickets.length,
                    itemBuilder: (BuildContext context, int index) {
                      final TicketItem ticket = _tickets[index];
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                        ),
                        decoration: BoxDecoration(
                          color: colors.surface,
                          borderRadius:
                              BorderRadius.circular(AppSpacing.buttonRadius),
                          border: Border.all(
                            color: colors.border,
                            width: AppSpacing.borderWidth,
                          ),
                        ),
                        child: Row(
                          children: <Widget>[
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: _dotColor(ticket.status, colors),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: TicketNumberText(
                                series: ticket.series,
                                number: ticket.number,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
