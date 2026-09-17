import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/exam_model.dart';
import '../../models/result_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/exam_provider.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/status_badge.dart';
import 'exam_interface_screen.dart';
import 'exam_result_screen.dart';
import 'student_history_screen.dart';
import 'student_profile_screen.dart';

class StudentDashboardScreen extends StatefulWidget {
  const StudentDashboardScreen({super.key});

  @override
  State<StudentDashboardScreen> createState() => _StudentDashboardScreenState();
}

class _StudentDashboardScreenState extends State<StudentDashboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshData();
    });
  }

  Future<void> _refreshData() async {
    final ep = Provider.of<ExamProvider>(context, listen: false);
    await ep.fetchAvailableExams();
    await ep.fetchHistory();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final examProvider = Provider.of<ExamProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Examination Portal'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _refreshData,
          ),
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'My Exam History',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const StudentHistoryScreen()),
              );
              if (mounted) _refreshData();
            },
          ),
          IconButton(
            icon: const Icon(Icons.account_circle),
            tooltip: 'My Profile',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const StudentProfileScreen()),
              );
              if (mounted) _refreshData();
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign Out',
            onPressed: () => auth.logout(),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.accentBlue,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(text: 'Active (${examProvider.activeExams.length})'),
            Tab(text: 'Upcoming (${examProvider.upcomingExams.length})'),
            Tab(text: 'Completed (${examProvider.completedExams.length})'),
          ],
        ),
      ),
      body: examProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refreshData,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildExamsList(examProvider.activeExams, 'No active examinations available right now.'),
                  _buildExamsList(examProvider.upcomingExams, 'No upcoming examinations scheduled.'),
                  _buildExamsList(examProvider.completedExams, 'You have not completed any examinations yet.'),
                ],
              ),
            ),
    );
  }

  Widget _buildExamsList(List<ExamModel> exams, String emptyMessage) {
    if (exams.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.assignment_turned_in_outlined, size: 64, color: AppTheme.textMuted),
            const SizedBox(height: 16),
            Text(
              emptyMessage,
              style: const TextStyle(fontSize: 15, color: AppTheme.textSecondary),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: exams.length,
      itemBuilder: (context, index) {
        final exam = exams[index];
        return _buildExamCard(context, exam);
      },
    );
  }

  Widget _buildExamCard(BuildContext context, ExamModel exam) {
    final bool isActive = exam.studentStatus == 'Active';
    final bool isCompleted = exam.studentStatus == 'Completed';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        exam.title,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Subject: ${exam.subject}',
                        style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
                StatusBadge(status: exam.studentStatus ?? exam.status),
              ],
            ),
            if (exam.description.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                exam.description,
                style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
              ),
            ],
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildCardInfo(Icons.timer_outlined, '${exam.duration} mins'),
                _buildCardInfo(Icons.format_list_numbered, '${exam.questionCount} Questions'),
                _buildCardInfo(Icons.grade_outlined, '${exam.totalMarks} Marks'),
                _buildCardInfo(Icons.remove_circle_outline, '-${exam.negativeMarking} Neg'),
              ],
            ),
            const SizedBox(height: 18),
            // Action Button
            SizedBox(
              width: double.infinity,
              child: isActive
                  ? ElevatedButton.icon(
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ExamInterfaceScreen(examId: exam.id),
                          ),
                        );
                        if (mounted) {
                          _refreshData();
                        }
                      },
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Start Examination'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.royalBlue,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    )
                  : isCompleted
                      ? OutlinedButton.icon(
                          onPressed: () async {
                            final ep = Provider.of<ExamProvider>(context, listen: false);
                            if (ep.history.isEmpty) {
                              await ep.fetchHistory();
                            }

                            ResultModel? result;
                            try {
                              result = ep.history.firstWhere((r) => r.examId == exam.id);
                            } catch (_) {
                              // If not in local history list, fetch by ID
                              final queryId = exam.attemptId ?? exam.id;
                              final res = await ApiService.get('/student/result/$queryId');
                              if (res.success && res.data != null) {
                                result = ResultModel.fromJson(res.data as Map<String, dynamic>);
                              }
                            }

                            if (context.mounted) {
                              if (result != null) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => ExamResultScreen(result: result!)),
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Result record is still processing or could not be loaded.')),
                                );
                              }
                            }
                          },
                          icon: const Icon(Icons.receipt_long),
                          label: const Text('View Result Scorecard'),
                        )
                      : Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: AppTheme.backgroundLight,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Available from ${exam.startDate.split('T')[0]}',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardInfo(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppTheme.royalBlue),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
