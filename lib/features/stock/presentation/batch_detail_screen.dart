import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/ui_kit.dart';
import '../../../l10n/app_localizations.dart';
import '../data/stock_repository.dart';
import '../domain/stock_entities.dart';
import 'stock_controller.dart';

/// Read-only Batch Ticket Grid Screen (§8.3, Phase 2 Requirement #6).
/// Displays mono ticket numbers with a semantic status dot, search, and status filter chips.
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
  final TextEditingController _searchController = TextEditingController();
  TicketStatus? _selectedStatus;
  List<TicketItem> _tickets = const <TicketItem>[];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTickets();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTickets() async {
    setState(() => _isLoading = true);
    try {
      final StockRepository repo = ref.read(stockRepositoryProvider);
      final List<TicketItem> list =
          await repo.fetchTicketsForBatch(widget.batch.id);
      if (mounted) {
        setState(() {
          _tickets = list;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
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
    final String query = _searchController.text.trim();

    final List<TicketItem> filtered = _tickets.where((TicketItem t) {
      if (_selectedStatus != null) {
        if (_selectedStatus == TicketStatus.soldCounter) {
          final bool isSold = t.status == TicketStatus.soldCounter ||
              t.status == TicketStatus.soldBySeller;
          if (!isSold) {
            return false;
          }
        } else if (t.status != _selectedStatus) {
          return false;
        }
      }
      if (query.isNotEmpty && !t.number.contains(query)) {
        return false;
      }
      return true;
    }).toList();

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

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${widget.batch.series} ${widget.batch.startNumber}–${widget.batch.endNumber}',
          style: context.text.ticketMonoLarge,
        ),
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
              onChanged: (_) => setState(() {}),
            ),
          ),
          FilterChipRow<TicketStatus?>(
            items: filters,
            selectedItem: _selectedStatus,
            labelBuilder: filterLabel,
            onSelected: (TicketStatus? st) =>
                setState(() => _selectedStatus = st),
          ),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: _isLoading
                ? Padding(
                    padding: AppSpacing.screenPadding,
                    child: SkeletonLoader.list(itemCount: 4, itemHeight: 56),
                  )
                : GridView.builder(
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
                    itemCount: filtered.length,
                    itemBuilder: (BuildContext context, int index) {
                      final TicketItem ticket = filtered[index];
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
