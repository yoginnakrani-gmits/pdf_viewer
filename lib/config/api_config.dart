/// Single place for the PDF list source.
class ApiConfig {
  /// true: read the list from assets/sample_pdfs.json (public sample PDFs that
  /// support HTTP Range). false: call [pdfListUrl] instead.
  static const bool useSampleData = true;

  static const String sampleAsset = 'assets/sample_pdfs.json';

  /// Real endpoint, used when [useSampleData] is false.
  static const String pdfListUrl = 'https://example.com/api/pdfs';
}
