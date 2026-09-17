import 'exam_model.dart';
import 'question_model.dart';

class AttemptModel {
  final String attemptId;
  final ExamModel exam;
  final List<QuestionModel> questions;
  final Map<String, String> studentAnswers;
  final String startedAt;
  final String expiresAt;
  final int remainingSeconds;

  AttemptModel({
    required this.attemptId,
    required this.exam,
    required this.questions,
    required this.studentAnswers,
    required this.startedAt,
    required this.expiresAt,
    required this.remainingSeconds,
  });

  factory AttemptModel.fromJson(Map<String, dynamic> json) {
    final rawExam = json['exam'] as Map<String, dynamic>? ?? {};
    final rawQuestions = (json['questions'] as List<dynamic>?) ?? [];
    final rawAnswers = (json['studentAnswers'] as Map<String, dynamic>?) ?? {};

    final Map<String, String> answersMap = {};
    rawAnswers.forEach((k, v) => answersMap[k] = v.toString());

    return AttemptModel(
      attemptId: json['attemptId'] ?? '',
      exam: ExamModel.fromJson(rawExam),
      questions: rawQuestions.map((q) => QuestionModel.fromJson(q as Map<String, dynamic>)).toList(),
      studentAnswers: answersMap,
      startedAt: json['startedAt'] ?? '',
      expiresAt: json['expiresAt'] ?? '',
      remainingSeconds: (json['remainingSeconds'] as num?)?.toInt() ?? 0,
    );
  }
}
