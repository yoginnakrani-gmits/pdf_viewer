import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/pdf_model.dart';

class DownloadException implements Exception {
  final String message;
  DownloadException(this.message);

  @override
  String toString() => message;
}

/// Thrown internally when the partial file cannot be continued safely.
class _RestartFromZero implements Exception {}

/// Streams PDFs to `<documents>/pdfs/<id>.pdf`.
///
/// While downloading, bytes go to `<id>.pdf.part`. The file is renamed to
/// `<id>.pdf` only when complete, so "final file exists" always means "done"
/// and the `.part` file's length is always the resume offset.
class DownloadService {
  /// [documentsDirectory] is injectable so tests can use a temp folder.
  DownloadService({Future<Directory> Function()? documentsDirectory})
      : _documentsDirectory =
            documentsDirectory ?? getApplicationDocumentsDirectory;

  final Future<Directory> Function() _documentsDirectory;

  Future<Directory> _pdfDirectory() async {
    final docs = await _documentsDirectory();
    final dir = Directory(p.join(docs.path, 'pdfs'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<File> _finalFile(int id) async =>
      File(p.join((await _pdfDirectory()).path, '$id.pdf'));

  Future<File> _partFile(int id) async =>
      File(p.join((await _pdfDirectory()).path, '$id.pdf.part'));

  /// Path of the finished PDF, or null if it is missing/empty (corrupt state).
  Future<String?> completedPath(int id) async {
    final file = await _finalFile(id);
    if (!await file.exists()) return null;
    if (await file.length() == 0) {
      await file.delete();
      return null;
    }
    return file.path;
  }

  Future<int> partialBytes(int id) async {
    final part = await _partFile(id);
    return await part.exists() ? await part.length() : 0;
  }

  /// Removes both the finished and partial file (used to recover from a bad file).
  Future<void> delete(int id) async {
    for (final file in [await _finalFile(id), await _partFile(id)]) {
      if (await file.exists()) await file.delete();
    }
  }

  /// Downloads (or resumes) the PDF and returns the local path.
  ///
  /// [onProgress] receives downloaded/total in 0..1, only when the total size
  /// is known. If the server sends no Content-Length it is never called.
  Future<String> download(
    PdfModel pdf, {
    required void Function(double fraction) onProgress,
  }) async {
    final done = await completedPath(pdf.id);
    if (done != null) return done;

    try {
      return await _fetch(pdf, await partialBytes(pdf.id), onProgress);
    } on _RestartFromZero {
      await delete(pdf.id);
      return _fetch(pdf, 0, onProgress);
    }
  }

  Future<String> _fetch(
    PdfModel pdf,
    int existingBytes,
    void Function(double fraction) onProgress,
  ) async {
    final part = await _partFile(pdf.id);
    final client = http.Client();
    try {
      final request = http.Request('GET', Uri.parse(pdf.pdfUrl));
      if (existingBytes > 0) {
        request.headers['Range'] = 'bytes=$existingBytes-';
      }
      final response =
          await client.send(request).timeout(const Duration(seconds: 30));

      final int startByte; // offset the first received byte belongs at
      final int? totalBytes; // full file size, null if unknown
      final FileMode mode;

      if (response.statusCode == 206) {
        // Server honoured the Range: the body is only the remaining bytes.
        // Content-Range looks like "bytes 6000000-9999999/10000000".
        final match = RegExp(r'bytes (\d+)-\d+/(\d+|\*)')
            .firstMatch(response.headers['content-range'] ?? '');
        if (match == null || int.parse(match.group(1)!) != existingBytes) {
          throw _RestartFromZero(); // can't verify alignment; don't append
        }
        startByte = existingBytes;
        totalBytes = match.group(2) == '*' ? null : int.parse(match.group(2)!);
        mode = FileMode.append;
      } else if (response.statusCode == 200) {
        // Full body. If we asked for a Range the server ignored it, so the
        // old partial bytes must NOT be appended to; overwrite from zero.
        startByte = 0;
        totalBytes = response.contentLength;
        mode = FileMode.write;
      } else if (response.statusCode == 416 && existingBytes > 0) {
        throw _RestartFromZero(); // partial file doesn't fit the remote file
      } else {
        throw DownloadException('Server returned ${response.statusCode}');
      }

      var receivedBytes = startByte;
      if (totalBytes != null && totalBytes > 0) {
        onProgress(receivedBytes / totalBytes);
      }

      final sink = part.openWrite(mode: mode);
      try {
        await for (final chunk in response.stream) {
          sink.add(chunk);
          receivedBytes += chunk.length;
          if (totalBytes != null && totalBytes > 0) {
            onProgress((receivedBytes / totalBytes).clamp(0.0, 1.0));
          }
        }
      } finally {
        // Flush what we have, even on error, so the partial file is resumable.
        await sink.close();
      }

      if (totalBytes != null && receivedBytes != totalBytes) {
        throw DownloadException(
            'Download interrupted ($receivedBytes of $totalBytes bytes)');
      }
      if (receivedBytes == 0) {
        throw DownloadException('Server returned an empty file');
      }

      final finalFile = await _finalFile(pdf.id);
      await part.rename(finalFile.path);
      return finalFile.path;
    } on SocketException catch (e) {
      throw DownloadException('Network error: ${e.message}');
    } on http.ClientException catch (e) {
      throw DownloadException('Network error: ${e.message}');
    } finally {
      client.close();
    }
  }
}
