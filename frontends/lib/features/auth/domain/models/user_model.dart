import 'package:equatable/equatable.dart';

class UserModel extends Equatable {
  final String email;
  final String name;
  final String role;
  final String department;
  final bool isStaff;
  final String? year;
  final String? section;
  final String? staffName;
  final String? inchargeName;
  final Map<String, dynamic> profile;

  const UserModel({
    required this.email,
    required this.name,
    required this.role,
    required this.department,
    required this.isStaff,
    this.year,
    this.section,
    this.staffName,
    this.inchargeName,
    this.profile = const {},
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      email: json['email'] ?? json['College Email'] ?? '',
      name: json['name'] ?? json['Name'] ?? '',
      role: json['role'] ?? 'user',
      department: json['department'] ?? '',
      isStaff: json['isStaff'] ?? false,
      year: json['year'],
      section: json['sec'],
      staffName: json['staffName'],
      inchargeName: json['inchargeName'] ?? json['incharge'],
      profile: json,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'name': name,
      'role': role,
      'department': department,
      'isStaff': isStaff,
      'year': year,
      'sec': section,
      'staffName': staffName,
      'inchargeName': inchargeName,
    };
  }

  UserModel copyWith({
    String? email,
    String? name,
    String? role,
    String? department,
    bool? isStaff,
    String? year,
    String? section,
    String? staffName,
    String? inchargeName,
    Map<String, dynamic>? profile,
  }) {
    return UserModel(
      email: email ?? this.email,
      name: name ?? this.name,
      role: role ?? this.role,
      department: department ?? this.department,
      isStaff: isStaff ?? this.isStaff,
      year: year ?? this.year,
      section: section ?? this.section,
      staffName: staffName ?? this.staffName,
      inchargeName: inchargeName ?? this.inchargeName,
      profile: profile ?? this.profile,
    );
  }

  @override
  List<Object?> get props => [
        email,
        name,
        role,
        department,
        isStaff,
        year,
        section,
        staffName,
        inchargeName,
      ];
}
