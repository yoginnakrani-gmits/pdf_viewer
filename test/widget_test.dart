import 'package:flutter_test/flutter_test.dart';

import 'package:pdf_viewer/main.dart';

void main() {
  testWidgets('Start screen shows title and START button', (tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('PDF Downloader'), findsOneWidget);
    expect(find.text('START'), findsOneWidget);
  });
}
