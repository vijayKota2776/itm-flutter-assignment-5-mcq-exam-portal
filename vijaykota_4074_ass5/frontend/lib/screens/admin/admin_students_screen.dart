import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/admin_provider.dart';
import '../../theme/app_theme.dart';

class AdminStudentsScreen extends StatefulWidget {
  const AdminStudentsScreen({super.key});

  @override
  State<AdminStudentsScreen> createState() => _AdminStudentsScreenState();
}

class _AdminStudentsScreenState extends State<AdminStudentsScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AdminProvider>(context, listen: false).fetchStudents();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final admin = Provider.of<AdminProvider>(context);

    final filteredStudents = admin.students.where((s) {
      final name = (s['name'] ?? '').toString().toLowerCase();
      final email = (s['email'] ?? '').toString().toLowerCase();
      final q = _searchQuery.toLowerCase();
      return name.contains(q) || email.contains(q);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Registered Students'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => admin.fetchStudents(),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val.trim()),
              decoration: const InputDecoration(
                hintText: 'Search students by name or email...',
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 18),

            Expanded(
              child: admin.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : filteredStudents.isEmpty
                      ? const Center(
                          child: Text('No student records found.'),
                        )
                      : Card(
                          child: SingleChildScrollView(
                            child: DataTable(
                              headingRowColor: WidgetStateProperty.all(AppTheme.primaryNavy.withValues(alpha: 0.05)),
                              columns: const [
                                DataColumn(label: Text('Student Name', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Email Address', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Total Attempts', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Average Score', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Pass %', style: TextStyle(fontWeight: FontWeight.bold))),
                              ],
                              rows: filteredStudents.map((s) {
                                return DataRow(cells: [
                                  DataCell(
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 14,
                                          backgroundColor: AppTheme.royalBlue,
                                          child: Text(
                                            (s['name'] ?? 'S').substring(0, 1).toUpperCase(),
                                            style: const TextStyle(color: Colors.white, fontSize: 12),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(s['name'] ?? 'Student', style: const TextStyle(fontWeight: FontWeight.w600)),
                                      ],
                                    ),
                                  ),
                                  DataCell(Text(s['email'] ?? '-')),
                                  DataCell(Text('${s['totalAttempts'] ?? 0}')),
                                  DataCell(Text('${s['averageScore'] ?? 0}')),
                                  DataCell(
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: ((s['passPercentage'] ?? 0) >= 50 ? AppTheme.statusGreen : AppTheme.statusRed).withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        '${s['passPercentage'] ?? 0}%',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: (s['passPercentage'] ?? 0) >= 50 ? AppTheme.statusGreen : AppTheme.statusRed,
                                        ),
                                      ),
                                    ),
                                  ),
                                ]);
                              }).toList(),
                            ),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
