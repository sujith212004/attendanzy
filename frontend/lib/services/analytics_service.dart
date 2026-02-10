import 'package:mongo_dart/mongo_dart.dart' as mongo;
import '../config/local_config.dart';

class AnalyticsService {
  static String mongoUrl = LocalConfig.mongoUri;

  static Future<List<Map<String, dynamic>>> fetchOdRequests() async {
    final db = await mongo.Db.create(mongoUrl);
    await db.open();
    final collection = db.collection('od_requests');
    final results = await collection.find().toList();
    await db.close();
    return List<Map<String, dynamic>>.from(results);
  }

  static Future<List<Map<String, dynamic>>> fetchLeaveRequests() async {
    final db = await mongo.Db.create(mongoUrl);
    await db.open();
    final collection = db.collection('leave_requests');
    final results = await collection.find().toList();
    await db.close();
    return List<Map<String, dynamic>>.from(results);
  }
}
