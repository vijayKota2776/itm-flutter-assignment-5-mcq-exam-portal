class QuestionModel {
  final String id;
  final int questionNo;
  final String question;
  final String imageUrl;
  final Map<String, String> options;
  final String? correctAnswer; // Null during active student attempts

  QuestionModel({
    required this.id,
    required this.questionNo,
    required this.question,
    this.imageUrl = '',
    required this.options,
    this.correctAnswer,
  });

  factory QuestionModel.fromJson(Map<String, dynamic> json) {
    final rawOptions = json['options'] as Map<String, dynamic>? ?? {};
    final Map<String, String> parsedOptions = {};
    rawOptions.forEach((key, value) {
      parsedOptions[key.toUpperCase()] = value.toString();
    });

    return QuestionModel(
      id: json['id'] ?? '',
      questionNo: json['questionNo'] is int ? json['questionNo'] : int.tryParse(json['questionNo']?.toString() ?? '1') ?? 1,
      question: json['question'] ?? '',
      imageUrl: json['imageUrl'] ?? '',
      options: parsedOptions,
      correctAnswer: json['correctAnswer'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'questionNo': questionNo,
      'question': question,
      'imageUrl': imageUrl,
      'options': options,
      if (correctAnswer != null) 'correctAnswer': correctAnswer,
    };
  }
}
