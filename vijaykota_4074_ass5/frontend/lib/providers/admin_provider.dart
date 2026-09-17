import 'package:flutter/foundation.dart';
import '../models/exam_model.dart';
import '../models/question_model.dart';
import '../models/report_model.dart';
import '../services/api_service.dart';

class AdminProvider extends ChangeNotifier {
  Map<String, dynamic> _dashboardStats = {};
  List<ExamModel> _exams = [];
  List<Map<String, dynamic>> _students = [];
  ExamReportModel? _currentReport;

  // Excel Upload & Preview State
  bool _isUploadingExcel = false;
  bool _isSavingExam = false;
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  Map<String, dynamic>? _excelPreviewData;
  List<QuestionModel> _parsedQuestions = [];
  List<dynamic> _parsedErrors = [];

  Map<String, dynamic> get dashboardStats => _dashboardStats;
  List<ExamModel> get exams => _exams;
  List<Map<String, dynamic>> get students => _students;
  ExamReportModel? get currentReport => _currentReport;

  bool get isUploadingExcel => _isUploadingExcel;
  bool get isSavingExam => _isSavingExam;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;

  Map<String, dynamic>? get excelPreviewData => _excelPreviewData;
  List<QuestionModel> get parsedQuestions => _parsedQuestions;
  List<dynamic> get parsedErrors => _parsedErrors;

  /// Fetch Dashboard Summary Cards
  Future<void> fetchDashboardStats() async {
    final res = await ApiService.get('/admin/dashboard-stats');
    if (res.success && res.data != null) {
      _dashboardStats = res.data as Map<String, dynamic>;
      notifyListeners();
    }
  }

  /// Fetch All Exams
  Future<void> fetchExams({String? status, String? search}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    String endpoint = '/admin/exams';
    final queryParams = <String>[];
    if (status != null && status.isNotEmpty && status != 'all') queryParams.add('status=$status');
    if (search != null && search.isNotEmpty) queryParams.add('search=${Uri.encodeComponent(search)}');
    if (queryParams.isNotEmpty) endpoint += '?${queryParams.join('&')}';

    final res = await ApiService.get(endpoint);
    if (res.success && res.data != null) {
      final List<dynamic> list = res.data as List<dynamic>;
      _exams = list.map((item) => ExamModel.fromJson(item as Map<String, dynamic>)).toList();
    } else {
      _errorMessage = res.message;
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Upload Excel / CSV file to backend
  Future<bool> uploadExcelFile(Uint8List fileBytes, String fileName) async {
    _isUploadingExcel = true;
    _errorMessage = null;
    _parsedQuestions.clear();
    _parsedErrors.clear();
    notifyListeners();

    final res = await ApiService.uploadFile(
      '/admin/upload-excel',
      fileBytes: fileBytes,
      fileName: fileName,
    );

    _isUploadingExcel = false;

    if (res.success && res.data != null) {
      _excelPreviewData = res.data as Map<String, dynamic>;
      final rawQuestions = (_excelPreviewData!['questions'] as List<dynamic>?) ?? [];
      _parsedQuestions = rawQuestions.map((q) => QuestionModel.fromJson(q as Map<String, dynamic>)).toList();
      _parsedErrors = (_excelPreviewData!['errors'] as List<dynamic>?) ?? [];
      notifyListeners();
      return true;
    } else {
      _errorMessage = res.message;
      if (res.data != null && res.data['details'] != null) {
        _parsedErrors = res.data['details']['errors'] ?? [];
      }
      notifyListeners();
      return false;
    }
  }

  /// Create Exam with parsed questions and metadata
  Future<bool> createExam(Map<String, dynamic> examPayload) async {
    _isSavingExam = true;
    _errorMessage = null;
    notifyListeners();

    // Include the parsed questions
    final fullPayload = {
      ...examPayload,
      'questions': _parsedQuestions.map((q) => q.toJson()).toList(),
      'excelUrl': _excelPreviewData?['excelUrl'] ?? '',
      'excelPublicId': _excelPreviewData?['excelPublicId'] ?? '',
    };

    final res = await ApiService.post('/admin/exam', body: fullPayload);

    _isSavingExam = false;

    if (res.success) {
      _successMessage = 'Examination created successfully!';
      clearExcelPreview();
      await fetchExams();
      await fetchDashboardStats();
      notifyListeners();
      return true;
    } else {
      _errorMessage = res.message;
      notifyListeners();
      return false;
    }
  }

  /// Toggle Publish Status
  Future<bool> togglePublishExam(String examId, bool publish) async {
    final status = publish ? 'published' : 'draft';
    final res = await ApiService.put('/admin/exam/$examId', body: {'status': status});
    if (res.success) {
      await fetchExams();
      await fetchDashboardStats();
      return true;
    } else {
      _errorMessage = res.message;
      notifyListeners();
      return false;
    }
  }

  /// Delete Exam
  Future<bool> deleteExam(String examId) async {
    final res = await ApiService.delete('/admin/exam/$examId');
    if (res.success) {
      await fetchExams();
      await fetchDashboardStats();
      return true;
    } else {
      _errorMessage = res.message;
      notifyListeners();
      return false;
    }
  }

  /// Fetch Registered Students
  Future<void> fetchStudents() async {
    _isLoading = true;
    notifyListeners();

    final res = await ApiService.get('/admin/students');
    if (res.success && res.data != null) {
      final list = res.data as List<dynamic>;
      _students = list.map((item) => item as Map<String, dynamic>).toList();
    }
    _isLoading = false;
    notifyListeners();
  }

  /// Fetch Analytics Report for Exam
  Future<void> fetchExamReport(String examId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final res = await ApiService.get('/admin/report/$examId');
    if (res.success && res.data != null) {
      _currentReport = ExamReportModel.fromJson(res.data as Map<String, dynamic>);
    } else {
      _errorMessage = res.message;
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Export Report (CSV, Excel, PDF)
  Future<String?> exportReport(String examId, String format) async {
    final res = await ApiService.post('/admin/report/$examId/export', body: {'format': format});
    if (res.success && res.data != null) {
      return res.data['reportUrl'] as String?;
    } else {
      _errorMessage = res.message;
      notifyListeners();
      return null;
    }
  }

  void clearExcelPreview() {
    _excelPreviewData = null;
    _parsedQuestions.clear();
    _parsedErrors.clear();
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
  }
}
