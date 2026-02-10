import 'package:equatable/equatable.dart';
import '../../domain/models/issue_model.dart';

abstract class IssueEvent extends Equatable {
  const IssueEvent();

  @override
  List<Object?> get props => [];
}

class FetchIssues extends IssueEvent {
  final String? studentEmail;
  final String? filterStatus;

  const FetchIssues({
    this.studentEmail,
    this.filterStatus,
  });

  @override
  List<Object?> get props => [studentEmail, filterStatus];
}

class CreateIssue extends IssueEvent {
  final IssueModel issue;

  const CreateIssue({required this.issue});

  @override
  List<Object?> get props => [issue];
}

class UpdateIssue extends IssueEvent {
  final String issueId;
  final IssueModel updatedIssue;

  const UpdateIssue({
    required this.issueId,
    required this.updatedIssue,
  });

  @override
  List<Object?> get props => [issueId, updatedIssue];
}

class DeleteIssue extends IssueEvent {
  final String issueId;

  const DeleteIssue({required this.issueId});

  @override
  List<Object?> get props => [issueId];
}

class ResolveIssue extends IssueEvent {
  final String issueId;
  final String? resolution;

  const ResolveIssue({
    required this.issueId,
    this.resolution,
  });

  @override
  List<Object?> get props => [issueId, resolution];
}

class AssignIssue extends IssueEvent {
  final String issueId;
  final String assignedTo;

  const AssignIssue({
    required this.issueId,
    required this.assignedTo,
  });

  @override
  List<Object?> get props => [issueId, assignedTo];
}

class FilterIssues extends IssueEvent {
  final String filter;

  const FilterIssues({required this.filter});

  @override
  List<Object?> get props => [filter];
}
