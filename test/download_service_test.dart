import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_viewer/models/pdf_model.dart';
import 'package:pdf_viewer/services/download_service.dart';

void main() {
  late Directory tempDir;
  late HttpServer server;
  late DownloadService service;
  late PdfModel pdf;
  final content = List<int>.generate(100000, (i) => i % 251);

  // Test knobs
  var supportRange = true;
  var cutAfterBytes = -1; // >=0: close connection after this many body bytes
  final receivedRanges = <String?>[];

  setUp(() async {
    supportRange = true;
    cutAfterBytes = -1;
    receivedRanges.clear();
    tempDir = await Directory.systemTemp.createTemp('pdf_test');
    service = DownloadService(documentsDirectory: () async => tempDir);
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    pdf = PdfModel(
        id: 1, name: 't', pdfUrl: 'http://127.0.0.1:${server.port}/a.pdf');
    server.listen((req) async {
      final range = req.headers.value('range');
      receivedRanges.add(range);
      var start = 0;
      if (supportRange && range != null) {
        start = int.parse(RegExp(r'bytes=(\d+)-').firstMatch(range)!.group(1)!);
        req.response.statusCode = 206;
        req.response.headers.set('Content-Range',
            'bytes $start-${content.length - 1}/${content.length}');
      }
      final body = content.sublist(start);
      req.response.contentLength = body.length;
      if (cutAfterBytes >= 0) {
        // Headers promise the full body; send only part, then drop the socket.
        final socket = await req.response.detachSocket();
        socket.add(body.sublist(0, cutAfterBytes));
        await socket.flush();
        socket.destroy();
      } else {
        req.response.add(body);
        await req.response.close();
      }
    });
  });

  tearDown(() async {
    await server.close(force: true);
    await tempDir.delete(recursive: true);
  });

  Future<List<int>> read(String path) => File(path).readAsBytes();

  test('full download reports progress ending at 1.0', () async {
    final steps = <double>[];
    final path = await service.download(pdf, onProgress: steps.add);
    expect(await read(path), content);
    expect(steps.last, 1.0);
  });

  test('completed file is reused without a request', () async {
    await service.download(pdf, onProgress: (_) {});
    receivedRanges.clear();
    await service.download(pdf, onProgress: (_) {});
    expect(receivedRanges, isEmpty);
  });

  test('interrupted download keeps partial file and resumes with Range (206)',
      () async {
    cutAfterBytes = 40000;
    await expectLater(
        service.download(pdf, onProgress: (_) {}), throwsA(anything));
    final partial = await service.partialBytes(1);
    expect(partial, greaterThan(0));
    expect(partial, lessThan(content.length));

    cutAfterBytes = -1;
    receivedRanges.clear();
    final path = await service.download(pdf, onProgress: (_) {});
    expect(receivedRanges.single, 'bytes=$partial-');
    expect(await read(path), content);
  });

  test('server ignoring Range (200) restarts instead of appending', () async {
    cutAfterBytes = 40000;
    await expectLater(
        service.download(pdf, onProgress: (_) {}), throwsA(anything));
    expect(await service.partialBytes(1), greaterThan(0));

    cutAfterBytes = -1;
    supportRange = false;
    final path = await service.download(pdf, onProgress: (_) {});
    expect(await read(path), content); // not corrupted by appending
  });
}
