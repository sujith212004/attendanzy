import 'package:equatable/equatable.dart';
import '../../domain/models/issue_model.dart';

abstract class IssueState extends Equatable {
  const IssueState();

  @override
  List<Object?> get props => [];
}

class IssueInitial extends IssueState {
  const IssueInitial();
}

class IssueLoading extends IssueState {
  const IssueLoading();
}

class IssueLoaded extends IssueState {
  final List<IssueModel> issues;
  final String currentFilter;
  final int openCount;
  final int resolvedCount;
  final int closedCount;

  const IssueLoaded({
    required this.issues,
    this.currentFilter = 'All',
    this.openCount = 0,
    this.resolvedCount = 0,
    this.closedCount = 0,
  });

  @override
  List<Object?> get props => [
        issues,
        currentFilter,
        openCount,
        resolvedCount,
        closedCount,
      ];

  IssueLoaded copyWith({
    List<IssueModel>? issues,
    String? currentFilter,
    int? openCount,
    int? resolvedCount,
    int? closedCount,
  }) {
    return IssueLoaded(
      issues: issues ?? this.issues,
      currentFilter: currentFilter ?? this.currentFilter,
      openCount: openCount ?? this.openCount,
      resolvedCount: resolvedCount ?? this.resolvedCount,
      closedCount: closedCount ?? this.closedCount,
    );
  }
}

class IssueError extends IssueState {
  final String message;

  const IssueError({required this.message});

  @override
  List<Object?> get props => [message];
}

class IssueCreated extends IssueState {
  final IssueModel issue;

  const IssueCreated({required this.issue});

  @override
  List<Object?> get props => [issue];
}

class IssueUpdated extends IssueState {
  final IssueModel issue;

  const IssueUpdated({required this.issue});

  @override
  List<Object?> get props => [issue];
}

class IssueDeleted extends IssueState {
  final String issueId;

  const IssueDeleted({required this.issueId});

  @override
  List<Object?> get props => [issueId];
}

class IssueResolved extends IssueState {
  final String issueId;

  const IssueResolved({required this.issueId});

  @override
  List<Object?> get props => [issueId];
}

class IssueAssigned extends IssueState {
  final String issueId;
  final String assignedTo;

  const IssueAssigned({
    required this.issueId,
    required this.assignedTo,
  });

  @override
  List<Object?> get props => [issueId, assignedTo];
}
