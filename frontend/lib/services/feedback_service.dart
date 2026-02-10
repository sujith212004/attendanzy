import 'package:mongo_dart/mongo_dart.dart';
import '../config/local_config.dart';

class FeedbackService {
  static String mongoUrl = LocalConfig.mongoUri;

  static Future<bool> submitFeedback(
    String userEmail,
    String feedback,
    int rating,
  ) async {
    try {
      final db = await Db.create(mongoUrl);
      await db.open();

      final collection = db.collection('feedback');

      await collection.insert({
        'userEmail': userEmail,
        'feedback': feedback,
        'rating': rating,
        'timestamp': DateTime.now().toIso8601String(),
      });

      await db.close();
      return true;
    } catch (e) {
      print('Error submitting feedback: $e');
      return false;
    }
  }
}
