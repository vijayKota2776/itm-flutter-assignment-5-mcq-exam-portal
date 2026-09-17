import 'exam_model.dart';

class ReportStatsModel {
  final int totalAttempts;
  final double averageScore;
  final double highestScore;
  final double lowestScore;
  final int passCount;
  final int failCount;
  final double passPercentage;
  final double failPercentage;
  final Map<String, int> scoreDistribution;

  ReportStatsModel({
    required this.totalAttempts,
    required this.averageScore,
    required this.highestScore,
    required this.lowestScore,
    required this.passCount,
    required this.failCount,
    required this.passPercentage,
    required this.failPercentage,
    required this.scoreDistribution,
  });

  factory ReportStatsModel.fromJson(Map<String, dynamic> json) {
    final rawDist = json['scoreDistribution'] as Map<String, dynamic>? ?? {};
    final Map<String, int> dist = {};
    rawDist.forEach((k, v) => dist[k] = (v as num?)?.toInt() ?? 0);

    return ReportStatsModel(
      totalAttempts: (json['totalAttempts'] as num?)?.toInt() ?? 0,
      averageScore: (json['averageScore'] as num?)?.toDouble() ?? 0.0,
      highestScore: (json['highestScore'] as num?)?.toDouble() ?? 0.0,
      lowestScore: (json['lowestScore'] as num?)?.toDouble() ?? 0.0,
      passCount: (json['passCount'] as num?)?.toInt() ?? 0,
      failCount: (json['failCount'] as num?)?.toInt() ?? 0,
      passPercentage: (json['passPercentage'] as num?)?.toDouble() ?? 0.0,
      failPercentage: (json['failPercentage'] as num?)?.toDouble() ?? 0.0,
      scoreDistribution: dist,
    );
  }
}

class StudentRankModel {
  final String studentName;
  final String email;
  final double score;
  final double totalMarks;
  final double percentage;
  final String status;
  final String grade;
  final int timeTaken;
  final String submittedAt;

  StudentRankModel({
    required this.studentName,
    required this.email,
    required this.score,
    required this.totalMarks,
    required this.percentage,
    required this.status,
    required this.grade,
    required this.timeTaken,
    required this.submittedAt,
  });

  factory StudentRankModel.fromJson(Map<String, dynamic> json) {
    return StudentRankModel(
      studentName: json['studentName'] ?? json['Student Name'] ?? 'Student',
      email: json['email'] ?? json['studentEmail'] ?? json['Email'] ?? '',
      score: (json['score'] as num?)?.toDouble() ?? 0.0,
      totalMarks: (json['totalMarks'] as num?)?.toDouble() ?? 100.0,
      percentage: (json['percentage'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] ?? 'PASS',
      grade: json['grade'] ?? 'B',
      timeTaken: (json['timeTaken'] as num?)?.toInt() ?? 0,
      submittedAt: json['submittedAt'] ?? '',
    );
  }
}

class ExamReportModel {
  final ExamModel exam;
  final ReportStatsModel stats;
  final List<StudentRankModel> students;

  ExamReportModel({
    required this.exam,
    required this.stats,
    required this.students,
  });

  factory ExamReportModel.fromJson(Map<String, dynamic> json) {
    final rawExam = json['exam'] as Map<String, dynamic>? ?? {};
    final rawStats = json['stats'] as Map<String, dynamic>? ?? {};
    final rawStudents = (json['students'] as List<dynamic>?) ?? [];

    return ExamReportModel(
      exam: ExamModel.fromJson(rawExam),
      stats: ReportStatsModel.fromJson(rawStats),
      students: rawStudents.map((s) => StudentRankModel.fromJson(s as Map<String, dynamic>)).toList(),
    );
  }
}
