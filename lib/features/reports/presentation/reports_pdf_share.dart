import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/pdf/pdf_font_loader.dart';
import '../../../core/utils/formatters.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/report_entities.dart';

/// Generates and shares multilingual P&L report PDFs.
/// English uses selectable `pw.Text`; Malayalam (`ml`) and Tamil (`ta`)
/// render Indic sections via Flutter's HarfBuzz text shaper into PNGs
/// embedded as `pw.Image` so conjuncts never break.
abstract final class ReportsPdfShare {
  static bool _isIndicLocale(Locale locale) =>
      locale.languageCode == 'ml' || locale.languageCode == 'ta';

  static Future<Uint8List> buildPdfBytes({
    required ReportsSummaryData summary,
    required AppLocalizations l10n,
    required Locale locale,
    required String shopName,
    BuildContext? context,
  }) async {
    final pw.ThemeData theme = await PdfFontLoader.loadTheme();
    final pw.Document doc = pw.Document(theme: theme);

    if (_isIndicLocale(locale)) {
      final PdfIndicImage indicImg = await PdfFontLoader.renderIndicSection(
        languageCode: locale.languageCode,
        title: shopName,
        subtitle:
            '${l10n.reportsTitle} · ${AppFormatters.shortDate(summary.fromDate)} - ${AppFormatters.shortDate(summary.toDate)}',
        rows: <PdfIndicRow>[
          PdfIndicRow(
            label: l10n.pnlSalesLabel,
            value: AppFormatters.moneyFromRupees(summary.totalSales.round()),
          ),
          PdfIndicRow(
            label: l10n.pnlStockCostLabel,
            value: AppFormatters.moneyFromRupees(summary.totalStockCost.round()),
          ),
          PdfIndicRow(
            label: l10n.pnlGrossMarginLabel,
            value: AppFormatters.moneyFromRupees(
              summary.totalGrossMargin.round(),
            ),
          ),
          PdfIndicRow(
            label: l10n.pnlUnsoldGainLabel,
            value: AppFormatters.moneyFromRupees(
              summary.totalUnsoldPrizeGain.round(),
            ),
          ),
          PdfIndicRow(
            label: l10n.pnlNetProfitLabel,
            value: AppFormatters.moneyFromRupees(summary.totalNetProfit.round()),
            bold: true,
            dividerBefore: true,
          ),
          PdfIndicRow(
            label: l10n.pnlToRecoverOfficeLabel,
            value: AppFormatters.moneyFromRupees(
              summary.totalToRecoverFromOffice.round(),
            ),
            dividerBefore: true,
          ),
          PdfIndicRow(
            label: l10n.pnlToCollectSellersLabel,
            value: AppFormatters.moneyFromRupees(
              summary.toCollectFromSellers.round(),
            ),
          ),
        ],
        sectionHeading:
            summary.draws.isNotEmpty ? l10n.pnlDrawBreakdownTitle : null,
        secondaryRows: summary.draws
            .take(15)
            .map(
              (DrawPnlRow d) => PdfIndicRow(
                label:
                    '${d.lotteryName} (${d.drawNumber}) · ${d.ticketsSoldTotal}/${d.ticketsBought}',
                value: AppFormatters.moneyFromRupees(d.netProfit.round()),
              ),
            )
            .toList(growable: false),
        footer: l10n.legalDisclaimer,
      );

      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(24),
          build: (pw.Context ctx) => pw.Image(
            pw.RawImage(
              bytes: indicImg.rgbaBytes,
              width: indicImg.width,
              height: indicImg.height,
            ),
            fit: pw.BoxFit.contain,
          ),
        ),
      );
    } else {
      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(28),
          build: (pw.Context ctx) => <pw.Widget>[
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: <pw.Widget>[
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: <pw.Widget>[
                      pw.Text(
                        shopName,
                        style: const pw.TextStyle(
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        l10n.reportsTitle,
                        style: const pw.TextStyle(
                          fontSize: 12,
                          color: PdfColors.grey700,
                        ),
                      ),
                    ],
                  ),
                  pw.Text(
                    '${AppFormatters.shortDate(summary.fromDate)} - ${AppFormatters.shortDate(summary.toDate)}',
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 10),
            _pdfSummaryRow(l10n.pnlSalesLabel, summary.totalSales),
            _pdfSummaryRow(l10n.pnlStockCostLabel, summary.totalStockCost),
            _pdfSummaryRow(l10n.pnlGrossMarginLabel, summary.totalGrossMargin),
            _pdfSummaryRow(
              l10n.pnlUnsoldGainLabel,
              summary.totalUnsoldPrizeGain,
            ),
            pw.Divider(),
            _pdfSummaryRow(
              l10n.pnlNetProfitLabel,
              summary.totalNetProfit,
              bold: true,
            ),
            pw.SizedBox(height: 10),
            _pdfSummaryRow(
              l10n.pnlToRecoverOfficeLabel,
              summary.totalToRecoverFromOffice,
            ),
            _pdfSummaryRow(
              l10n.pnlToCollectSellersLabel,
              summary.toCollectFromSellers,
            ),
            if (summary.draws.isNotEmpty) ...<pw.Widget>[
              pw.SizedBox(height: 16),
              pw.Text(
                l10n.pnlDrawBreakdownTitle,
                style: const pw.TextStyle(
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 6),
              pw.TableHelper.fromTextArray(
                headerStyle: const pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                ),
                cellStyle: const pw.TextStyle(fontSize: 9),
                headers: <String>[
                  'Draw',
                  'Sold / Bought',
                  l10n.pnlSalesLabel,
                  l10n.pnlStockCostLabel,
                  l10n.pnlUnsoldGainLabel,
                  l10n.pnlNetProfitLabel,
                ],
                data: summary.draws
                    .map(
                      (DrawPnlRow d) => <String>[
                        '${d.lotteryName} (${d.drawNumber})',
                        '${d.ticketsSoldTotal}/${d.ticketsBought}',
                        AppFormatters.moneyFromRupees(d.sales.round()),
                        AppFormatters.moneyFromRupees(d.stockCost.round()),
                        AppFormatters.moneyFromRupees(
                          d.unsoldPrizeGain.round(),
                        ),
                        AppFormatters.moneyFromRupees(d.netProfit.round()),
                      ],
                    )
                    .toList(growable: false),
              ),
            ],
          ],
        ),
      );
    }

    return doc.save();
  }

  static pw.Widget _pdfSummaryRow(
    String label,
    double amount, {
    bool bold = false,
  }) {
    final pw.TextStyle style = pw.TextStyle(
      fontSize: bold ? 12 : 10,
      fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
    );
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: <pw.Widget>[
          pw.Text(label, style: style),
          pw.Text(AppFormatters.moneyFromRupees(amount.round()), style: style),
        ],
      ),
    );
  }

  static Future<void> sharePdf({
    required BuildContext context,
    required ReportsSummaryData summary,
    required AppLocalizations l10n,
    required Locale locale,
    required String shopName,
  }) async {
    final Uint8List bytes = await buildPdfBytes(
      summary: summary,
      l10n: l10n,
      locale: locale,
      shopName: shopName,
      context: context,
    );
    await Printing.sharePdf(
      bytes: bytes,
      filename:
          'luckyledger_report_${AppFormatters.shortDate(summary.fromDate).replaceAll(' ', '_')}.pdf',
    );
  }
}
