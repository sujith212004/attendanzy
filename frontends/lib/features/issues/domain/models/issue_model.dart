import 'package:equatable/equatable.dart';

class IssueModel extends Equatable {
  final String? id;
  final String studentEmail;
  final String title;
  final String description;
  final String category;
  final String status;
  final String? timestamp;
  final String? createdAt;
  final String? resolvedAt;
  final String? assignedTo;
  final Map<String, dynamic>? additionalData;

  const IssueModel({
    this.id,
    required this.studentEmail,
    required this.title,
    required this.description,
    required this.category,
    this.status = 'open',
    this.timestamp,
    this.createdAt,
    this.resolvedAt,
    this.assignedTo,
    this.additionalData,
  });

  factory IssueModel.fromJson(Map<String, dynamic> json) {
    return IssueModel(
      id: json['_id']?.toString(),
      studentEmail: json['studentEmail'] ?? '',
      title: json['title'] ?? 'Issue',
      description: json['description'] ?? '',
      category: json['category'] ?? 'General',
      status: json['status']?.toString() ?? 'open',
      timestamp: json['timestamp']?.toString(),
      createdAt: json['createdAt']?.toString(),
      resolvedAt: json['resolvedAt']?.toString(),
      assignedTo: json['assignedTo']?.toString(),
      additionalData: json,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) '_id': id,
      'studentEmail': studentEmail,
      'title': title,
      'description': description,
      'category': category,
      'status': status,
      if (timestamp != null) 'timestamp': timestamp,
      if (createdAt != null) 'createdAt': createdAt,
      if (resolvedAt != null) 'resolvedAt': resolvedAt,
      if (assignedTo != null) 'assignedTo': assignedTo,
      ...?additionalData,
    };
  }

  IssueModel copyWith({
    String? id,
    String? studentEmail,
    String? title,
    String? description,
    String? category,
    String? status,
    String? timestamp,
    String? createdAt,
    String? resolvedAt,
    String? assignedTo,
    Map<String, dynamic>? additionalData,
  }) {
    return IssueModel(
      id: id ?? this.id,
      studentEmail: studentEmail ?? this.studentEmail,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      status: status ?? this.status,
      timestamp: timestamp ?? this.timestamp,
      createdAt: createdAt ?? this.createdAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      assignedTo: assignedTo ?? this.assignedTo,
      additionalData: additionalData ?? this.additionalData,
    );
  }

  @override
  List<Object?> get props => [
        id,
        studentEmail,
        title,
        description,
        category,
        status,
        timestamp,
        createdAt,
        resolvedAt,
        assignedTo,
      ];
}
