import 'package:equatable/equatable.dart';
import '../../domain/models/od_request_model.dart';

abstract class ODState extends Equatable {
  const ODState();

  @override
  List<Object?> get props => [];
}

class ODInitial extends ODState {
  const ODInitial();
}

class ODLoading extends ODState {
  const ODLoading();
}

class ODLoaded extends ODState {
  final List<ODRequestModel> requests;
  final String currentFilter;
  final int pendingCount;
  final int acceptedCount;
  final int rejectedCount;

  const ODLoaded({
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

  ODLoaded copyWith({
    List<ODRequestModel>? requests,
    String? currentFilter,
    int? pendingCount,
    int? acceptedCount,
    int? rejectedCount,
  }) {
    return ODLoaded(
      requests: requests ?? this.requests,
      currentFilter: currentFilter ?? this.currentFilter,
      pendingCount: pendingCount ?? this.pendingCount,
      acceptedCount: acceptedCount ?? this.acceptedCount,
      rejectedCount: rejectedCount ?? this.rejectedCount,
    );
  }
}

class ODError extends ODState {
  final String message;

  const ODError({required this.message});

  @override
  List<Object?> get props => [message];
}

class ODRequestCreated extends ODState {
  final ODRequestModel request;

  const ODRequestCreated({required this.request});

  @override
  List<Object?> get props => [request];
}

class ODRequestUpdated extends ODState {
  final ODRequestModel request;

  const ODRequestUpdated({required this.request});

  @override
  List<Object?> get props => [request];
}

class ODRequestDeleted extends ODState {
  final String requestId;

  const ODRequestDeleted({required this.requestId});

  @override
  List<Object?> get props => [requestId];
}

class ODRequestApproved extends ODState {
  final String requestId;

  const ODRequestApproved({required this.requestId});

  @override
  List<Object?> get props => [requestId];
}

class ODRequestRejected extends ODState {
  final String requestId;

  const ODRequestRejected({required this.requestId});

  @override
  List<Object?> get props => [requestId];
}
