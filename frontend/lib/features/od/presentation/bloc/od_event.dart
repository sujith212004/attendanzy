import 'package:equatable/equatable.dart';
import '../../domain/models/od_request_model.dart';

abstract class ODEvent extends Equatable {
  const ODEvent();

  @override
  List<Object?> get props => [];
}

class FetchODRequests extends ODEvent {
  final String studentEmail;
  final String? filterStatus;

  const FetchODRequests({
    required this.studentEmail,
    this.filterStatus,
  });

  @override
  List<Object?> get props => [studentEmail, filterStatus];
}

class CreateODRequest extends ODEvent {
  final ODRequestModel request;

  const CreateODRequest({required this.request});

  @override
  List<Object?> get props => [request];
}

class UpdateODRequest extends ODEvent {
  final String requestId;
  final ODRequestModel updatedRequest;

  const UpdateODRequest({
    required this.requestId,
    required this.updatedRequest,
  });

  @override
  List<Object?> get props => [requestId, updatedRequest];
}

class DeleteODRequest extends ODEvent {
  final String requestId;

  const DeleteODRequest({required this.requestId});

  @override
  List<Object?> get props => [requestId];
}

class FilterODRequests extends ODEvent {
  final String filter;

  const FilterODRequests({required this.filter});

  @override
  List<Object?> get props => [filter];
}

class ApproveODRequest extends ODEvent {
  final String requestId;
  final String approverRole; // 'staff' or 'hod'

  const ApproveODRequest({
    required this.requestId,
    required this.approverRole,
  });

  @override
  List<Object?> get props => [requestId, approverRole];
}

class RejectODRequest extends ODEvent {
  final String requestId;
  final String approverRole; // 'staff' or 'hod'
  final String? reason;

  const RejectODRequest({
    required this.requestId,
    required this.approverRole,
    this.reason,
  });

  @override
  List<Object?> get props => [requestId, approverRole, reason];
}

class FetchStaffODRequests extends ODEvent {
  final String staffEmail;
  final String year;
  final String section;

  const FetchStaffODRequests({
    required this.staffEmail,
    required this.year,
    required this.section,
  });

  @override
  List<Object?> get props => [staffEmail, year, section];
}

class FetchHODODRequests extends ODEvent {
  final String department;

  const FetchHODODRequests({required this.department});

  @override
  List<Object?> get props => [department];
}
