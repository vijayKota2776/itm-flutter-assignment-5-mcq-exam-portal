class ExamModel {
  final String id;
  final String title;
  final String subject;
  final String description;
  final int duration; // in minutes
  final double totalMarks;
  final double marksPerQuestion;
  final double negativeMarking;
  final double passingMarks;
  final String instructions;
  final int questionCount;
  final String status; // 'draft' | 'published' | 'archived'
  final String? studentStatus; // 'Active' | 'Upcoming' | 'Completed' | 'Expired'
  final String? attemptId;
  final String? attemptStatus;
  final String startDate;
  final String endDate;
  final String excelUrl;
  final String? createdAt;

  ExamModel({
    required this.id,
    required this.title,
    required this.subject,
    this.description = '',
    required this.duration,
    required this.totalMarks,
    this.marksPerQuestion = 1.0,
    this.negativeMarking = 0.0,
    required this.passingMarks,
    this.instructions = '',
    required this.questionCount,
    required this.status,
    this.studentStatus,
    this.attemptId,
    this.attemptStatus,
    required this.startDate,
    required this.endDate,
    this.excelUrl = '',
    this.createdAt,
  });

  bool get isPublished => status == 'published';
  bool get canStart => studentStatus == 'Active';

  factory ExamModel.fromJson(Map<String, dynamic> json) {
    return ExamModel(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      subject: json['subject'] ?? '',
      description: json['description'] ?? '',
      duration: (json['duration'] as num?)?.toInt() ?? 30,
      totalMarks: (json['totalMarks'] as num?)?.toDouble() ?? 0.0,
      marksPerQuestion: (json['marksPerQuestion'] as num?)?.toDouble() ?? 1.0,
      negativeMarking: (json['negativeMarking'] as num?)?.toDouble() ?? 0.0,
      passingMarks: (json['passingMarks'] as num?)?.toDouble() ?? 0.0,
      instructions: json['instructions'] ?? '',
      questionCount: (json['questionCount'] as num?)?.toInt() ?? 0,
      status: json['status'] ?? 'draft',
      studentStatus: json['studentStatus'],
      attemptId: json['attemptId'],
      attemptStatus: json['attemptStatus'],
      startDate: json['startDate'] ?? '',
      endDate: json['endDate'] ?? '',
      excelUrl: json['excelUrl'] ?? '',
      createdAt: json['createdAt'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'subject': subject,
      'description': description,
      'duration': duration,
      'totalMarks': totalMarks,
      'marksPerQuestion': marksPerQuestion,
      'negativeMarking': negativeMarking,
      'passingMarks': passingMarks,
      'instructions': instructions,
      'questionCount': questionCount,
      'status': status,
      'studentStatus': studentStatus,
      'attemptId': attemptId,
      'attemptStatus': attemptStatus,
      'startDate': startDate,
      'endDate': endDate,
      'excelUrl': excelUrl,
      'createdAt': createdAt,
    };
  }
}
