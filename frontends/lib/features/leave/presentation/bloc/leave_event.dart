import 'package:equatable/equatable.dart';
import '../../domain/models/leave_request_model.dart';

abstract class LeaveEvent extends Equatable {
  const LeaveEvent();

  @override
  List<Object?> get props => [];
}

class FetchLeaveRequests extends LeaveEvent {
  final String studentEmail;
  final String? filterStatus;

  const FetchLeaveRequests({
    required this.studentEmail,
    this.filterStatus,
  });

  @override
  List<Object?> get props => [studentEmail, filterStatus];
}

class CreateLeaveRequest extends LeaveEvent {
  final LeaveRequestModel request;

  const CreateLeaveRequest({required this.request});

  @override
  List<Object?> get props => [request];
}

class UpdateLeaveRequest extends LeaveEvent {
  final String requestId;
  final LeaveRequestModel updatedRequest;

  const UpdateLeaveRequest({
    required this.requestId,
    required this.updatedRequest,
  });

  @override
  List<Object?> get props => [requestId, updatedRequest];
}

class DeleteLeaveRequest extends LeaveEvent {
  final String requestId;

  const DeleteLeaveRequest({required this.requestId});

  @override
  List<Object?> get props => [requestId];
}

class FilterLeaveRequests extends LeaveEvent {
  final String filter;

  const FilterLeaveRequests({required this.filter});

  @override
  List<Object?> get props => [filter];
}

class ApproveLeaveRequest extends LeaveEvent {
  final String requestId;
  final String approverRole; // 'staff' or 'hod'

  const ApproveLeaveRequest({
    required this.requestId,
    required this.approverRole,
  });

  @override
  List<Object?> get props => [requestId, approverRole];
}

class RejectLeaveRequest extends LeaveEvent {
  final String requestId;
  final String approverRole; // 'staff' or 'hod'
  final String? reason;

  const RejectLeaveRequest({
    required this.requestId,
    required this.approverRole,
    this.reason,
  });

  @override
  List<Object?> get props => [requestId, approverRole, reason];
}

class FetchStaffLeaveRequests extends LeaveEvent {
  final String staffEmail;
  final String year;
  final String section;

  const FetchStaffLeaveRequests({
    required this.staffEmail,
    required this.year,
    required this.section,
  });

  @override
  List<Object?> get props => [staffEmail, year, section];
}

class FetchHODLeaveRequests extends LeaveEvent {
  final String department;

  const FetchHODLeaveRequests({required this.department});

  @override
  List<Object?> get props => [department];
}
