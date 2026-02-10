import 'package:equatable/equatable.dart';

class ODRequestModel extends Equatable {
  final String? id;
  final String studentEmail;
  final String subject;
  final String reason;
  final String fromDate;
  final String toDate;
  final String status;
  final String? staffStatus;
  final String? hodStatus;
  final String? timestamp;
  final String? createdAt;
  final Map<String, dynamic>? additionalData;

  const ODRequestModel({
    this.id,
    required this.studentEmail,
    required this.subject,
    required this.reason,
    required this.fromDate,
    required this.toDate,
    this.status = 'pending',
    this.staffStatus,
    this.hodStatus,
    this.timestamp,
    this.createdAt,
    this.additionalData,
  });

  factory ODRequestModel.fromJson(Map<String, dynamic> json) {
    return ODRequestModel(
      id: json['_id']?.toString(),
      studentEmail: json['studentEmail'] ?? '',
      subject: json['subject'] ?? 'OD Request',
      reason: json['reason'] ?? '',
      fromDate: json['fromDate'] ?? '',
      toDate: json['toDate'] ?? '',
      status: json['status']?.toString() ?? 'pending',
      staffStatus: json['staffStatus']?.toString(),
      hodStatus: json['hodStatus']?.toString(),
      timestamp: json['timestamp']?.toString(),
      createdAt: json['createdAt']?.toString(),
      additionalData: json,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) '_id': id,
      'studentEmail': studentEmail,
      'subject': subject,
      'reason': reason,
      'fromDate': fromDate,
      'toDate': toDate,
      'status': status,
      if (staffStatus != null) 'staffStatus': staffStatus,
      if (hodStatus != null) 'hodStatus': hodStatus,
      if (timestamp != null) 'timestamp': timestamp,
      if (createdAt != null) 'createdAt': createdAt,
      ...?additionalData,
    };
  }

  ODRequestModel copyWith({
    String? id,
    String? studentEmail,
    String? subject,
    String? reason,
    String? fromDate,
    String? toDate,
    String? status,
    String? staffStatus,
    String? hodStatus,
    String? timestamp,
    String? createdAt,
    Map<String, dynamic>? additionalData,
  }) {
    return ODRequestModel(
      id: id ?? this.id,
      studentEmail: studentEmail ?? this.studentEmail,
      subject: subject ?? this.subject,
      reason: reason ?? this.reason,
      fromDate: fromDate ?? this.fromDate,
      toDate: toDate ?? this.toDate,
      status: status ?? this.status,
      staffStatus: staffStatus ?? this.staffStatus,
      hodStatus: hodStatus ?? this.hodStatus,
      timestamp: timestamp ?? this.timestamp,
      createdAt: createdAt ?? this.createdAt,
      additionalData: additionalData ?? this.additionalData,
    );
  }

  @override
  List<Object?> get props => [
        id,
        studentEmail,
        subject,
        reason,
        fromDate,
        toDate,
        status,
        staffStatus,
        hodStatus,
        timestamp,
        createdAt,
      ];
}
