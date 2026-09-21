import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'controllers/pdf_controller.dart';
import 'views/start_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'PDF Downloader',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      // Created once; permanent so popping routes never disposes it.
      initialBinding: BindingsBuilder(() {
        Get.put(PdfController(), permanent: true);
      }),
      home: const StartScreen(),
    );
  }
}
