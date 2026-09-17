import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:http/http.dart' as http;
import '../models/result_model.dart';

class PdfService {
  /// Opens the PDF print / download dialog using the Cloudinary secure URL
  static Future<bool> downloadOrPrintFromUrl(String pdfUrl, String fileName) async {
    try {
      if (pdfUrl.isEmpty) return false;
      final response = await http.get(Uri.parse(pdfUrl));
      if (response.statusCode == 200) {
        await Printing.layoutPdf(
          onLayout: (format) async => response.bodyBytes,
          name: fileName,
        );
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Direct print layout for a ResultModel using client-side rendering if offline
  static Future<void> printResultLocally(ResultModel result) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              // Header
              pw.Container(
                color: PdfColor.fromHex('#0F172A'),
                padding: const pw.EdgeInsets.all(16),
                child: pw.Column(
                  children: [
                    pw.Text(
                      'ITM SKILLS UNIVERSITY',
                      style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'EXAMINATION RESULT SCORECARD',
                      style: const pw.TextStyle(color: PdfColors.white, fontSize: 10),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // Student Details Card
              pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColor.fromHex('#CBD5E1')),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                ),
                padding: const pw.EdgeInsets.all(12),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Student Name: ${result.studentName}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.Text('Exam Title: ${result.examTitle} (${result.subject})'),
                    pw.Text('Date: ${result.submittedAt}'),
                  ],
                ),
              ),
              pw.SizedBox(height: 16),

              // Score Details
              pw.Container(
                color: PdfColor.fromHex('#F8FAFC'),
                padding: const pw.EdgeInsets.all(16),
                child: pw.Column(
                  children: [
                    pw.Text(
                      'Score: ${result.score} / ${result.totalMarks} (${result.percentage}%)',
                      style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: result.isPass ? PdfColors.green : PdfColors.red),
                    ),
                    pw.SizedBox(height: 6),
                    pw.Text('Status: ${result.status} | Grade: ${result.grade}'),
                    pw.SizedBox(height: 6),
                    pw.Text('Correct: ${result.correct} | Wrong: ${result.wrong} | Unattempted: ${result.unattempted}'),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name: 'ITM_Result_${result.examTitle.replaceAll(' ', '_')}.pdf',
    );
  }
}
