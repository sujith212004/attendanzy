import 'dart:io';
import 'package:dio/dio.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';

/// Service to handle file downloads and opening
class FileService {
  static final Dio _dio = Dio();

  /// Downloads a file from the given URL and opens it
  /// [url] The backend download URL
  /// [fileName] The desired name for the saved file
  static Future<void> downloadAndOpenFile({
    required BuildContext context,
    required String url,
    required String fileName,
  }) async {
    try {
      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 15),
              Text('Downloading $fileName...'),
            ],
          ),
          duration: const Duration(seconds: 2),
        ),
      );

      // Get appropriate directory
      Directory? directory;
      if (Platform.isAndroid) {
        directory = Directory('/storage/emulated/0/Download');
        if (!await directory.exists()) {
          directory = await getExternalStorageDirectory();
        }
      } else {
        directory = await getApplicationDocumentsDirectory();
      }

      final String savePath = '${directory!.path}/$fileName';

      // Download the file
      await _dio.download(
        url,
        savePath,
        onReceiveProgress: (count, total) {
          if (total != -1) {
            print(
              'Download progress: ${(count / total * 100).toStringAsFixed(0)}%',
            );
          }
        },
      );

      // Open the file
      final result = await OpenFilex.open(savePath);

      if (result.type != ResultType.done) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open file: ${result.message}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('Error downloading/opening file: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Download failed: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
