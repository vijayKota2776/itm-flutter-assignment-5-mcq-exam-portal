class QuestionAnalysisModel {
  final String questionId;
  final int questionNo;
  final String question;
  final Map<String, String> options;
  final String? studentAnswer;
  final String correctAnswer;
  final String status; // 'CORRECT' | 'WRONG' | 'UNATTEMPTED'
  final double marksAwarded;

  QuestionAnalysisModel({
    required this.questionId,
    required this.questionNo,
    required this.question,
    required this.options,
    this.studentAnswer,
    required this.correctAnswer,
    required this.status,
    required this.marksAwarded,
  });

  bool get isCorrect => status == 'CORRECT';
  bool get isWrong => status == 'WRONG';
  bool get isUnattempted => status == 'UNATTEMPTED';

  factory QuestionAnalysisModel.fromJson(Map<String, dynamic> json) {
    final rawOpts = json['options'] as Map<String, dynamic>? ?? {};
    final Map<String, String> opts = {};
    rawOpts.forEach((k, v) => opts[k] = v.toString());

    return QuestionAnalysisModel(
      questionId: json['questionId'] ?? '',
      questionNo: (json['questionNo'] as num?)?.toInt() ?? 1,
      question: json['question'] ?? '',
      options: opts,
      studentAnswer: json['studentAnswer'],
      correctAnswer: json['correctAnswer'] ?? '',
      status: json['status'] ?? 'UNATTEMPTED',
      marksAwarded: (json['marksAwarded'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class ResultModel {
  final String id;
  final String attemptId;
  final String studentId;
  final String studentName;
  final String examId;
  final String examTitle;
  final String subject;
  final int totalQuestions;
  final int attempted;
  final int correct;
  final int wrong;
  final int unattempted;
  final double score;
  final double totalMarks;
  final double passingMarks;
  final double percentage;
  final String status; // 'PASS' | 'FAIL'
  final String grade;
  final int timeTaken; // in seconds
  final String resultPdfUrl;
  final String submittedAt;
  final List<QuestionAnalysisModel> questionAnalysis;

  ResultModel({
    required this.id,
    required this.attemptId,
    required this.studentId,
    required this.studentName,
    required this.examId,
    required this.examTitle,
    required this.subject,
    required this.totalQuestions,
    required this.attempted,
    required this.correct,
    required this.wrong,
    required this.unattempted,
    required this.score,
    required this.totalMarks,
    required this.passingMarks,
    required this.percentage,
    required this.status,
    required this.grade,
    required this.timeTaken,
    this.resultPdfUrl = '',
    required this.submittedAt,
    required this.questionAnalysis,
  });

  bool get isPass => status == 'PASS';

  factory ResultModel.fromJson(Map<String, dynamic> json) {
    final rawAnalysis = (json['questionAnalysis'] as List<dynamic>?) ?? [];

    return ResultModel(
      id: json['id'] ?? '',
      attemptId: json['attemptId'] ?? '',
      studentId: json['studentId'] ?? '',
      studentName: json['studentName'] ?? '',
      examId: json['examId'] ?? '',
      examTitle: json['examTitle'] ?? '',
      subject: json['subject'] ?? '',
      totalQuestions: (json['totalQuestions'] as num?)?.toInt() ?? 0,
      attempted: (json['attempted'] as num?)?.toInt() ?? 0,
      correct: (json['correct'] as num?)?.toInt() ?? 0,
      wrong: (json['wrong'] as num?)?.toInt() ?? 0,
      unattempted: (json['unattempted'] as num?)?.toInt() ?? 0,
      score: (json['score'] as num?)?.toDouble() ?? 0.0,
      totalMarks: (json['totalMarks'] as num?)?.toDouble() ?? 0.0,
      passingMarks: (json['passingMarks'] as num?)?.toDouble() ?? 0.0,
      percentage: (json['percentage'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] ?? 'PASS',
      grade: json['grade'] ?? 'B',
      timeTaken: (json['timeTaken'] as num?)?.toInt() ?? 0,
      resultPdfUrl: json['resultPdfUrl'] ?? '',
      submittedAt: json['submittedAt'] ?? '',
      questionAnalysis: rawAnalysis
          .map((item) => QuestionAnalysisModel.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}
