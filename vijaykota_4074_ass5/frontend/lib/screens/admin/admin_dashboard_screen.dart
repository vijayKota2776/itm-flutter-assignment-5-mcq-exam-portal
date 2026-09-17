import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/admin_provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/stat_card.dart';
import 'create_exam_screen.dart';
import 'admin_exams_screen.dart';
import 'admin_students_screen.dart';
import 'admin_reports_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshAdminData();
    });
  }

  Future<void> _refreshAdminData() async {
    final admin = Provider.of<AdminProvider>(context, listen: false);
    await admin.fetchDashboardStats();
    await admin.fetchExams();
  }

  Future<void> _openCreateExam() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreateExamScreen()),
    );
    if (mounted) {
      _refreshAdminData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 900;

    final pages = [
      _buildOverviewTab(isDesktop, auth),
      const AdminExamsScreen(),
      const AdminStudentsScreen(),
      const AdminReportsScreen(),
    ];

    if (!isDesktop) {
      return Scaffold(
        body: pages[_selectedIndex],
        bottomNavigationBar: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: (idx) => setState(() => _selectedIndex = idx),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Dashboard'),
            NavigationDestination(icon: Icon(Icons.assignment_outlined), selectedIcon: Icon(Icons.assignment), label: 'Exams'),
            NavigationDestination(icon: Icon(Icons.people_alt_outlined), selectedIcon: Icon(Icons.people_alt), label: 'Students'),
            NavigationDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart), label: 'Reports'),
          ],
        ),
      );
    }

    // Desktop Layout with Sidebar Navigation
    return Scaffold(
      body: Row(
        children: [
          // Sidebar
          Container(
            width: 250,
            color: AppTheme.primaryNavy,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.school, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('ITM SKILLS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                            Text('Admin Portal', style: TextStyle(color: Colors.white70, fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(color: Colors.white24, height: 1),

                // Navigation Items
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    children: [
                      _buildNavItem(0, Icons.dashboard_outlined, Icons.dashboard, 'Dashboard'),
                      _buildNavItem(1, Icons.assignment_outlined, Icons.assignment, 'Examinations'),
                      _buildNavItem(2, Icons.people_alt_outlined, Icons.people_alt, 'Students'),
                      _buildNavItem(3, Icons.bar_chart_outlined, Icons.bar_chart, 'Reports & Analytics'),
                    ],
                  ),
                ),

                // User profile & logout footer
                const Divider(color: Colors.white24, height: 1),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        radius: 16,
                        backgroundColor: AppTheme.royalBlue,
                        child: Icon(Icons.admin_panel_settings, size: 18, color: Colors.white),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              auth.user?.name ?? 'Admin',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                            Text(
                              auth.user?.email ?? '',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white70, fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.logout, size: 18, color: Colors.white70),
                        tooltip: 'Sign Out',
                        onPressed: () => auth.logout(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Main Screen Area
          Expanded(child: pages[_selectedIndex]),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, IconData activeIcon, String title) {
    final isSelected = _selectedIndex == index;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isSelected ? AppTheme.royalBlue : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        leading: Icon(isSelected ? activeIcon : icon, color: Colors.white),
        title: Text(
          title,
          style: TextStyle(
            color: Colors.white,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 14,
          ),
        ),
        onTap: () => setState(() => _selectedIndex = index),
      ),
    );
  }

  Widget _buildOverviewTab(bool isDesktop, AuthProvider auth) {
    final admin = Provider.of<AdminProvider>(context);
    final stats = admin.dashboardStats;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Administrator Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _refreshAdminData,
          ),
          if (!isDesktop)
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Sign Out',
              onPressed: () => auth.logout(),
            ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ElevatedButton.icon(
              onPressed: _openCreateExam,
              icon: const Icon(Icons.upload_file, size: 16),
              label: const Text('Create New Exam'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentBlue,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Banner Card
            Card(
              color: AppTheme.primaryNavy,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'ITM Skills University Examination Management',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Manage course examinations, upload questions via spreadsheet, evaluate performance, and export accredited reports.',
                            style: TextStyle(fontSize: 13, color: Colors.white70),
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 12,
                            runSpacing: 10,
                            children: [
                              ElevatedButton(
                                onPressed: _openCreateExam,
                                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.royalBlue),
                                child: const Text('Upload & Create Exam'),
                              ),
                              OutlinedButton(
                                onPressed: () => setState(() => _selectedIndex = 3),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  side: const BorderSide(color: Colors.white54),
                                ),
                                child: const Text('View Analytics Reports'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),
                    const Icon(Icons.assessment_rounded, size: 84, color: Colors.white24),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Metrics Grid (Interactive: clicking shortcuts to respective tabs)
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 900;
                return GridView.count(
                  crossAxisCount: isWide ? 3 : 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  childAspectRatio: isWide ? 2.0 : 1.4,
                  children: [
                    InkWell(
                      onTap: () => setState(() => _selectedIndex = 1),
                      borderRadius: BorderRadius.circular(12),
                      child: StatCard(
                        title: 'Total Examinations',
                        value: '${stats['totalExams'] ?? admin.exams.length}',
                        icon: Icons.quiz_outlined,
                        iconColor: AppTheme.royalBlue,
                        subtitle: 'Click to view all exams',
                      ),
                    ),
                    InkWell(
                      onTap: () => setState(() => _selectedIndex = 1),
                      borderRadius: BorderRadius.circular(12),
                      child: StatCard(
                        title: 'Active Examinations',
                        value: '${stats['activeExams'] ?? admin.exams.where((e) => e.isPublished).length}',
                        icon: Icons.play_circle_outline,
                        iconColor: AppTheme.statusGreen,
                        subtitle: 'Published for students',
                      ),
                    ),
                    InkWell(
                      onTap: () => setState(() => _selectedIndex = 2),
                      borderRadius: BorderRadius.circular(12),
                      child: StatCard(
                        title: 'Registered Students',
                        value: '${stats['totalStudents'] ?? 0}',
                        icon: Icons.people_outline,
                        iconColor: AppTheme.statusPurple,
                        subtitle: 'Click to manage students',
                      ),
                    ),
                    InkWell(
                      onTap: () => setState(() => _selectedIndex = 3),
                      borderRadius: BorderRadius.circular(12),
                      child: StatCard(
                        title: 'Total Attempts',
                        value: '${stats['totalAttempts'] ?? 0}',
                        icon: Icons.assignment_turned_in_outlined,
                        iconColor: AppTheme.royalBlue,
                        subtitle: 'Click to view reports',
                      ),
                    ),
                    InkWell(
                      onTap: () => setState(() => _selectedIndex = 3),
                      borderRadius: BorderRadius.circular(12),
                      child: StatCard(
                        title: 'Average Score',
                        value: '${stats['averageScore'] ?? 0.0}',
                        icon: Icons.bar_chart,
                        iconColor: AppTheme.accentBlue,
                        subtitle: 'Across all examinations',
                      ),
                    ),
                    InkWell(
                      onTap: () => setState(() => _selectedIndex = 3),
                      borderRadius: BorderRadius.circular(12),
                      child: StatCard(
                        title: 'Pass Rate',
                        value: '${stats['passPercentage'] ?? 0.0}%',
                        icon: Icons.verified_user_outlined,
                        iconColor: AppTheme.statusGreen,
                        subtitle: 'Overall success rate',
                      ),
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 24),

            // Recent Examinations Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Recent Examinations',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        TextButton(
                          onPressed: () => setState(() => _selectedIndex = 1),
                          child: const Text('View All'),
                        ),
                      ],
                    ),
                    const Divider(height: 20),
                    if (admin.exams.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: Text('No examinations created yet.')),
                      )
                    else
                      ...admin.exams.take(5).map((e) => ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: AppTheme.backgroundLight,
                          child: Icon(Icons.quiz, color: AppTheme.royalBlue, size: 20),
                        ),
                        title: Text(e.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('${e.subject} • ${e.questionCount} Questions • ${e.duration} mins'),
                        onTap: () => setState(() => _selectedIndex = 1),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: (e.isPublished ? AppTheme.statusGreen : AppTheme.statusGray).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                e.status.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: e.isPublished ? AppTheme.statusGreen : AppTheme.textSecondary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.bar_chart_outlined, size: 18, color: AppTheme.statusPurple),
                              tooltip: 'Analytics Report',
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => AdminReportsScreen(initialExamId: e.id),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      )),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
