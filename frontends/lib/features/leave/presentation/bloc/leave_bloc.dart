import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mongo_dart/mongo_dart.dart' as mongo;
import '../../../../core/config/local_config.dart';
import '../../domain/models/leave_request_model.dart';
import 'leave_event.dart';
import 'leave_state.dart';

class LeaveBloc extends Bloc<LeaveEvent, LeaveState> {
  final String mongoUri = LocalConfig.mongoUri;
  final String collectionName = "leave_requests";

  LeaveBloc() : super(const LeaveInitial()) {
    on<FetchLeaveRequests>(_onFetchLeaveRequests);
    on<CreateLeaveRequest>(_onCreateLeaveRequest);
    on<UpdateLeaveRequest>(_onUpdateLeaveRequest);
    on<DeleteLeaveRequest>(_onDeleteLeaveRequest);
    on<FilterLeaveRequests>(_onFilterLeaveRequests);
    on<ApproveLeaveRequest>(_onApproveLeaveRequest);
    on<RejectLeaveRequest>(_onRejectLeaveRequest);
    on<FetchStaffLeaveRequests>(_onFetchStaffLeaveRequests);
    on<FetchHODLeaveRequests>(_onFetchHODLeaveRequests);
  }

  Future<void> _onFetchLeaveRequests(
    FetchLeaveRequests event,
    Emitter<LeaveState> emit,
  ) async {
    emit(const LeaveLoading());

    try {
      final db = await mongo.Db.create(mongoUri);
      await db.open();
      final collection = db.collection(collectionName);

      final result = await collection
          .find(
            mongo.where
                .eq("studentEmail", event.studentEmail)
                .sortBy('createdAt', descending: true),
          )
          .toList();

      await db.close();

      // Convert to models
      List<LeaveRequestModel> allRequests =
          result.map((json) => LeaveRequestModel.fromJson(json)).toList();

      // Apply filter
      List<LeaveRequestModel> filteredRequests = allRequests;
      if (event.filterStatus != null && event.filterStatus != 'All') {
        filteredRequests = allRequests
            .where((request) =>
                request.status.toLowerCase() ==
                event.filterStatus!.toLowerCase())
            .toList();
      }

      // Sort by timestamp
      filteredRequests.sort((a, b) {
        final timestampA = a.timestamp ?? a.createdAt ?? '';
        final timestampB = b.timestamp ?? b.createdAt ?? '';
        return timestampB.compareTo(timestampA);
      });

      // Calculate counts
      final pendingCount = allRequests
          .where((r) => r.status.toLowerCase() == 'pending')
          .length;
      final acceptedCount = allRequests
          .where((r) => r.status.toLowerCase() == 'accepted')
          .length;
      final rejectedCount = allRequests
          .where((r) => r.status.toLowerCase() == 'rejected')
          .length;

      emit(LeaveLoaded(
        requests: filteredRequests,
        currentFilter: event.filterStatus ?? 'All',
        pendingCount: pendingCount,
        acceptedCount: acceptedCount,
        rejectedCount: rejectedCount,
      ));
    } catch (e) {
      emit(LeaveError(message: e.toString()));
    }
  }

  Future<void> _onCreateLeaveRequest(
    CreateLeaveRequest event,
    Emitter<LeaveState> emit,
  ) async {
    emit(const LeaveLoading());

    try {
      final db = await mongo.Db.create(mongoUri);
      await db.open();
      final collection = db.collection(collectionName);

      final requestData = event.request.toJson();
      requestData['createdAt'] = DateTime.now().toIso8601String();
      requestData['timestamp'] = DateTime.now().toIso8601String();
      requestData['status'] = 'pending';

      await collection.insert(requestData);
      await db.close();

      emit(LeaveRequestCreated(request: event.request));
    } catch (e) {
      emit(LeaveError(message: 'Failed to create request: ${e.toString()}'));
    }
  }

  Future<void> _onUpdateLeaveRequest(
    UpdateLeaveRequest event,
    Emitter<LeaveState> emit,
  ) async {
    emit(const LeaveLoading());

    try {
      final db = await mongo.Db.create(mongoUri);
      await db.open();
      final collection = db.collection(collectionName);

      await collection.update(
        mongo.where.eq('_id', mongo.ObjectId.fromHexString(event.requestId)),
        event.updatedRequest.toJson(),
      );

      await db.close();

      emit(LeaveRequestUpdated(request: event.updatedRequest));
    } catch (e) {
      emit(LeaveError(message: 'Failed to update request: ${e.toString()}'));
    }
  }

  Future<void> _onDeleteLeaveRequest(
    DeleteLeaveRequest event,
    Emitter<LeaveState> emit,
  ) async {
    emit(const LeaveLoading());

    try {
      final db = await mongo.Db.create(mongoUri);
      await db.open();
      final collection = db.collection(collectionName);

      await collection.remove(
        mongo.where.eq('_id', mongo.ObjectId.fromHexString(event.requestId)),
      );

      await db.close();

      emit(LeaveRequestDeleted(requestId: event.requestId));
    } catch (e) {
      emit(LeaveError(message: 'Failed to delete request: ${e.toString()}'));
    }
  }

  Future<void> _onFilterLeaveRequests(
    FilterLeaveRequests event,
    Emitter<LeaveState> emit,
  ) async {
    if (state is LeaveLoaded) {
      final currentState = state as LeaveLoaded;
      emit(currentState.copyWith(currentFilter: event.filter));
    }
  }

  Future<void> _onApproveLeaveRequest(
    ApproveLeaveRequest event,
    Emitter<LeaveState> emit,
  ) async {
    emit(const LeaveLoading());

    try {
      final db = await mongo.Db.create(mongoUri);
      await db.open();
      final collection = db.collection(collectionName);

      final updateData = <String, dynamic>{};
      if (event.approverRole == 'staff') {
        updateData['staffStatus'] = 'accepted';
      } else if (event.approverRole == 'hod') {
        updateData['hodStatus'] = 'accepted';
        updateData['status'] = 'accepted';
      }

      await collection.update(
        mongo.where.eq('_id', mongo.ObjectId.fromHexString(event.requestId)),
        mongo.modify.set('staffStatus', updateData['staffStatus'] ?? '')
            .set('hodStatus', updateData['hodStatus'] ?? '')
            .set('status', updateData['status'] ?? ''),
      );

      await db.close();

      emit(LeaveRequestApproved(requestId: event.requestId));
    } catch (e) {
      emit(LeaveError(message: 'Failed to approve request: ${e.toString()}'));
    }
  }

  Future<void> _onRejectLeaveRequest(
    RejectLeaveRequest event,
    Emitter<LeaveState> emit,
  ) async {
    emit(const LeaveLoading());

    try {
      final db = await mongo.Db.create(mongoUri);
      await db.open();
      final collection = db.collection(collectionName);

      final updateData = <String, dynamic>{};
      if (event.approverRole == 'staff') {
        updateData['staffStatus'] = 'rejected';
        updateData['status'] = 'rejected';
      } else if (event.approverRole == 'hod') {
        updateData['hodStatus'] = 'rejected';
        updateData['status'] = 'rejected';
      }

      if (event.reason != null) {
        updateData['rejectionReason'] = event.reason;
      }

      await collection.update(
        mongo.where.eq('_id', mongo.ObjectId.fromHexString(event.requestId)),
        mongo.modify.set('staffStatus', updateData['staffStatus'] ?? '')
            .set('hodStatus', updateData['hodStatus'] ?? '')
            .set('status', updateData['status'] ?? '')
            .set('rejectionReason', updateData['rejectionReason'] ?? ''),
      );

      await db.close();

      emit(LeaveRequestRejected(requestId: event.requestId));
    } catch (e) {
      emit(LeaveError(message: 'Failed to reject request: ${e.toString()}'));
    }
  }

  Future<void> _onFetchStaffLeaveRequests(
    FetchStaffLeaveRequests event,
    Emitter<LeaveState> emit,
  ) async {
    emit(const LeaveLoading());

    try {
      final db = await mongo.Db.create(mongoUri);
      await db.open();
      final collection = db.collection(collectionName);

      final result = await collection
          .find(
            mongo.where
                .eq("year", event.year)
                .eq("section", event.section)
                .sortBy('createdAt', descending: true),
          )
          .toList();

      await db.close();

      List<LeaveRequestModel> requests =
          result.map((json) => LeaveRequestModel.fromJson(json)).toList();

      final pendingCount =
          requests.where((r) => r.status.toLowerCase() == 'pending').length;
      final acceptedCount =
          requests.where((r) => r.status.toLowerCase() == 'accepted').length;
      final rejectedCount =
          requests.where((r) => r.status.toLowerCase() == 'rejected').length;

      emit(LeaveLoaded(
        requests: requests,
        pendingCount: pendingCount,
        acceptedCount: acceptedCount,
        rejectedCount: rejectedCount,
      ));
    } catch (e) {
      emit(LeaveError(message: e.toString()));
    }
  }

  Future<void> _onFetchHODLeaveRequests(
    FetchHODLeaveRequests event,
    Emitter<LeaveState> emit,
  ) async {
    emit(const LeaveLoading());

    try {
      final db = await mongo.Db.create(mongoUri);
      await db.open();
      final collection = db.collection(collectionName);

      final result = await collection
          .find(
            mongo.where
                .eq("department", event.department)
                .eq("staffStatus", "accepted")
                .sortBy('createdAt', descending: true),
          )
          .toList();

      await db.close();

      List<LeaveRequestModel> requests =
          result.map((json) => LeaveRequestModel.fromJson(json)).toList();

      final pendingCount =
          requests.where((r) => (r.hodStatus ?? 'pending') == 'pending').length;
      final acceptedCount =
          requests.where((r) => r.hodStatus == 'accepted').length;
      final rejectedCount =
          requests.where((r) => r.hodStatus == 'rejected').length;

      emit(LeaveLoaded(
        requests: requests,
        pendingCount: pendingCount,
        acceptedCount: acceptedCount,
        rejectedCount: rejectedCount,
      ));
    } catch (e) {
      emit(LeaveError(message: e.toString()));
    }
  }
}
