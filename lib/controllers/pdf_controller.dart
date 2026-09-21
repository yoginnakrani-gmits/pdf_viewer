import 'package:get/get.dart';

import '../models/pdf_model.dart';
import '../services/api_service.dart';
import '../services/download_service.dart';

/// Single app-wide controller (registered once in main.dart as permanent), so
/// list/progress state survives navigation between screens.
class PdfController extends GetxController {
  PdfController({ApiService? apiService, DownloadService? downloadService})
      : _api = apiService ?? ApiService(),
        _downloader = downloadService ?? DownloadService();

  final ApiService _api;
  final DownloadService _downloader;

  final pdfList = <PdfModel>[].obs;
  final isLoading = false.obs;
  final errorMessage = ''.obs;

  /// PDF id -> fraction 0..1 (only when the server reports the total size).
  final progress = <int, double>{}.obs;
  final downloadedFiles = <int, String>{}.obs;
  final downloading = <int>{}.obs;

  /// PDF id -> last download error, and bytes already stored for resume.
  final downloadErrors = <int, String>{}.obs;
  final partialBytes = <int, int>{}.obs;

  Future<void> loadPdfs({bool force = false}) async {
    if (isLoading.value || (pdfList.isNotEmpty && !force)) return;
    isLoading.value = true;
    errorMessage.value = '';
    try {
      final pdfs = await _api.fetchPdfs();
      pdfList.assignAll(pdfs);
      await _restoreLocalState(pdfs);
    } catch (e) {
      errorMessage.value = 'Could not load PDFs: $e';
    } finally {
      isLoading.value = false;
    }
    // Not awaited: downloads run in the background while the list is shown.
    downloadAll();
  }

  /// Starts (or resumes) every PDF that isn't finished. Already-active and
  /// completed PDFs are skipped, so this is safe to call repeatedly.
  void downloadAll() {
    for (final pdf in pdfList) {
      if (!downloadedFiles.containsKey(pdf.id)) startDownload(pdf);
    }
  }

  /// Picks up files left on disk by a previous app run.
  Future<void> _restoreLocalState(List<PdfModel> pdfs) async {
    for (final pdf in pdfs) {
      if (downloading.contains(pdf.id)) continue;
      final path = await _downloader.completedPath(pdf.id);
      if (path != null) {
        downloadedFiles[pdf.id] = path;
        progress[pdf.id] = 1.0;
      } else {
        final bytes = await _downloader.partialBytes(pdf.id);
        if (bytes > 0) partialBytes[pdf.id] = bytes;
      }
    }
  }

  /// Starts or resumes a download. No-op if this PDF is already downloading,
  /// so screens can call it freely and just observe the shared state.
  Future<void> startDownload(PdfModel pdf) async {
    if (downloading.contains(pdf.id)) return;
    downloading.add(pdf.id);
    downloadErrors.remove(pdf.id);
    try {
      final path = await _downloader.download(pdf, onProgress: (fraction) {
        final previous = progress[pdf.id] ?? 0;
        // Only notify listeners when the whole percent changes.
        if ((fraction * 100).floor() != (previous * 100).floor()) {
          progress[pdf.id] = fraction;
        }
      });
      progress[pdf.id] = 1.0;
      partialBytes.remove(pdf.id);
      downloadedFiles[pdf.id] = path;
    } catch (e) {
      downloadErrors[pdf.id] = e.toString();
      final bytes = await _downloader.partialBytes(pdf.id);
      if (bytes > 0) partialBytes[pdf.id] = bytes;
    } finally {
      downloading.remove(pdf.id);
    }
  }

  /// Deletes a broken/missing local file and downloads it again from zero.
  Future<void> discardAndRedownload(PdfModel pdf) async {
    if (downloading.contains(pdf.id)) return;
    await _downloader.delete(pdf.id);
    downloadedFiles.remove(pdf.id);
    progress.remove(pdf.id);
    partialBytes.remove(pdf.id);
    await startDownload(pdf);
  }
}
