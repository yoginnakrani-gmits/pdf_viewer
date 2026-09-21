import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'pdf_list_screen.dart';

class StartScreen extends StatelessWidget {
  const StartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('PDF Downloader',
                style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Get.to(() => const PdfListScreen()),
              child: const Text('START'),
            ),
          ],
        ),
      ),
    );
  }
}
