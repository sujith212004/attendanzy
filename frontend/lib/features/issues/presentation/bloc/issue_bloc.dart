import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/models/issue_model.dart';
import 'issue_event.dart';
import 'issue_state.dart';

class IssueBloc extends Bloc<IssueEvent, IssueState> {
  // You can inject a repository here for database operations
  IssueBloc() : super(const IssueInitial()) {
    on<FetchIssues>(_onFetchIssues);
    on<CreateIssue>(_onCreateIssue);
    on<UpdateIssue>(_onUpdateIssue);
    on<DeleteIssue>(_onDeleteIssue);
    on<ResolveIssue>(_onResolveIssue);
    on<AssignIssue>(_onAssignIssue);
    on<FilterIssues>(_onFilterIssues);
  }

  Future<void> _onFetchIssues(
    FetchIssues event,
    Emitter<IssueState> emit,
  ) async {
    emit(const IssueLoading());

    try {
      // TODO: Implement actual database fetch logic here
      // This is a placeholder implementation
      await Future.delayed(const Duration(seconds: 1));

      List<IssueModel> issues = [];

      // Apply filter if provided
      if (event.filterStatus != null && event.filterStatus != 'All') {
        issues = issues
            .where((issue) =>
                issue.status.toLowerCase() ==
                event.filterStatus!.toLowerCase())
            .toList();
      }

      // Calculate counts
      final openCount =
          issues.where((i) => i.status.toLowerCase() == 'open').length;
      final resolvedCount =
          issues.where((i) => i.status.toLowerCase() == 'resolved').length;
      final closedCount =
          issues.where((i) => i.status.toLowerCase() == 'closed').length;

      emit(IssueLoaded(
        issues: issues,
        currentFilter: event.filterStatus ?? 'All',
        openCount: openCount,
        resolvedCount: resolvedCount,
        closedCount: closedCount,
      ));
    } catch (e) {
      emit(IssueError(message: e.toString()));
    }
  }

  Future<void> _onCreateIssue(
    CreateIssue event,
    Emitter<IssueState> emit,
  ) async {
    emit(const IssueLoading());

    try {
      // TODO: Implement actual database insert logic
      await Future.delayed(const Duration(seconds: 1));

      emit(IssueCreated(issue: event.issue));
    } catch (e) {
      emit(IssueError(message: 'Failed to create issue: ${e.toString()}'));
    }
  }

  Future<void> _onUpdateIssue(
    UpdateIssue event,
    Emitter<IssueState> emit,
  ) async {
    emit(const IssueLoading());

    try {
      // TODO: Implement actual database update logic
      await Future.delayed(const Duration(seconds: 1));

      emit(IssueUpdated(issue: event.updatedIssue));
    } catch (e) {
      emit(IssueError(message: 'Failed to update issue: ${e.toString()}'));
    }
  }

  Future<void> _onDeleteIssue(
    DeleteIssue event,
    Emitter<IssueState> emit,
  ) async {
    emit(const IssueLoading());

    try {
      // TODO: Implement actual database delete logic
      await Future.delayed(const Duration(seconds: 1));

      emit(IssueDeleted(issueId: event.issueId));
    } catch (e) {
      emit(IssueError(message: 'Failed to delete issue: ${e.toString()}'));
    }
  }

  Future<void> _onResolveIssue(
    ResolveIssue event,
    Emitter<IssueState> emit,
  ) async {
    emit(const IssueLoading());

    try {
      // TODO: Implement actual resolve logic
      await Future.delayed(const Duration(seconds: 1));

      emit(IssueResolved(issueId: event.issueId));
    } catch (e) {
      emit(IssueError(message: 'Failed to resolve issue: ${e.toString()}'));
    }
  }

  Future<void> _onAssignIssue(
    AssignIssue event,
    Emitter<IssueState> emit,
  ) async {
    emit(const IssueLoading());

    try {
      // TODO: Implement actual assign logic
      await Future.delayed(const Duration(seconds: 1));

      emit(IssueAssigned(
        issueId: event.issueId,
        assignedTo: event.assignedTo,
      ));
    } catch (e) {
      emit(IssueError(message: 'Failed to assign issue: ${e.toString()}'));
    }
  }

  Future<void> _onFilterIssues(
    FilterIssues event,
    Emitter<IssueState> emit,
  ) async {
    if (state is IssueLoaded) {
      final currentState = state as IssueLoaded;
      emit(currentState.copyWith(currentFilter: event.filter));
    }
  }
}
