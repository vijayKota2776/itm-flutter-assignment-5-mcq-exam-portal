import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/attempt_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/question_palette.dart';
import '../../widgets/timer_widget.dart';
import 'exam_result_screen.dart';

class ExamInterfaceScreen extends StatefulWidget {
  final String examId;

  const ExamInterfaceScreen({super.key, required this.examId});

  @override
  State<ExamInterfaceScreen> createState() => _ExamInterfaceScreenState();
}

class _ExamInterfaceScreenState extends State<ExamInterfaceScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final attempt = Provider.of<AttemptProvider>(context, listen: false);

      // Set up auto submit on time expiration
      attempt.onTimeExpired = () {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Time has expired! Your exam was automatically evaluated.'),
              backgroundColor: AppTheme.statusRed,
              duration: Duration(seconds: 4),
            ),
          );
          _navigateToResult();
        }
      };

      final success = await attempt.startExam(widget.examId);
      if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(attempt.errorMessage ?? 'Unable to start examination.'),
            backgroundColor: AppTheme.statusRed,
          ),
        );
        Navigator.pop(context);
      }
    });
  }

  void _navigateToResult() {
    final attempt = Provider.of<AttemptProvider>(context, listen: false);
    if (attempt.lastResult != null && mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ExamResultScreen(result: attempt.lastResult!),
        ),
      );
    }
  }

  Future<void> _confirmAndSubmit() async {
    final attempt = Provider.of<AttemptProvider>(context, listen: false);
    final answered = attempt.answeredCount;
    final total = attempt.totalQuestions;
    final unattempted = total - answered;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Submit Examination?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('You are about to submit your examination.', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text('• Questions Answered: $answered / $total'),
            Text(
              '• Questions Unattempted: $unattempted',
              style: TextStyle(color: unattempted > 0 ? AppTheme.statusRed : AppTheme.statusGreen),
            ),
            const SizedBox(height: 12),
            const Text(
              'Once submitted, you will not be able to modify your answers.',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Return to Exam'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.statusGreen),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm & Submit'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      // Show evaluating dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const PopScope(
          canPop: false,
          child: Center(
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Evaluating answers & generating scorecard...', style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      final success = await attempt.submitExam();
      if (mounted) {
        Navigator.pop(context); // Close evaluation dialog
      }

      if (success && mounted) {
        _navigateToResult();
      } else if (mounted && attempt.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(attempt.errorMessage!),
            backgroundColor: AppTheme.statusRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final attempt = Provider.of<AttemptProvider>(context);
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 900;

    if (attempt.isLoading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Initializing secure examination session...', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      );
    }

    if (attempt.questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Examination')),
        body: const Center(child: Text('No questions found for this exam.')),
      );
    }

    final currentQ = attempt.currentQuestion!;
    final selectedOption = attempt.answers[currentQ.id];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldExit = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Exit Examination?'),
            content: const Text('Your timer is still running on the server. Are you sure you want to return to the dashboard? Your answers are automatically saved.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Stay in Exam')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.statusRed),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Exit to Dashboard'),
              ),
            ],
          ),
        );
        if (shouldExit == true && context.mounted) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false, // Protected exit via PopScope
          title: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      attempt.attempt?.exam.title ?? 'MCQ Examination',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Question ${attempt.currentIndex + 1} of ${attempt.totalQuestions}  •  Answered: ${attempt.answeredCount}',
                      style: const TextStyle(fontSize: 11, color: Colors.white70),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Countdown Timer
              TimerWidget(remainingSeconds: attempt.remainingSeconds),
              const SizedBox(width: 12),
              // Autosave indicator
              if (attempt.autosaveMessage != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: Colors.white12,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    attempt.autosaveMessage!,
                    style: const TextStyle(fontSize: 11, color: Colors.white70),
                  ),
                ),
              // Submit Exam Button
              ElevatedButton(
                onPressed: attempt.isSubmitting ? null : _confirmAndSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.statusGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                child: attempt.isSubmitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text('Submit Exam'),
              ),
            ],
          ),
        ),
        endDrawer: !isDesktop
            ? Drawer(
                child: SafeArea(
                  child: QuestionPalette(
                    totalQuestions: attempt.totalQuestions,
                    currentIndex: attempt.currentIndex,
                    onSelectQuestion: (idx) {
                      attempt.goToQuestion(idx);
                      Navigator.pop(context);
                    },
                    getState: attempt.getPaletteState,
                  ),
                ),
              )
            : null,
        body: Row(
          children: [
            // Main Question Area
            Expanded(
              flex: 3,
              child: Column(
                children: [
                  // Question Progress Indicator Bar
                  LinearProgressIndicator(
                    value: (attempt.currentIndex + 1) / attempt.totalQuestions,
                    backgroundColor: AppTheme.borderLight,
                    valueColor: const AlwaysStoppedAnimation(AppTheme.royalBlue),
                    minHeight: 4,
                  ),

                  // Question Body
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Question Header Card
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppTheme.royalBlue.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'QUESTION ${attempt.currentIndex + 1}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.royalBlue),
                                ),
                              ),
                              if (!isDesktop)
                                Builder(
                                  builder: (ctx) => TextButton.icon(
                                    onPressed: () => Scaffold.of(ctx).openEndDrawer(),
                                    icon: const Icon(Icons.grid_view_rounded, size: 16),
                                    label: const Text('Palette'),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Question Text
                          Text(
                            currentQ.question,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 28),

                          // Options A, B, C, D
                          ...['A', 'B', 'C', 'D'].map((optKey) {
                            final optText = currentQ.options[optKey] ?? '';
                            final isSelected = selectedOption == optKey;

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: InkWell(
                                onTap: () => attempt.selectOption(optKey),
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: isSelected ? AppTheme.royalBlue.withValues(alpha: 0.08) : Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: isSelected ? AppTheme.royalBlue : AppTheme.borderLight,
                                      width: isSelected ? 2.0 : 1.0,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 32,
                                        height: 32,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: isSelected ? AppTheme.royalBlue : AppTheme.backgroundLight,
                                          border: Border.all(
                                            color: isSelected ? AppTheme.royalBlue : AppTheme.borderLight,
                                          ),
                                        ),
                                        alignment: Alignment.center,
                                        child: Text(
                                          optKey,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            color: isSelected ? Colors.white : AppTheme.textPrimary,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Text(
                                          optText,
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                            color: AppTheme.textPrimary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),

                  // Bottom Action Bar (Previous, Clear Answer, Mark for Review, Next/Finish)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(top: BorderSide(color: AppTheme.borderLight)),
                    ),
                    child: Row(
                      children: [
                        // Previous Button
                        OutlinedButton.icon(
                          onPressed: attempt.currentIndex > 0 ? () => attempt.previousQuestion() : null,
                          icon: const Icon(Icons.arrow_back, size: 16),
                          label: const Text('Previous'),
                        ),
                        const SizedBox(width: 10),

                        // Clear Answer Button
                        if (selectedOption != null)
                          TextButton(
                            onPressed: () => attempt.clearAnswer(),
                            child: const Text('Clear Answer', style: TextStyle(color: AppTheme.statusRed, fontSize: 13)),
                          ),

                        const Spacer(),

                        // Mark for Review Button
                        OutlinedButton.icon(
                          onPressed: () => attempt.toggleMarkForReview(),
                          icon: Icon(
                            attempt.isCurrentMarkedForReview ? Icons.bookmark : Icons.bookmark_border,
                            size: 16,
                            color: AppTheme.statusPurple,
                          ),
                          label: Text(
                            attempt.isCurrentMarkedForReview ? 'Unmark Review' : 'Mark for Review',
                            style: const TextStyle(color: AppTheme.statusPurple),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Next / Finish Button
                        ElevatedButton.icon(
                          onPressed: () {
                            if (attempt.currentIndex < attempt.totalQuestions - 1) {
                              attempt.nextQuestion();
                            } else {
                              _confirmAndSubmit();
                            }
                          },
                          icon: Icon(
                            attempt.currentIndex < attempt.totalQuestions - 1 ? Icons.arrow_forward : Icons.done_all,
                            size: 16,
                          ),
                          label: Text(attempt.currentIndex < attempt.totalQuestions - 1 ? 'Next' : 'Finish Exam'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Desktop Permanent Question Palette Sidebar
            if (isDesktop)
              Container(
                width: 280,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(left: BorderSide(color: AppTheme.borderLight)),
                ),
                child: QuestionPalette(
                  totalQuestions: attempt.totalQuestions,
                  currentIndex: attempt.currentIndex,
                  onSelectQuestion: (idx) => attempt.goToQuestion(idx),
                  getState: attempt.getPaletteState,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
