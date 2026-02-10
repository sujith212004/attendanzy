import 'package:equatable/equatable.dart';
import '../../domain/models/leave_request_model.dart';

abstract class LeaveState extends Equatable {
  const LeaveState();

  @override
  List<Object?> get props => [];
}

class LeaveInitial extends LeaveState {
  const LeaveInitial();
}

class LeaveLoading extends LeaveState {
  const LeaveLoading();
}

class LeaveLoaded extends LeaveState {
  final List<LeaveRequestModel> requests;
  final String currentFilter;
  final int pendingCount;
  final int acceptedCount;
  final int rejectedCount;

  const LeaveLoaded({
    required this.requests,
    this.currentFilter = 'All',
    this.pendingCount = 0,
    this.acceptedCount = 0,
    this.rejectedCount = 0,
  });

  @override
  List<Object?> get props => [
        requests,
        currentFilter,
        pendingCount,
        acceptedCount,
        rejectedCount,
      ];

  LeaveLoaded copyWith({
    List<LeaveRequestModel>? requests,
    String? currentFilter,
    int? pendingCount,
    int? acceptedCount,
    int? rejectedCount,
  }) {
    return LeaveLoaded(
      requests: requests ?? this.requests,
      currentFilter: currentFilter ?? this.currentFilter,
      pendingCount: pendingCount ?? this.pendingCount,
      acceptedCount: acceptedCount ?? this.acceptedCount,
      rejectedCount: rejectedCount ?? this.rejectedCount,
    );
  }
}

class LeaveError extends LeaveState {
  final String message;

  const LeaveError({required this.message});

  @override
  List<Object?> get props => [message];
}

class LeaveRequestCreated extends LeaveState {
  final LeaveRequestModel request;

  const LeaveRequestCreated({required this.request});

  @override
  List<Object?> get props => [request];
}

class LeaveRequestUpdated extends LeaveState {
  final LeaveRequestModel request;

  const LeaveRequestUpdated({required this.request});

  @override
  List<Object?> get props => [request];
}

class LeaveRequestDeleted extends LeaveState {
  final String requestId;

  const LeaveRequestDeleted({required this.requestId});

  @override
  List<Object?> get props => [requestId];
}

class LeaveRequestApproved extends LeaveState {
  final String requestId;

  const LeaveRequestApproved({required this.requestId});

  @override
  List<Object?> get props => [requestId];
}

class LeaveRequestRejected extends LeaveState {
  final String requestId;

  const LeaveRequestRejected({required this.requestId});

  @override
  List<Object?> get props => [requestId];
}
