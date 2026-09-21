class PdfModel {
  final int id;
  final String name;
  final String pdfUrl;

  const PdfModel({required this.id, required this.name, required this.pdfUrl});

  /// Expects {"id": 1, "name": "...", "pdf_url": "..."}.
  factory PdfModel.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'];
    final id = rawId is String ? int.tryParse(rawId) : rawId;
    final name = json['name'];
    final url = json['pdf_url'] ?? json['url'];
    if (id is! int || name is! String || url is! String || url.isEmpty) {
      throw FormatException('Invalid PDF item: $json');
    }
    return PdfModel(id: id, name: name, pdfUrl: url);
  }
}
