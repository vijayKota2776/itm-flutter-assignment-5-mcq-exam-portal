import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/admin_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/stat_card.dart';
import '../../widgets/status_badge.dart';

class AdminReportsScreen extends StatefulWidget {
  final String? initialExamId;

  const AdminReportsScreen({super.key, this.initialExamId});

  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<AdminReportsScreen> {
  String? _selectedExamId;
  bool _isExporting = false;
  String? _exportedUrl;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final admin = Provider.of<AdminProvider>(context, listen: false);
      await admin.fetchExams();
      
      final examToSelect = widget.initialExamId ?? (admin.exams.isNotEmpty ? admin.exams.first.id : null);
      if (examToSelect != null) {
        setState(() => _selectedExamId = examToSelect);
        await admin.fetchExamReport(examToSelect);
      }
    });
  }

  Future<void> _handleExport(String format) async {
    if (_selectedExamId == null) return;
    setState(() {
      _isExporting = true;
      _exportedUrl = null;
    });

    final admin = Provider.of<AdminProvider>(context, listen: false);
    final url = await admin.exportReport(_selectedExamId!, format);

    setState(() {
      _isExporting = false;
      _exportedUrl = url;
    });

    if (url != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Report exported to $format successfully!'),
          backgroundColor: AppTheme.statusGreen,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final admin = Provider.of<AdminProvider>(context);
    final report = admin.currentReport;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Examination Reports & Analytics'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Exam Selector Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    const Icon(Icons.analytics_outlined, color: AppTheme.royalBlue, size: 28),
                    const SizedBox(width: 14),
                    const Text('Select Exam:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedExamId,
                          hint: const Text('Select an examination'),
                          isExpanded: true,
                          items: admin.exams.map((e) {
                            return DropdownMenuItem<String>(
                              value: e.id,
                              child: Text('${e.title} (${e.subject})'),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _selectedExamId = val;
                                _exportedUrl = null;
                              });
                              admin.fetchExamReport(val);
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Export Actions
                    PopupMenuButton<String>(
                      onSelected: _handleExport,
                      itemBuilder: (ctx) => const [
                        PopupMenuItem(value: 'csv', child: Text('Export to CSV')),
                        PopupMenuItem(value: 'excel', child: Text('Export to Excel (.xlsx)')),
                        PopupMenuItem(value: 'pdf', child: Text('Export to PDF')),
                      ],
                      child: ElevatedButton.icon(
                        onPressed: null, // trigger via PopupMenuButton
                        icon: _isExporting
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.download, size: 16),
                        label: const Text('Export Report'),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            if (_exportedUrl != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.statusGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.statusGreen),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: AppTheme.statusGreen),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Exported Cloudinary URL: $_exportedUrl',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            if (admin.isLoading)
              const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
            else if (report == null)
              const Center(child: Text('Select an examination above to view detailed reports.'))
            else ...[
              // Summary Stat Cards
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 900;
                  return GridView.count(
                    crossAxisCount: isWide ? 4 : 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    childAspectRatio: isWide ? 1.8 : 1.4,
                    children: [
                      StatCard(
                        title: 'Total Attempts',
                        value: '${report.stats.totalAttempts}',
                        icon: Icons.people_alt_outlined,
                        iconColor: AppTheme.royalBlue,
                      ),
                      StatCard(
                        title: 'Average Score',
                        value: '${report.stats.averageScore}',
                        icon: Icons.score_outlined,
                        iconColor: AppTheme.accentBlue,
                      ),
                      StatCard(
                        title: 'Highest / Lowest',
                        value: '${report.stats.highestScore} / ${report.stats.lowestScore}',
                        icon: Icons.trending_up,
                        iconColor: AppTheme.statusGreen,
                      ),
                      StatCard(
                        title: 'Pass Rate',
                        value: '${report.stats.passPercentage}%',
                        icon: Icons.verified_outlined,
                        iconColor: AppTheme.statusPurple,
                      ),
                    ],
                  );
                },
              ),

              const SizedBox(height: 24),

              // Score Distribution Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Score Distribution',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 18),
                      ...report.stats.scoreDistribution.entries.map((entry) {
                        final count = entry.value;
                        final total = report.stats.totalAttempts;
                        final fraction = total > 0 ? (count / total) : 0.0;

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(entry.key, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                  Text('$count students (${(fraction * 100).toStringAsFixed(1)}%)', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                                ],
                              ),
                              const SizedBox(height: 4),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: fraction,
                                  minHeight: 10,
                                  backgroundColor: AppTheme.borderLight,
                                  valueColor: const AlwaysStoppedAnimation(AppTheme.royalBlue),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Student Leaderboard Table
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Student Attempts Leaderboard (${report.students.length} Submissions)',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      if (report.students.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(child: Text('No student submissions recorded yet for this exam.')),
                        )
                      else
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            headingRowColor: WidgetStateProperty.all(AppTheme.primaryNavy.withValues(alpha: 0.05)),
                            columns: const [
                              DataColumn(label: Text('Rank', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Student Name', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Email', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Score', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Percentage', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Grade', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                            ],
                            rows: report.students.asMap().entries.map((entry) {
                              final rank = entry.key + 1;
                              final s = entry.value;
                              return DataRow(cells: [
                                DataCell(Text('#$rank', style: const TextStyle(fontWeight: FontWeight.bold))),
                                DataCell(Text(s.studentName, style: const TextStyle(fontWeight: FontWeight.w600))),
                                DataCell(Text(s.email)),
                                DataCell(Text('${s.score} / ${s.totalMarks}', style: const TextStyle(fontWeight: FontWeight.bold))),
                                DataCell(Text('${s.percentage}%')),
                                DataCell(Text(s.grade, style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.statusPurple))),
                                DataCell(StatusBadge(status: s.status)),
                              ]);
                            }).toList(),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
