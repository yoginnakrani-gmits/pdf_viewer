import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/pdf_model.dart';

class ApiService {
  Future<List<PdfModel>> fetchPdfs() async {
    final body = ApiConfig.useSampleData
        ? await rootBundle.loadString(ApiConfig.sampleAsset)
        : await _get(ApiConfig.pdfListUrl);
    return _parse(body);
  }

  Future<String> _get(String url) async {
    final client = http.Client();
    try {
      final response = await client
          .get(Uri.parse(url), headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) {
        throw Exception('Server returned ${response.statusCode}');
      }
      // allowMalformed: a non-UTF-8 body (e.g. an HTML error page) must reach
      // _parse and produce a readable message instead of a decoder crash.
      return utf8.decode(response.bodyBytes, allowMalformed: true);
    } finally {
      client.close();
    }
  }

  List<PdfModel> _parse(String body) {
    final dynamic decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      final preview = body.trimLeft();
      throw FormatException('Response is not JSON: '
          '${preview.substring(0, preview.length.clamp(0, 60))}');
    }
    // Accept either a bare list or {"data": [...]}.
    final list = decoded is List ? decoded : (decoded is Map ? decoded['data'] : null);
    if (list is! List) {
      throw const FormatException('Expected a JSON list of PDFs');
    }
    return list
        .map((item) => PdfModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}
