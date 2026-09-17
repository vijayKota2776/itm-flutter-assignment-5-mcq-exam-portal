import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/attempt_model.dart';
import '../models/question_model.dart';
import '../models/result_model.dart';
import '../services/api_service.dart';

enum QuestionPaletteState {
  answered,           // GREEN
  visitedUnanswered,  // RED
  markedForReview,    // PURPLE
  notVisited          // GRAY
}

class AttemptProvider extends ChangeNotifier {
  AttemptModel? _attempt;
  int _currentIndex = 0;
  final Map<String, String> _answers = {};
  final Set<int> _markedForReview = {};
  final Set<int> _visitedIndices = {0}; // Start on question 0

  int _remainingSeconds = 0;
  Timer? _timer;
  Timer? _autosaveDebounceTimer;

  bool _isLoading = false;
  bool _isSubmitting = false;
  String? _errorMessage;
  String? _autosaveMessage;
  ResultModel? _lastResult;

  // Auto-submit callback to notify UI
  VoidCallback? onTimeExpired;

  AttemptModel? get attempt => _attempt;
  int get currentIndex => _currentIndex;
  Map<String, String> get answers => _answers;
  int get remainingSeconds => _remainingSeconds;
  bool get isLoading => _isLoading;
  bool get isSubmitting => _isSubmitting;
  String? get errorMessage => _errorMessage;
  String? get autosaveMessage => _autosaveMessage;
  ResultModel? get lastResult => _lastResult;

  List<QuestionModel> get questions => _attempt?.questions ?? [];
  QuestionModel? get currentQuestion =>
      (questions.isNotEmpty && _currentIndex < questions.length) ? questions[_currentIndex] : null;

  int get answeredCount => _answers.values.where((v) => v.isNotEmpty).length;
  int get totalQuestions => questions.length;
  bool get isCurrentMarkedForReview => _markedForReview.contains(_currentIndex);

  /// Get state for question palette tile
  QuestionPaletteState getPaletteState(int index) {
    if (index >= questions.length) return QuestionPaletteState.notVisited;
    final q = questions[index];
    final ans = _answers[q.id];

    if (_markedForReview.contains(index)) {
      return QuestionPaletteState.markedForReview;
    }
    if (ans != null && ans.isNotEmpty) {
      return QuestionPaletteState.answered;
    }
    if (_visitedIndices.contains(index)) {
      return QuestionPaletteState.visitedUnanswered;
    }
    return QuestionPaletteState.notVisited;
  }

  /// Start an exam attempt via backend
  Future<bool> startExam(String examId) async {
    _isLoading = true;
    _errorMessage = null;
    _answers.clear();
    _markedForReview.clear();
    _visitedIndices.clear();
    _visitedIndices.add(0);
    _currentIndex = 0;
    _lastResult = null;
    notifyListeners();

    final response = await ApiService.post('/student/exam/$examId/start');

    if (response.success && response.data != null) {
      _attempt = AttemptModel.fromJson(response.data as Map<String, dynamic>);
      _answers.addAll(_attempt!.studentAnswers);
      _remainingSeconds = _attempt!.remainingSeconds;

      _startTimer();
      _isLoading = false;
      notifyListeners();
      return true;
    } else {
      _errorMessage = response.message;
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        _remainingSeconds--;
        notifyListeners();
      } else {
        _timer?.cancel();
        // Trigger auto submit on timer expiration
        if (!_isSubmitting) {
          submitExam(isAutoSubmit: true).then((_) {
            if (onTimeExpired != null) {
              onTimeExpired!();
            }
          });
        }
      }
    });
  }

  /// Select answer option for current question
  void selectOption(String option) {
    if (currentQuestion == null) return;
    final qId = currentQuestion!.id;

    _answers[qId] = option;
    notifyListeners();

    // Trigger debounced background autosave
    _triggerAutosave();
  }

  /// Clear answer for current question
  void clearAnswer() {
    if (currentQuestion == null) return;
    final qId = currentQuestion!.id;
    _answers.remove(qId);
    notifyListeners();
    _triggerAutosave();
  }

  /// Toggle Mark for Review
  void toggleMarkForReview() {
    if (_markedForReview.contains(_currentIndex)) {
      _markedForReview.remove(_currentIndex);
    } else {
      _markedForReview.add(_currentIndex);
    }
    notifyListeners();
  }

  /// Navigation
  void goToQuestion(int index) {
    if (index >= 0 && index < totalQuestions) {
      _currentIndex = index;
      _visitedIndices.add(index);
      notifyListeners();
    }
  }

  void nextQuestion() {
    if (_currentIndex < totalQuestions - 1) {
      goToQuestion(_currentIndex + 1);
    }
  }

  void previousQuestion() {
    if (_currentIndex > 0) {
      goToQuestion(_currentIndex - 1);
    }
  }

  /// Debounced background autosave to backend
  void _triggerAutosave() {
    _autosaveDebounceTimer?.cancel();
    _autosaveDebounceTimer = Timer(const Duration(milliseconds: 700), () async {
      if (_attempt == null) return;
      _autosaveMessage = 'Saving...';
      notifyListeners();

      final res = await ApiService.post(
        '/student/exam/${_attempt!.exam.id}/save-answer',
        body: {
          'attemptId': _attempt!.attemptId,
          'answers': _answers,
        },
      );

      if (res.success) {
        _autosaveMessage = 'All answers saved';
      } else {
        _autosaveMessage = 'Saved locally';
      }
      notifyListeners();

      // Clear message after 2 seconds
      Timer(const Duration(seconds: 2), () {
        _autosaveMessage = null;
        notifyListeners();
      });
    });
  }

  /// Final Submission and Server-Side Evaluation
  Future<bool> submitExam({bool isAutoSubmit = false}) async {
    if (_attempt == null || _isSubmitting) return false;

    _isSubmitting = true;
    _timer?.cancel();
    _autosaveDebounceTimer?.cancel();
    notifyListeners();

    final res = await ApiService.post(
      '/student/exam/${_attempt!.exam.id}/submit',
      body: {
        'attemptId': _attempt!.attemptId,
        'answers': _answers,
        'isAutoSubmit': isAutoSubmit,
      },
    );

    _isSubmitting = false;

    if (res.success && res.data != null) {
      _lastResult = ResultModel.fromJson(res.data as Map<String, dynamic>);
      notifyListeners();
      return true;
    } else {
      _errorMessage = res.message;
      notifyListeners();
      return false;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _autosaveDebounceTimer?.cancel();
    super.dispose();
  }
}
