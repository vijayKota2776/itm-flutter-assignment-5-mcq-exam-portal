import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/exam_model.dart';
import '../../models/question_model.dart';
import '../../providers/admin_provider.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/status_badge.dart';
import 'create_exam_screen.dart';
import 'admin_reports_screen.dart';

class AdminExamsScreen extends StatefulWidget {
  const AdminExamsScreen({super.key});

  @override
  State<AdminExamsScreen> createState() => _AdminExamsScreenState();
}

class _AdminExamsScreenState extends State<AdminExamsScreen> {
  final _searchController = TextEditingController();
  String _selectedStatus = 'all';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AdminProvider>(context, listen: false).fetchExams();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String val) {
    Provider.of<AdminProvider>(context, listen: false).fetchExams(
      status: _selectedStatus,
      search: val.trim(),
    );
  }

  Future<void> _openCreateExam() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreateExamScreen()),
    );
    if (mounted) {
      final admin = Provider.of<AdminProvider>(context, listen: false);
      await admin.fetchExams(status: _selectedStatus, search: _searchController.text);
      await admin.fetchDashboardStats();
    }
  }

  void _showQuestionsDialog(ExamModel exam) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    final res = await ApiService.get('/admin/exam/${exam.id}');
    if (!mounted) return;
    Navigator.pop(context); // dismiss loading

    if (res.success && res.data != null) {
      final data = res.data as Map<String, dynamic>;
      final rawQuestions = (data['questions'] as List<dynamic>?) ?? [];
      final questions = rawQuestions.map((q) => QuestionModel.fromJson(q as Map<String, dynamic>)).toList();

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('${exam.title} - Questions (${questions.length})'),
          content: SizedBox(
            width: 600,
            height: 450,
            child: questions.isEmpty
                ? const Center(child: Text('No questions recorded for this exam.'))
                : ListView.separated(
                    itemCount: questions.length,
                    separatorBuilder: (_, _) => const Divider(),
                    itemBuilder: (c, idx) {
                      final q = questions[idx];
                      return ListTile(
                        leading: CircleAvatar(
                          radius: 12,
                          backgroundColor: AppTheme.royalBlue,
                          child: Text('${q.questionNo}', style: const TextStyle(fontSize: 10, color: Colors.white)),
                        ),
                        title: Text(q.question, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        subtitle: Text(
                          'A: ${q.options['A']} | B: ${q.options['B']} | C: ${q.options['C']} | D: ${q.options['D']}',
                          style: const TextStyle(fontSize: 11),
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.statusGreen.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text('Ans: ${q.correctAnswer ?? '-'}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.statusGreen)),
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load questions: ${res.message}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final admin = Provider.of<AdminProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Examinations'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () => admin.fetchExams(status: _selectedStatus, search: _searchController.text),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ElevatedButton.icon(
              onPressed: _openCreateExam,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Create Exam'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentBlue,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Search & Filter Row
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    decoration: const InputDecoration(
                      hintText: 'Search exams by title or subject...',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.borderLight),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedStatus,
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('All Statuses')),
                        DropdownMenuItem(value: 'draft', child: Text('Drafts Only')),
                        DropdownMenuItem(value: 'published', child: Text('Published Only')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedStatus = val);
                          admin.fetchExams(status: val, search: _searchController.text);
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Exams List
            Expanded(
              child: admin.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : admin.exams.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.assignment_late_outlined, size: 64, color: AppTheme.textMuted),
                              const SizedBox(height: 16),
                              const Text('No examinations found', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              const Text('Click "Create Exam" to upload questions and publish a new test.'),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _openCreateExam,
                                child: const Text('Create First Exam'),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: admin.exams.length,
                          itemBuilder: (context, index) {
                            final exam = admin.exams[index];
                            return _buildExamRow(context, admin, exam);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExamRow(BuildContext context, AdminProvider admin, ExamModel exam) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.royalBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.quiz_outlined, color: AppTheme.royalBlue, size: 28),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        exam.title,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 10),
                      StatusBadge(status: exam.status),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Subject: ${exam.subject}  •  Questions: ${exam.questionCount}  •  Duration: ${exam.duration}m  •  Total Marks: ${exam.totalMarks}  •  Neg. Mark: ${exam.negativeMarking}',
                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
            // Actions
            Row(
              children: [
                // View Questions Action
                IconButton(
                  icon: const Icon(Icons.visibility_outlined, color: AppTheme.royalBlue),
                  tooltip: 'View Questions',
                  onPressed: () => _showQuestionsDialog(exam),
                ),
                // Analytics Report Action
                IconButton(
                  icon: const Icon(Icons.bar_chart_outlined, color: AppTheme.statusPurple),
                  tooltip: 'View Analytics Report',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AdminReportsScreen(initialExamId: exam.id),
                      ),
                    );
                  },
                ),
                // Publish / Unpublish Toggle
                OutlinedButton.icon(
                  onPressed: () async {
                    final newStatus = !exam.isPublished;
                    await admin.togglePublishExam(exam.id, newStatus);
                  },
                  icon: Icon(
                    exam.isPublished ? Icons.visibility_off_outlined : Icons.publish_outlined,
                    size: 16,
                    color: exam.isPublished ? AppTheme.statusAmber : AppTheme.statusGreen,
                  ),
                  label: Text(
                    exam.isPublished ? 'Unpublish' : 'Publish',
                    style: TextStyle(
                      color: exam.isPublished ? AppTheme.statusAmber : AppTheme.statusGreen,
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Delete Button
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: AppTheme.statusRed),
                  tooltip: 'Delete Examination',
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Delete Examination?'),
                        content: Text('Are you sure you want to delete "${exam.title}"? All associated questions and files will be permanently removed.'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.statusRed),
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await admin.deleteExam(exam.id);
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
