import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/pdf_controller.dart';
import '../models/pdf_model.dart';
import 'pdf_viewer_screen.dart';

class PdfListScreen extends StatefulWidget {
  const PdfListScreen({super.key});

  @override
  State<PdfListScreen> createState() => _PdfListScreenState();
}

class _PdfListScreenState extends State<PdfListScreen> {
  final PdfController controller = Get.find<PdfController>();

  @override
  void initState() {
    super.initState();
    // Skipped by the controller if the list is already loaded.
    controller.loadPdfs();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('PDF List')),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }
        if (controller.errorMessage.isNotEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(controller.errorMessage.value,
                    textAlign: TextAlign.center),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => controller.loadPdfs(force: true),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }
        if (controller.pdfList.isEmpty) {
          return const Center(child: Text('No PDFs found'));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: controller.pdfList.length,
          itemBuilder: (_, index) =>
              _PdfCard(pdf: controller.pdfList[index], controller: controller),
        );
      }),
    );
  }
}

class _PdfCard extends StatelessWidget {
  const _PdfCard({required this.pdf, required this.controller});

  final PdfModel pdf;
  final PdfController controller;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Obx(() {
          final isDone = controller.downloadedFiles.containsKey(pdf.id);
          final isActive = controller.downloading.contains(pdf.id);
          final fraction = controller.progress[pdf.id];
          final error = controller.downloadErrors[pdf.id];
          final partial = controller.partialBytes[pdf.id];

          final String status;
          if (isDone) {
            status = '100% - Downloaded';
          } else if (fraction != null) {
            status = '${(fraction * 100).floor()}%';
          } else if (isActive) {
            status = 'Downloading...';
          } else if (partial != null) {
            final mb = (partial / 1048576).toStringAsFixed(1);
            status = 'Paused ($mb MB saved)';
          } else {
            status = '0%';
          }

          final String buttonLabel;
          if (isDone) {
            buttonLabel = 'OPEN PDF';
          } else if (partial != null && !isActive) {
            buttonLabel = 'RESUME & OPEN';
          } else {
            buttonLabel = 'DOWNLOAD & OPEN';
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(pdf.name, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              LinearProgressIndicator(
                // null = indeterminate (size unknown, so no fake percentage)
                value: isDone
                    ? 1.0
                    : (isActive && fraction == null ? null : fraction ?? 0),
              ),
              const SizedBox(height: 8),
              Text(status),
              if (error != null && !isActive)
                Text(error,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error)),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () => Get.to(() => PdfViewerScreen(pdf: pdf)),
                child: Text(buttonLabel),
              ),
            ],
          );
        }),
      ),
    );
  }
}
