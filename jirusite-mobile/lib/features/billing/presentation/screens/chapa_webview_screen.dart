import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../../../../app/theme.dart';

/// Mobile-only Chapa checkout WebView screen.
/// Detects the return URL and signals payment completion.
class ChapaWebViewScreen extends StatefulWidget {
  const ChapaWebViewScreen({super.key, required this.checkoutUrl, this.txRef});
  final String checkoutUrl;
  final String? txRef;

  @override
  State<ChapaWebViewScreen> createState() => _ChapaWebViewScreenState();
}

class _ChapaWebViewScreenState extends State<ChapaWebViewScreen> {
  InAppWebViewController? _webCtrl;
  bool _loading = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Chapa Checkout'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context, false),
        ),
        actions: [
          if (_loading)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white)),
              ),
            ),
        ],
      ),
      body: InAppWebView(
        initialUrlRequest: URLRequest(url: WebUri(widget.checkoutUrl)),
        initialSettings: InAppWebViewSettings(
          useShouldOverrideUrlLoading: true,
          javaScriptEnabled: true,
          userAgent: 'JIRUSite/1.0 Flutter',
        ),
        onWebViewCreated: (ctrl) {
          _webCtrl = ctrl;
          ctrl.addJavaScriptHandler(
            handlerName: 'paymentComplete',
            callback: (_) => Navigator.pop(context, true),
          );
        },
        onLoadStop: (ctrl, url) {
          setState(() => _loading = false);
          final urlStr = url?.toString() ?? '';
          if (urlStr.contains('/billing/chapa/return')) {
            Navigator.pop(context, true);
          }
        },
        onLoadStart: (_, __) => setState(() => _loading = true),
        shouldOverrideUrlLoading: (ctrl, action) async {
          final url = action.request.url?.toString() ?? '';
          if (url.contains('/billing/chapa/return')) {
            Navigator.pop(context, true);
            return NavigationActionPolicy.CANCEL;
          }
          return NavigationActionPolicy.ALLOW;
        },
        onReceivedError: (_, __, err) => setState(() => _loading = false),
      ),
    );
  }
}
