import 'package:flutter/material.dart';

/// Web stub — InAppWebView is not available on web.
/// This file is selected by the conditional import in billing_screen.dart
/// when running on web (dart.library.html is available).
class ChapaWebViewScreen extends StatelessWidget {
  const ChapaWebViewScreen(
      {super.key, required this.checkoutUrl, this.txRef});
  final String checkoutUrl;
  final String? txRef;

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('WebView not available on web.')),
    );
  }
}
