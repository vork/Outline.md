import 'dart:io';

import 'package:docx_to_text/docx_to_text.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

class DocImportService {
  /// Import a PDF file and convert to markdown.
  Future<String> importPdf(String filePath) async {
    final bytes = await File(filePath).readAsBytes();
    final document = PdfDocument(inputBytes: bytes);

    final buffer = StringBuffer();
    final pageCount = document.pages.count;

    for (int i = 0; i < pageCount; i++) {
      final text = PdfTextExtractor(document).extractText(startPageIndex: i, endPageIndex: i);
      if (text.trim().isNotEmpty) {
        buffer.writeln(text);
        buffer.writeln();
      }
    }

    document.dispose();

    final content = buffer.toString().trim();
    if (content.isEmpty) {
      throw Exception('No text content found in PDF');
    }

    return content;
  }

  /// Import a DOCX file and convert to markdown.
  Future<String> importDocx(String filePath) async {
    final bytes = await File(filePath).readAsBytes();
    final text = docxToText(bytes);

    if (text.trim().isEmpty) {
      throw Exception('No text content found in document');
    }

    return text;
  }

  /// Detect file type and import accordingly.
  Future<String> importFile(String filePath) async {
    final lower = filePath.toLowerCase();
    if (lower.endsWith('.pdf')) {
      return importPdf(filePath);
    } else if (lower.endsWith('.docx') || lower.endsWith('.doc')) {
      return importDocx(filePath);
    }
    throw ArgumentError('Unsupported file type: $filePath');
  }
}
