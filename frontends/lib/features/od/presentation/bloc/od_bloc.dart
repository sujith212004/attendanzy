import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mongo_dart/mongo_dart.dart' as mongo;
import '../../../../core/config/local_config.dart';
import '../../domain/models/od_request_model.dart';
import 'od_event.dart';
import 'od_state.dart';

class ODBloc extends Bloc<ODEvent, ODState> {
  final String mongoUri = LocalConfig.mongoUri;
  final String collectionName = "od_requests";

  ODBloc() : super(const ODInitial()) {
    on<FetchODRequests>(_onFetchODRequests);
    on<CreateODRequest>(_onCreateODRequest);
    on<UpdateODRequest>(_onUpdateODRequest);
    on<DeleteODRequest>(_onDeleteODRequest);
    on<FilterODRequests>(_onFilterODRequests);
    on<ApproveODRequest>(_onApproveODRequest);
    on<RejectODRequest>(_onRejectODRequest);
    on<FetchStaffODRequests>(_onFetchStaffODRequests);
    on<FetchHODODRequests>(_onFetchHODODRequests);
  }

  Future<void> _onFetchODRequests(
    FetchODRequests event,
    Emitter<ODState> emit,
  ) async {
    emit(const ODLoading());

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
      List<ODRequestModel> allRequests =
          result.map((json) => ODRequestModel.fromJson(json)).toList();

      // Apply filter
      List<ODRequestModel> filteredRequests = allRequests;
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

      emit(ODLoaded(
        requests: filteredRequests,
        currentFilter: event.filterStatus ?? 'All',
        pendingCount: pendingCount,
        acceptedCount: acceptedCount,
        rejectedCount: rejectedCount,
      ));
    } catch (e) {
      emit(ODError(message: e.toString()));
    }
  }

  Future<void> _onCreateODRequest(
    CreateODRequest event,
    Emitter<ODState> emit,
  ) async {
    emit(const ODLoading());

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

      emit(ODRequestCreated(request: event.request));
    } catch (e) {
      emit(ODError(message: 'Failed to create request: ${e.toString()}'));
    }
  }

  Future<void> _onUpdateODRequest(
    UpdateODRequest event,
    Emitter<ODState> emit,
  ) async {
    emit(const ODLoading());

    try {
      final db = await mongo.Db.create(mongoUri);
      await db.open();
      final collection = db.collection(collectionName);

      await collection.update(
        mongo.where.eq('_id', mongo.ObjectId.fromHexString(event.requestId)),
        event.updatedRequest.toJson(),
      );

      await db.close();

      emit(ODRequestUpdated(request: event.updatedRequest));
    } catch (e) {
      emit(ODError(message: 'Failed to update request: ${e.toString()}'));
    }
  }

  Future<void> _onDeleteODRequest(
    DeleteODRequest event,
    Emitter<ODState> emit,
  ) async {
    emit(const ODLoading());

    try {
      final db = await mongo.Db.create(mongoUri);
      await db.open();
      final collection = db.collection(collectionName);

      await collection.remove(
        mongo.where.eq('_id', mongo.ObjectId.fromHexString(event.requestId)),
      );

      await db.close();

      emit(ODRequestDeleted(requestId: event.requestId));
    } catch (e) {
      emit(ODError(message: 'Failed to delete request: ${e.toString()}'));
    }
  }

  Future<void> _onFilterODRequests(
    FilterODRequests event,
    Emitter<ODState> emit,
  ) async {
    if (state is ODLoaded) {
      final currentState = state as ODLoaded;
      // Re-fetch with new filter
      // This would typically trigger FetchODRequests event
      emit(currentState.copyWith(currentFilter: event.filter));
    }
  }

  Future<void> _onApproveODRequest(
    ApproveODRequest event,
    Emitter<ODState> emit,
  ) async {
    emit(const ODLoading());

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

      emit(ODRequestApproved(requestId: event.requestId));
    } catch (e) {
      emit(ODError(message: 'Failed to approve request: ${e.toString()}'));
    }
  }

  Future<void> _onRejectODRequest(
    RejectODRequest event,
    Emitter<ODState> emit,
  ) async {
    emit(const ODLoading());

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

      emit(ODRequestRejected(requestId: event.requestId));
    } catch (e) {
      emit(ODError(message: 'Failed to reject request: ${e.toString()}'));
    }
  }

  Future<void> _onFetchStaffODRequests(
    FetchStaffODRequests event,
    Emitter<ODState> emit,
  ) async {
    emit(const ODLoading());

    try {
      final db = await mongo.Db.create(mongoUri);
      await db.open();
      final collection = db.collection(collectionName);

      // Fetch requests for staff's year and section
      final result = await collection
          .find(
            mongo.where
                .eq("year", event.year)
                .eq("section", event.section)
                .sortBy('createdAt', descending: true),
          )
          .toList();

      await db.close();

      List<ODRequestModel> requests =
          result.map((json) => ODRequestModel.fromJson(json)).toList();

      final pendingCount =
          requests.where((r) => r.status.toLowerCase() == 'pending').length;
      final acceptedCount =
          requests.where((r) => r.status.toLowerCase() == 'accepted').length;
      final rejectedCount =
          requests.where((r) => r.status.toLowerCase() == 'rejected').length;

      emit(ODLoaded(
        requests: requests,
        pendingCount: pendingCount,
        acceptedCount: acceptedCount,
        rejectedCount: rejectedCount,
      ));
    } catch (e) {
      emit(ODError(message: e.toString()));
    }
  }

  Future<void> _onFetchHODODRequests(
    FetchHODODRequests event,
    Emitter<ODState> emit,
  ) async {
    emit(const ODLoading());

    try {
      final db = await mongo.Db.create(mongoUri);
      await db.open();
      final collection = db.collection(collectionName);

      // Fetch requests for department with staff approved status
      final result = await collection
          .find(
            mongo.where
                .eq("department", event.department)
                .eq("staffStatus", "accepted")
                .sortBy('createdAt', descending: true),
          )
          .toList();

      await db.close();

      List<ODRequestModel> requests =
          result.map((json) => ODRequestModel.fromJson(json)).toList();

      final pendingCount =
          requests.where((r) => (r.hodStatus ?? 'pending') == 'pending').length;
      final acceptedCount =
          requests.where((r) => r.hodStatus == 'accepted').length;
      final rejectedCount =
          requests.where((r) => r.hodStatus == 'rejected').length;

      emit(ODLoaded(
        requests: requests,
        pendingCount: pendingCount,
        acceptedCount: acceptedCount,
        rejectedCount: rejectedCount,
      ));
    } catch (e) {
      emit(ODError(message: e.toString()));
    }
  }
}
