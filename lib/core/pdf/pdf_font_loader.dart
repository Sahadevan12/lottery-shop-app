import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/widgets.dart' as pw;

class PdfIndicImage {
  const PdfIndicImage({
    required this.rgbaBytes,
    required this.width,
    required this.height,
  });

  final Uint8List rgbaBytes;
  final int width;
  final int height;
}

class PdfIndicRow {
  const PdfIndicRow({
    required this.label,
    required this.value,
    this.bold = false,
    this.dividerBefore = false,
  });

  final String label;
  final String value;
  final bool bold;
  final bool dividerBefore;
}

/// Bundles Inter, Noto Sans Malayalam, Noto Sans Tamil, and JetBrains Mono
/// fonts into the `pdf` package and renders Indic (Malayalam/Tamil) PDF
/// sections via Flutter's HarfBuzz text shaper (`TextPainter` -> PNG) so
/// complex conjuncts never break in `pdf`.
abstract final class PdfFontLoader {
  static pw.ThemeData? _cachedTheme;

  /// Optional test hook for headless `flutter_test` environments where
  /// `ui.Image.toByteData` has no rasterizer surface.
  @visibleForTesting
  static Future<PdfIndicImage> Function({
    required String title,
    required String subtitle,
    required List<PdfIndicRow> rows,
    String? sectionHeading,
    List<PdfIndicRow> secondaryRows,
    String? footer,
    required String languageCode,
  })? testIndicRenderer;

  static Future<pw.ThemeData> loadTheme() async {
    if (_cachedTheme != null) {
      return _cachedTheme!;
    }
    final pw.Font interRegular = pw.Font.ttf(
      await rootBundle.load('assets/fonts/Inter-Regular.ttf'),
    );
    final pw.Font interBold = pw.Font.ttf(
      await rootBundle.load('assets/fonts/Inter-Bold.ttf'),
    );
    final pw.Font malayalam = pw.Font.ttf(
      await rootBundle.load('assets/fonts/NotoSansMalayalam-Regular.ttf'),
    );
    final pw.Font tamil = pw.Font.ttf(
      await rootBundle.load('assets/fonts/NotoSansTamil-Regular.ttf'),
    );
    final pw.Font mono = pw.Font.ttf(
      await rootBundle.load('assets/fonts/JetBrainsMono-Regular.ttf'),
    );

    _cachedTheme = pw.ThemeData.withFont(
      base: interRegular,
      bold: interBold,
      fontFallback: <pw.Font>[malayalam, tamil, mono],
    );
    return _cachedTheme!;
  }

  /// Renders a structured report/statement section in Malayalam or Tamil to
  /// high-DPI raw RGBA bytes using Flutter's HarfBuzz text shaper.
  static Future<PdfIndicImage> renderIndicSection({
    required String title,
    required String subtitle,
    required List<PdfIndicRow> rows,
    String? sectionHeading,
    List<PdfIndicRow> secondaryRows = const <PdfIndicRow>[],
    String? footer,
    required String languageCode,
  }) async {
    if (testIndicRenderer != null) {
      return testIndicRenderer!(
        title: title,
        subtitle: subtitle,
        rows: rows,
        sectionHeading: sectionHeading,
        secondaryRows: secondaryRows,
        footer: footer,
        languageCode: languageCode,
      );
    }
    const double width = 1120;
    const double pad = 40;
    const double contentWidth = width - pad * 2;
    final String fontFamily =
        languageCode == 'ta' ? 'NotoSansTamil' : 'NotoSansMalayalam';

    TextPainter makePainter(
      String text, {
      double fontSize = 26,
      FontWeight weight = FontWeight.w400,
      Color color = const Color(0xFF14181F),
      double maxWidth = contentWidth,
      TextAlign align = TextAlign.left,
    }) {
      final TextPainter tp = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            fontFamily: fontFamily,
            fontFamilyFallback: const <String>[
              'NotoSansMalayalam',
              'NotoSansTamil',
              'Inter',
            ],
            fontSize: fontSize,
            fontWeight: weight,
            color: color,
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: align,
      );
      tp.layout(maxWidth: maxWidth);
      return tp;
    }

    // Measure total height first.
    double y = pad;
    final TextPainter titleTp = makePainter(
      title,
      fontSize: 36,
      weight: FontWeight.w700,
    );
    y += titleTp.height + 8;

    final TextPainter subTp = makePainter(
      subtitle,
      fontSize: 24,
      color: const Color(0xFF5A6475),
    );
    y += subTp.height + 28;

    final List<({PdfIndicRow row, TextPainter left, TextPainter right})>
        measuredPrimary =
        <({PdfIndicRow row, TextPainter left, TextPainter right})>[];
    for (final PdfIndicRow r in rows) {
      if (r.dividerBefore) {
        y += 16;
      }
      final TextPainter left = makePainter(
        r.label,
        fontSize: r.bold ? 28 : 25,
        weight: r.bold ? FontWeight.w700 : FontWeight.w500,
        maxWidth: contentWidth * 0.68,
      );
      final TextPainter right = makePainter(
        r.value,
        fontSize: r.bold ? 28 : 25,
        weight: r.bold ? FontWeight.w700 : FontWeight.w600,
        maxWidth: contentWidth * 0.30,
        align: TextAlign.right,
      );
      measuredPrimary.add((row: r, left: left, right: right));
      y += (left.height > right.height ? left.height : right.height) + 14;
    }

    TextPainter? secHeadingTp;
    final List<({PdfIndicRow row, TextPainter left, TextPainter right})>
        measuredSecondary =
        <({PdfIndicRow row, TextPainter left, TextPainter right})>[];
    if (sectionHeading != null && secondaryRows.isNotEmpty) {
      y += 22;
      secHeadingTp = makePainter(
        sectionHeading,
        fontSize: 28,
        weight: FontWeight.w700,
      );
      y += secHeadingTp.height + 12;
      for (final PdfIndicRow r in secondaryRows) {
        final TextPainter left = makePainter(
          r.label,
          fontSize: 23,
          maxWidth: contentWidth * 0.68,
        );
        final TextPainter right = makePainter(
          r.value,
          fontSize: 23,
          weight: FontWeight.w600,
          maxWidth: contentWidth * 0.30,
          align: TextAlign.right,
        );
        measuredSecondary.add((row: r, left: left, right: right));
        y += (left.height > right.height ? left.height : right.height) + 12;
      }
    }

    TextPainter? footerTp;
    if (footer != null && footer.isNotEmpty) {
      y += 20;
      footerTp = makePainter(
        footer,
        fontSize: 20,
        color: const Color(0xFF5A6475),
      );
      y += footerTp.height;
    }
    y += pad;

    final int heightInt = y.ceil();
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);
    final Paint bgPaint = Paint()..color = const Color(0xFFFFFFFF);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, width, heightInt.toDouble()),
      bgPaint,
    );
    final Paint linePaint = Paint()
      ..color = const Color(0xFFD0D5DD)
      ..strokeWidth = 2;

    double drawY = pad;
    titleTp.paint(canvas, Offset(pad, drawY));
    drawY += titleTp.height + 8;

    subTp.paint(canvas, Offset(pad, drawY));
    drawY += subTp.height + 14;
    canvas.drawLine(Offset(pad, drawY), Offset(width - pad, drawY), linePaint);
    drawY += 14;

    void paintRows(
      List<({PdfIndicRow row, TextPainter left, TextPainter right})> items,
    ) {
      for (final item in items) {
        if (item.row.dividerBefore) {
          canvas.drawLine(
            Offset(pad, drawY + 6),
            Offset(width - pad, drawY + 6),
            linePaint,
          );
          drawY += 16;
        }
        item.left.paint(canvas, Offset(pad, drawY));
        item.right.paint(
          canvas,
          Offset(width - pad - item.right.width, drawY),
        );
        final double rowH = item.left.height > item.right.height
            ? item.left.height
            : item.right.height;
        drawY += rowH + 14;
      }
    }

    paintRows(measuredPrimary);

    if (secHeadingTp != null) {
      drawY += 22;
      secHeadingTp.paint(canvas, Offset(pad, drawY));
      drawY += secHeadingTp.height + 12;
      paintRows(measuredSecondary);
    }

    if (footerTp != null) {
      drawY += 20;
      footerTp.paint(canvas, Offset(pad, drawY));
    }

    final ui.Picture picture = recorder.endRecording();
    final ui.Image image = picture.toImageSync(width.toInt(), heightInt);
    final ByteData? byteData =
        await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    return PdfIndicImage(
      rgbaBytes: byteData!.buffer.asUint8List(),
      width: width.toInt(),
      height: heightInt,
    );
  }
}
