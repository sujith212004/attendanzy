import 'package:mongo_dart/mongo_dart.dart';
import 'lib/config/local_config.dart';

// Script to fix all staffStatus values to lowercase in MongoDB
// Run with: dart run fix_database.dart

void main() async {
  final db = await Db.create(LocalConfig.mongoUri);

  try {
    await db.open();
    print('Connected to MongoDB');

    // Fix leave_requests collection
    print('\n=== Fixing leave_requests collection ===');
    final leaveCollection = db.collection('leave_requests');

    // First, let's see what values exist
    print('\nChecking existing staffStatus values...');
    final leaveRequests = await leaveCollection.find().toList();
    final leaveStatuses = <String>{};
    for (var doc in leaveRequests) {
      final status = doc['staffStatus'];
      if (status != null) {
        leaveStatuses.add(status.toString());
      }
    }
    print('Found statuses: ${leaveStatuses.join(", ")}');

    var result = await leaveCollection.updateMany(
      where.eq('staffStatus', 'Approved'),
      modify.set('staffStatus', 'approved'),
    );
    print('Updated ${result.nModified} "Approved" -> "approved"');

    result = await leaveCollection.updateMany(
      where.eq('staffStatus', 'Rejected'),
      modify.set('staffStatus', 'rejected'),
    );
    print('Updated ${result.nModified} "Rejected" -> "rejected"');

    result = await leaveCollection.updateMany(
      where.eq('staffStatus', 'Pending'),
      modify.set('staffStatus', 'pending'),
    );
    print('Updated ${result.nModified} "Pending" -> "pending"');

    // Set default for null/missing staffStatus
    result = await leaveCollection.updateMany(
      where.eq('staffStatus', null),
      modify.set('staffStatus', 'pending'),
    );
    print('Set ${result.nModified} null values -> "pending"');

    // Fix od_requests collection
    print('\n=== Fixing od_requests collection ===');
    final odCollection = db.collection('od_requests');

    // Check existing values
    print('\nChecking existing staffStatus values...');
    final odRequests = await odCollection.find().toList();
    final odStatuses = <String>{};
    for (var doc in odRequests) {
      final status = doc['staffStatus'];
      if (status != null) {
        odStatuses.add(status.toString());
      }
    }
    print('Found statuses: ${odStatuses.join(", ")}');

    result = await odCollection.updateMany(
      where.eq('staffStatus', 'Approved'),
      modify.set('staffStatus', 'approved'),
    );
    print('Updated ${result.nModified} "Approved" -> "approved"');

    result = await odCollection.updateMany(
      where.eq('staffStatus', 'Accepted'),
      modify.set('staffStatus', 'accepted'),
    );
    print('Updated ${result.nModified} "Accepted" -> "accepted"');

    result = await odCollection.updateMany(
      where.eq('staffStatus', 'Rejected'),
      modify.set('staffStatus', 'rejected'),
    );
    print('Updated ${result.nModified} "Rejected" -> "rejected"');

    result = await odCollection.updateMany(
      where.eq('staffStatus', 'Pending'),
      modify.set('staffStatus', 'pending'),
    );
    print('Updated ${result.nModified} "Pending" -> "pending"');

    // Set default for null/missing staffStatus
    result = await odCollection.updateMany(
      where.eq('staffStatus', null),
      modify.set('staffStatus', 'pending'),
    );
    print('Set ${result.nModified} null values -> "pending"');

    // Final check
    print('\n=== Final Status Check ===');
    final leaveAfter = await leaveCollection.find().toList();
    final leaveStatusesAfter = <String, int>{};
    for (var doc in leaveAfter) {
      final status = doc['staffStatus']?.toString() ?? 'null';
      leaveStatusesAfter[status] = (leaveStatusesAfter[status] ?? 0) + 1;
    }
    print('Leave requests by status:');
    leaveStatusesAfter.forEach((status, count) {
      print('  $status: $count');
    });

    final odAfter = await odCollection.find().toList();
    final odStatusesAfter = <String, int>{};
    for (var doc in odAfter) {
      final status = doc['staffStatus']?.toString() ?? 'null';
      odStatusesAfter[status] = (odStatusesAfter[status] ?? 0) + 1;
    }
    print('OD requests by status:');
    odStatusesAfter.forEach((status, count) {
      print('  $status: $count');
    });

    print('\n✅ Database update complete!');
  } catch (e) {
    print('❌ Error: $e');
  } finally {
    await db.close();
    print('Connection closed');
  }
}
