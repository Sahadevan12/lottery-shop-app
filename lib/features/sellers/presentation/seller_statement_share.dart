import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/pdf/pdf_font_loader.dart';
import '../../../core/utils/formatters.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/seller_entities.dart';

/// Generates and shares a PDF khata statement for a seller (§8.4).
/// English uses selectable `pw.Text`; Malayalam (`ml`) and Tamil (`ta`)
/// render Indic sections via Flutter's HarfBuzz text shaper into PNGs
/// embedded in the PDF so conjuncts never break.
abstract final class SellerStatementShare {
  static String _resolvedLanguageCode(Locale? locale, AppLocalizations l10n) {
    final String raw = locale?.languageCode ?? l10n.localeName;
    if (raw.startsWith('ml')) {
      return 'ml';
    }
    if (raw.startsWith('ta')) {
      return 'ta';
    }
    return 'en';
  }

  static Future<void> shareStatement({
    required SellerProfile seller,
    required SellerBalanceBreakdown breakdown,
    required List<LedgerEntry> entries,
    required AppLocalizations l10n,
    Locale? locale,
    BuildContext? context,
  }) async {
    final Uint8List pdfBytes = await buildPdfBytes(
      seller: seller,
      breakdown: breakdown,
      entries: entries,
      l10n: l10n,
      locale: locale,
      context: context,
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
    Locale? locale,
    BuildContext? context,
  }) async {
    final pw.ThemeData theme = await PdfFontLoader.loadTheme();
    final pw.Document doc = pw.Document(theme: theme);
    final String langCode = _resolvedLanguageCode(locale, l10n);

    if (langCode == 'ml' || langCode == 'ta') {
      final String subtitle = <String>[
        seller.name,
        if (seller.area != null && seller.area!.isNotEmpty) seller.area!,
        if (seller.phone != null && seller.phone!.isNotEmpty) seller.phone!,
      ].join(' · ');

      final PdfIndicImage indicImg = await PdfFontLoader.renderIndicSection(
        languageCode: langCode,
        title: '${l10n.appName} — ${l10n.sellerStatementTitle}',
        subtitle: subtitle,
        rows: <PdfIndicRow>[
          PdfIndicRow(
            label: l10n.breakdownGrandTotal,
            value: AppFormatters.moneyFromPaise(breakdown.grandTotalPaise),
            bold: true,
          ),
        ],
        sectionHeading: l10n.sellerTabLedger,
        secondaryRows: entries
            .take(20)
            .map(
              (LedgerEntry e) => PdfIndicRow(
                label:
                    '${AppFormatters.shortDate(e.createdAt.toLocal())} · ${e.note ?? e.type.dbValue}',
                value:
                    AppFormatters.moneyFromPaise(e.amountPaise, showSign: true),
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
      return doc.save();
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context ctx) {
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
              headers: const <String>[
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
