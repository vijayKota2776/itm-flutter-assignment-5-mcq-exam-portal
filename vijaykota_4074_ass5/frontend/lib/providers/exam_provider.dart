import 'package:flutter/foundation.dart';
import '../models/exam_model.dart';
import '../models/result_model.dart';
import '../services/api_service.dart';

class ExamProvider extends ChangeNotifier {
  List<ExamModel> _exams = [];
  List<ResultModel> _history = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<ExamModel> get exams => _exams;
  List<ResultModel> get history => _history;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  List<ExamModel> get activeExams => _exams.where((e) => e.studentStatus == 'Active').toList();
  List<ExamModel> get upcomingExams => _exams.where((e) => e.studentStatus == 'Upcoming').toList();
  List<ExamModel> get completedExams => _exams.where((e) => e.studentStatus == 'Completed').toList();

  Future<void> fetchAvailableExams() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final response = await ApiService.get('/student/exams');

    if (response.success && response.data != null) {
      final List<dynamic> list = response.data as List<dynamic>;
      _exams = list.map((item) => ExamModel.fromJson(item as Map<String, dynamic>)).toList();
    } else {
      _errorMessage = response.message;
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> fetchHistory() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final response = await ApiService.get('/student/history');

    if (response.success && response.data != null) {
      final List<dynamic> list = response.data as List<dynamic>;
      _history = list.map((item) => ResultModel.fromJson(item as Map<String, dynamic>)).toList();
    } else {
      _errorMessage = response.message;
    }

    _isLoading = false;
    notifyListeners();
  }
}
