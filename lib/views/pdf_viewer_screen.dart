import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import '../controllers/pdf_controller.dart';
import '../models/pdf_model.dart';

class PdfViewerScreen extends StatefulWidget {
  const PdfViewerScreen({super.key, required this.pdf});

  final PdfModel pdf;

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  final PdfController controller = Get.find<PdfController>();
  String? viewerError;

  @override
  void initState() {
    super.initState();
    // Starts/resumes, or does nothing if a download is already running.
    controller.startDownload(widget.pdf);
  }

  Future<void> _downloadAgain() async {
    setState(() => viewerError = null);
    await controller.discardAndRedownload(widget.pdf);
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.pdf.id;
    return Scaffold(
      appBar: AppBar(title: Text(widget.pdf.name)),
      body: Obx(() {
        final path = controller.downloadedFiles[id];
        if (path != null && viewerError == null) {
          // Always the local file, never the network URL.
          return SfPdfViewer.file(
            File(path),
            onDocumentLoadFailed: (details) =>
                setState(() => viewerError = details.description),
          );
        }

        final error = viewerError ?? controller.downloadErrors[id];
        if (error != null && !controller.downloading.contains(id)) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(error, textAlign: TextAlign.center),
                const SizedBox(height: 12),
                FilledButton(
                  // Viewer errors mean the file is bad: restart from zero.
                  // Network errors keep the partial file and resume.
                  onPressed: viewerError != null
                      ? _downloadAgain
                      : () => controller.startDownload(widget.pdf),
                  child:
                      Text(viewerError != null ? 'Download again' : 'Retry'),
                ),
              ],
            ),
          );
        }

        final fraction = controller.progress[id];
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(value: fraction),
              const SizedBox(height: 16),
              if (fraction != null) Text('${(fraction * 100).floor()}%'),
              const Text('Loading PDF...'),
            ],
          ),
        );
      }),
    );
  }
}
