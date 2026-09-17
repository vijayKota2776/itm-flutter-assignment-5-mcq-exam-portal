import 'package:flutter/material.dart';
import '../../models/result_model.dart';
import '../../services/pdf_service.dart';
import '../../theme/app_theme.dart';

class ExamResultScreen extends StatelessWidget {
  final ResultModel result;

  const ExamResultScreen({super.key, required this.result});

  void _handleDownloadPdf(BuildContext context) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Preparing Result PDF Scorecard...')),
    );

    if (result.resultPdfUrl.isNotEmpty) {
      final success = await PdfService.downloadOrPrintFromUrl(
        result.resultPdfUrl,
        'ITM_Result_${result.examTitle.replaceAll(' ', '_')}.pdf',
      );
      if (!success) {
        await PdfService.printResultLocally(result);
      }
    } else {
      await PdfService.printResultLocally(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPass = result.isPass;
    final statusColor = isPass ? AppTheme.statusGreen : AppTheme.statusRed;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Examination Results'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            // Safely pop back to dashboard
            Navigator.of(context).popUntil((route) => route.isFirst);
          },
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ElevatedButton.icon(
              onPressed: () => _handleDownloadPdf(context),
              icon: const Icon(Icons.download, size: 16),
              label: const Text('Download PDF'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 880),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Score Banner Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            result.status,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: statusColor,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          result.examTitle,
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                        Text(
                          'Subject: ${result.subject}',
                          style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                        ),
                        const SizedBox(height: 24),

                        // Score Grid
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildScoreMetric('Score', '${result.score} / ${result.totalMarks}', statusColor),
                            _buildScoreMetric('Percentage', '${result.percentage}%', AppTheme.royalBlue),
                            _buildScoreMetric('Grade', result.grade, AppTheme.statusPurple),
                          ],
                        ),

                        const Divider(height: 36),

                        // Stat Pills (Correct, Wrong, Unattempted, Time)
                        Wrap(
                          spacing: 16,
                          runSpacing: 10,
                          alignment: WrapAlignment.center,
                          children: [
                            _buildStatPill(Icons.check_circle, 'Correct: ${result.correct}', AppTheme.statusGreen),
                            _buildStatPill(Icons.cancel, 'Wrong: ${result.wrong}', AppTheme.statusRed),
                            _buildStatPill(Icons.help_outline, 'Unattempted: ${result.unattempted}', AppTheme.statusAmber),
                            _buildStatPill(
                              Icons.timer_outlined,
                              'Time: ${result.timeTaken ~/ 60}m ${result.timeTaken % 60}s',
                              AppTheme.textSecondary,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 28),

                // Question-Wise Analysis
                const Text(
                  'Question-by-Question Analysis',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy),
                ),
                const SizedBox(height: 12),

                ...result.questionAnalysis.map((q) => _buildQuestionAnalysisCard(q)),

                const SizedBox(height: 28),

                // Return to Dashboard Action Button
                SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    },
                    icon: const Icon(Icons.home_outlined),
                    label: const Text('Return to Examination Dashboard', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryNavy,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScoreMetric(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: color),
        ),
        const SizedBox(height: 4),
        Text(
          label.toUpperCase(),
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.textMuted, letterSpacing: 0.5),
        ),
      ],
    );
  }

  Widget _buildStatPill(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(text, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: color)),
        ],
      ),
    );
  }

  Widget _buildQuestionAnalysisCard(QuestionAnalysisModel q) {
    Color cardBorder;
    IconData statusIcon;
    Color iconColor;

    if (q.isCorrect) {
      cardBorder = AppTheme.statusGreen.withValues(alpha: 0.4);
      statusIcon = Icons.check_circle;
      iconColor = AppTheme.statusGreen;
    } else if (q.isWrong) {
      cardBorder = AppTheme.statusRed.withValues(alpha: 0.4);
      statusIcon = Icons.cancel;
      iconColor = AppTheme.statusRed;
    } else {
      cardBorder = AppTheme.borderLight;
      statusIcon = Icons.remove_circle_outline;
      iconColor = AppTheme.statusGray;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: cardBorder, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: AppTheme.royalBlue,
                      child: Text('${q.questionNo}', style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 10),
                    Icon(statusIcon, size: 18, color: iconColor),
                    const SizedBox(width: 6),
                    Text(
                      q.status,
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: iconColor),
                    ),
                  ],
                ),
                Text(
                  '${q.marksAwarded >= 0 ? '+' : ''}${q.marksAwarded} Marks',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: q.marksAwarded > 0 ? AppTheme.statusGreen : (q.marksAwarded < 0 ? AppTheme.statusRed : AppTheme.textSecondary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              q.question,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 14),

            // Options List
            ...['A', 'B', 'C', 'D'].map((key) {
              final isCorrectKey = key == q.correctAnswer;
              final isStudentKey = key == q.studentAnswer;

              Color optBg = Colors.transparent;
              Color optBorder = AppTheme.borderLight;
              FontWeight fw = FontWeight.normal;

              if (isCorrectKey) {
                optBg = AppTheme.statusGreen.withValues(alpha: 0.1);
                optBorder = AppTheme.statusGreen;
                fw = FontWeight.bold;
              } else if (isStudentKey && !isCorrectKey) {
                optBg = AppTheme.statusRed.withValues(alpha: 0.1);
                optBorder = AppTheme.statusRed;
                fw = FontWeight.bold;
              }

              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: optBg,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: optBorder),
                ),
                child: Row(
                  children: [
                    Text('$key: ', style: TextStyle(fontWeight: FontWeight.bold, color: isCorrectKey ? AppTheme.statusGreen : AppTheme.textPrimary)),
                    Expanded(child: Text(q.options[key] ?? '', style: TextStyle(fontWeight: fw))),
                    if (isStudentKey && isCorrectKey)
                      const Text('(Your Answer - Correct)', style: TextStyle(fontSize: 11, color: AppTheme.statusGreen, fontWeight: FontWeight.bold))
                    else if (isStudentKey)
                      const Text('(Your Answer)', style: TextStyle(fontSize: 11, color: AppTheme.statusRed, fontWeight: FontWeight.bold))
                    else if (isCorrectKey)
                      const Text('(Correct Answer)', style: TextStyle(fontSize: 11, color: AppTheme.statusGreen, fontWeight: FontWeight.bold)),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
