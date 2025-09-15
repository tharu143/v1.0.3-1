import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'dart:io';
import 'dart:developer' as developer;
import 'package:package_info_plus/package_info_plus.dart'; // Add this package

import '../utils/error_handler.dart'; // Assuming this is your custom error handler

class PdfViewerScreen extends StatelessWidget {
  final String pdfUrl;
  final String fileName;

  const PdfViewerScreen({
    Key? key,
    required this.pdfUrl,
    required this.fileName,
  }) : super(key: key);

  Future<void> _downloadPdf(BuildContext context) async {
    try {
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      developer.log('Starting download of $fileName');
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Downloading $fileName...')),
      );
      final response = await http.get(Uri.parse(pdfUrl));
      developer.log('HTTP Response: ${response.statusCode}');
      if (response.statusCode == 200) {
        final bytes = response.bodyBytes;
        final dir = await getApplicationDocumentsDirectory();
        developer.log('Saving to: ${dir.path}/$fileName');
        final file = File('${dir.path}/$fileName');
        await file.writeAsBytes(bytes, flush: true);
        if (await file.exists()) {
          developer.log('File exists at ${file.path}');
        } else {
          developer.log('File does not exist at ${file.path}');
        }
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('Downloaded successfully. Opening file...'),
            backgroundColor: Colors.green,
          ),
        );
        // Get package name using package_info_plus
        final packageInfo = await PackageInfo.fromPlatform();
        final packageName = packageInfo.packageName;
        final uri = Uri.parse('content://$packageName.fileprovider/app_flutter/$fileName');
        developer.log('Launching URI: $uri');
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
          developer.log('File opened successfully');
        } else {
          developer.log('Failed to launch URI: $uri');
          scaffoldMessenger.showSnackBar(
            const SnackBar(
              content: Text('No app available to open PDF.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        if (context.mounted) {
          showApiErrorDialog(context,
              statusCode: response.statusCode, message: response.body);
        }
      }
    } catch (e) {
      developer.log('Error during download: $e');
      if (context.mounted) {
        showApiErrorDialog(context, message: "Failed to download PDF: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          fileName,
          style: Theme.of(context).textTheme.titleMedium!.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Theme.of(context).colorScheme.primary,
                Theme.of(context).colorScheme.secondary.withOpacity(0.8),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.download, color: Colors.white),
            onPressed: () => _downloadPdf(context),
            tooltip: 'Download PDF',
          ),
        ],
      ),
      body: SfPdfViewer.network(pdfUrl),
    );
  }
}