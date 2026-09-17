import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/question_model.dart';
import '../../providers/admin_provider.dart';
import '../../theme/app_theme.dart';

class CreateExamScreen extends StatefulWidget {
  const CreateExamScreen({super.key});

  @override
  State<CreateExamScreen> createState() => _CreateExamScreenState();
}

class _CreateExamScreenState extends State<CreateExamScreen> {
  final _formKey = GlobalKey<FormState>();

  // Form Controllers
  final _titleController = TextEditingController(text: 'General Knowledge Examination 2026');
  final _subjectController = TextEditingController(text: 'General Studies');
  final _descriptionController = TextEditingController(text: 'Comprehensive undergraduate general knowledge assessment.');
  final _durationController = TextEditingController(text: '30');
  final _marksPerQuestionController = TextEditingController(text: '1.0');
  final _negativeMarkingController = TextEditingController(text: '0.25');
  final _passingMarksController = TextEditingController(text: '4.0');
  final _instructionsController = TextEditingController(text: 'Read all questions carefully. Choose the single best option. Negative marking applies.');

  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 7));

  String? _selectedFileName;

  @override
  void dispose() {
    _titleController.dispose();
    _subjectController.dispose();
    _descriptionController.dispose();
    _durationController.dispose();
    _marksPerQuestionController.dispose();
    _negativeMarkingController.dispose();
    _passingMarksController.dispose();
    _instructionsController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadExcel() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls', 'csv'],
      withData: true,
    );

    if (!mounted) return;

    if (result != null && result.files.isNotEmpty) {
      final file = result.files.first;
      if (file.bytes != null) {
        setState(() {
          _selectedFileName = file.name;
        });

        final admin = Provider.of<AdminProvider>(context, listen: false);
        final success = await admin.uploadExcelFile(file.bytes!, file.name);

        if (success && mounted) {
          // Auto calculate passing marks default
          final totalQ = admin.parsedQuestions.length;
          final mpq = double.tryParse(_marksPerQuestionController.text) ?? 1.0;
          _passingMarksController.text = (totalQ * mpq * 0.4).toStringAsFixed(1);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Spreadsheet parsed successfully! ${admin.parsedQuestions.length} questions loaded.'),
              backgroundColor: AppTheme.statusGreen,
            ),
          );
        }
      }
    }
  }

  Future<void> _handleSaveExam() async {
    if (!_formKey.currentState!.validate()) return;

    final admin = Provider.of<AdminProvider>(context, listen: false);
    if (admin.parsedQuestions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please upload an Excel or CSV file with valid questions first.'),
          backgroundColor: AppTheme.statusRed,
        ),
      );
      return;
    }

    final duration = int.tryParse(_durationController.text) ?? 30;
    final marksPerQ = double.tryParse(_marksPerQuestionController.text) ?? 1.0;
    final negativeMark = double.tryParse(_negativeMarkingController.text) ?? 0.0;
    final totalMarks = admin.parsedQuestions.length * marksPerQ;
    final passingMarks = double.tryParse(_passingMarksController.text) ?? (totalMarks * 0.4);

    final payload = {
      'title': _titleController.text.trim(),
      'subject': _subjectController.text.trim(),
      'description': _descriptionController.text.trim(),
      'duration': duration,
      'totalMarks': totalMarks,
      'marksPerQuestion': marksPerQ,
      'negativeMarking': negativeMark,
      'passingMarks': passingMarks,
      'instructions': _instructionsController.text.trim(),
      'startDate': _startDate.toIso8601String(),
      'endDate': _endDate.toIso8601String(),
    };

    final success = await admin.createExam(payload);
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Exam created successfully in draft mode!'),
          backgroundColor: AppTheme.statusGreen,
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final admin = Provider.of<AdminProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create New Examination'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Section 1: Excel / CSV Question Upload
                  _buildExcelUploadCard(admin),

                  const SizedBox(height: 24),

                  // Section 2: Questions Preview (if uploaded)
                  if (admin.parsedQuestions.isNotEmpty) ...[
                    _buildQuestionsPreviewCard(admin.parsedQuestions),
                    const SizedBox(height: 24),
                  ],

                  // Validation Errors Card (if any)
                  if (admin.parsedErrors.isNotEmpty) ...[
                    _buildErrorsCard(admin.parsedErrors),
                    const SizedBox(height: 24),
                  ],

                  // Section 3: Exam Metadata
                  _buildExamMetadataCard(),

                  const SizedBox(height: 32),

                  // Action Button
                  SizedBox(
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: (admin.isSavingExam || admin.isUploadingExcel) ? null : _handleSaveExam,
                      icon: admin.isSavingExam
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Icon(Icons.check_circle_outline),
                      label: Text(
                        admin.isSavingExam ? 'Creating Examination...' : 'Save Examination (Draft)',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExcelUploadCard(AdminProvider admin) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.royalBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.file_present_rounded, color: AppTheme.royalBlue),
                ),
                const SizedBox(width: 14),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'STEP 1: Upload Question Sheet',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Select an .xlsx or .csv spreadsheet with Question No., Options A-D, and Correct Answer.',
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ],
            ),
            const Divider(height: 32),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                border: Border.all(color: AppTheme.borderLight, style: BorderStyle.solid),
                borderRadius: BorderRadius.circular(12),
                color: AppTheme.backgroundLight,
              ),
              child: Center(
                child: Column(
                  children: [
                    const Icon(Icons.cloud_upload_outlined, size: 48, color: AppTheme.royalBlue),
                    const SizedBox(height: 12),
                    Text(
                      _selectedFileName ?? 'No spreadsheet file selected yet',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: _selectedFileName != null ? FontWeight.bold : FontWeight.normal,
                        color: _selectedFileName != null ? AppTheme.primaryNavy : AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: admin.isUploadingExcel ? null : _pickAndUploadExcel,
                      icon: admin.isUploadingExcel
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Icon(Icons.file_upload_outlined, size: 18),
                      label: Text(admin.isUploadingExcel ? 'Parsing & Validating...' : 'Choose Excel / CSV File'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionsPreviewCard(List<QuestionModel> questions) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Parsed Questions Preview (${questions.length} Questions)',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.statusGreen.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'VALID SPREADSHEET',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.statusGreen),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280),
              child: ListView.separated(
                itemCount: questions.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, idx) {
                  final q = questions[idx];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    leading: CircleAvatar(
                      radius: 14,
                      backgroundColor: AppTheme.royalBlue,
                      child: Text('${q.questionNo}', style: const TextStyle(fontSize: 11, color: Colors.white)),
                    ),
                    title: Text(q.question, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    subtitle: Text('A: ${q.options['A']} | B: ${q.options['B']} | C: ${q.options['C']} | D: ${q.options['D']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11)),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.royalBlue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text('Key: ${q.correctAnswer}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.royalBlue)),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorsCard(List<dynamic> errors) {
    return Card(
      color: AppTheme.statusRed.withValues(alpha: 0.05),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.error_outline, color: AppTheme.statusRed),
                SizedBox(width: 8),
                Text('Row-Level Spreadsheet Errors', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.statusRed, fontSize: 15)),
              ],
            ),
            const SizedBox(height: 12),
            ...errors.map((e) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text('• ${e.toString()}', style: const TextStyle(fontSize: 12, color: AppTheme.statusRed)),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildExamMetadataCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'STEP 2: Examination Details & Rules',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 18),

            // Title & Subject
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(labelText: 'Examination Title'),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Title is required' : null,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _subjectController,
                    decoration: const InputDecoration(labelText: 'Subject'),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Subject is required' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Description
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'Description'),
              maxLines: 2,
            ),
            const SizedBox(height: 16),

            // Duration, Marks per Q, Negative Marking, Passing Marks
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _durationController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Duration (Minutes)'),
                    validator: (v) => int.tryParse(v ?? '') == null ? 'Valid minutes required' : null,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _marksPerQuestionController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Marks / Question'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _negativeMarkingController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Negative Marking'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _passingMarksController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Passing Marks'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Start Date & End Date Pickers
            Row(
              children: [
                Expanded(
                  child: ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: const BorderSide(color: AppTheme.borderLight),
                    ),
                    title: const Text('Start Date', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                    subtitle: Text(DateFormat('yyyy-MM-dd').format(_startDate), style: const TextStyle(fontWeight: FontWeight.bold)),
                    trailing: const Icon(Icons.calendar_today, size: 18),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _startDate,
                        firstDate: DateTime.now().subtract(const Duration(days: 1)),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) setState(() => _startDate = picked);
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: const BorderSide(color: AppTheme.borderLight),
                    ),
                    title: const Text('End Date', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                    subtitle: Text(DateFormat('yyyy-MM-dd').format(_endDate), style: const TextStyle(fontWeight: FontWeight.bold)),
                    trailing: const Icon(Icons.calendar_today, size: 18),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _endDate,
                        firstDate: _startDate,
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) setState(() => _endDate = picked);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Instructions
            TextFormField(
              controller: _instructionsController,
              decoration: const InputDecoration(labelText: 'Student Instructions'),
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }
}
