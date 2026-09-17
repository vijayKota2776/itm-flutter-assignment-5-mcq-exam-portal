import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/exam_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/status_badge.dart';
import 'exam_result_screen.dart';

class StudentHistoryScreen extends StatefulWidget {
  const StudentHistoryScreen({super.key});

  @override
  State<StudentHistoryScreen> createState() => _StudentHistoryScreenState();
}

class _StudentHistoryScreenState extends State<StudentHistoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ExamProvider>(context, listen: false).fetchHistory();
    });
  }

  @override
  Widget build(BuildContext context) {
    final examProvider = Provider.of<ExamProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Examination History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => examProvider.fetchHistory(),
          ),
        ],
      ),
      body: examProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : examProvider.history.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.history_edu_outlined, size: 64, color: AppTheme.textMuted),
                      const SizedBox(height: 16),
                      const Text(
                        'No exam history found',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      const Text('Attempt examinations from your dashboard to view performance logs.'),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(24),
                  itemCount: examProvider.history.length,
                  itemBuilder: (context, index) {
                    final res = examProvider.history[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => ExamResultScreen(result: res)),
                          );
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: (res.isPass ? AppTheme.statusGreen : AppTheme.statusRed).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  res.isPass ? Icons.check_circle_outline : Icons.cancel_outlined,
                                  color: res.isPass ? AppTheme.statusGreen : AppTheme.statusRed,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          res.examTitle,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                        ),
                                        const SizedBox(width: 8),
                                        StatusBadge(status: res.status),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${res.subject} • Score: ${res.score}/${res.totalMarks} (${res.percentage}%) • Grade: ${res.grade}',
                                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right, color: AppTheme.textMuted),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
