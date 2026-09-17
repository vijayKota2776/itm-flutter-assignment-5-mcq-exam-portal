class UserModel {
  final String uid;
  final String email;
  final String name;
  final String role; // 'admin' | 'student'
  final String photoUrl;
  final String? createdAt;
  final String? lastLogin;

  UserModel({
    required this.uid,
    required this.email,
    required this.name,
    required this.role,
    this.photoUrl = '',
    this.createdAt,
    this.lastLogin,
  });

  bool get isAdmin => role == 'admin';
  bool get isStudent => role == 'student';

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      uid: json['uid'] ?? json['id'] ?? '',
      email: json['email'] ?? '',
      name: json['name'] ?? '',
      role: json['role'] ?? 'student',
      photoUrl: json['photoUrl'] ?? '',
      createdAt: json['createdAt'],
      lastLogin: json['lastLogin'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'email': email,
      'name': name,
      'role': role,
      'photoUrl': photoUrl,
      'createdAt': createdAt,
      'lastLogin': lastLogin,
    };
  }
}
