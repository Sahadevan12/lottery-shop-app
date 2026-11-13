import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/utils/formatters.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/seller_entities.dart';

/// Generates and shares a PDF khata statement for a seller (§8.4).
abstract final class SellerStatementShare {
  static Future<void> shareStatement({
    required SellerProfile seller,
    required SellerBalanceBreakdown breakdown,
    required List<LedgerEntry> entries,
    required AppLocalizations l10n,
  }) async {
    final Uint8List pdfBytes = await buildPdfBytes(
      seller: seller,
      breakdown: breakdown,
      entries: entries,
      l10n: l10n,
    );
    final String safeName =
        seller.name.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    await Printing.sharePdf(
      bytes: pdfBytes,
      filename: 'khata_$safeName.pdf',
    );
  }

  static Future<Uint8List> buildPdfBytes({
    required SellerProfile seller,
    required SellerBalanceBreakdown breakdown,
    required List<LedgerEntry> entries,
    required AppLocalizations l10n,
  }) async {
    final pw.Document doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return <pw.Widget>[
            pw.Text(
              '${l10n.appName} — ${l10n.sellerStatementTitle}',
              style: const pw.TextStyle(
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 6),
            pw.Text(
              <String>[
                seller.name,
                if (seller.area != null && seller.area!.isNotEmpty)
                  seller.area!,
                if (seller.phone != null && seller.phone!.isNotEmpty)
                  seller.phone!,
              ].join(' · '),
              style: const pw.TextStyle(fontSize: 12),
            ),
            pw.SizedBox(height: 12),
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey400),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: <pw.Widget>[
                  pw.Text(
                    l10n.breakdownGrandTotal,
                    style: const pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    AppFormatters.moneyFromPaise(breakdown.grandTotalPaise),
                    style: const pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 16),
            pw.Text(
              l10n.sellerTabLedger,
              style: const pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 8),
            pw.TableHelper.fromTextArray(
              headers: <String>[
                'Date',
                'Type',
                'Details',
                'Amount',
              ],
              data: entries.take(50).map((LedgerEntry e) {
                return <String>[
                  AppFormatters.shortDate(e.createdAt.toLocal()),
                  e.type.dbValue,
                  e.note ?? '',
                  AppFormatters.moneyFromPaise(e.amountPaise, showSign: true),
                ];
              }).toList(),
            ),
            pw.SizedBox(height: 20),
            pw.Text(
              l10n.legalDisclaimer,
              style: const pw.TextStyle(
                fontSize: 9,
                color: PdfColors.grey700,
              ),
            ),
          ];
        },
      ),
    );

    return doc.save();
  }
}
