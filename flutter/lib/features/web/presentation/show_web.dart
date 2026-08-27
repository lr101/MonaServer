import 'package:buff_lisa/widgets/custom_interaction/presentation/custom_error_snack_bar.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:url_launcher/url_launcher.dart'; // Ensure you add this package
import 'package:webview_flutter/webview_flutter.dart';

class ShowWebWidget extends ConsumerStatefulWidget {
  const ShowWebWidget({super.key, required this.route, required this.title});

  final String route;
  final String title;

  @override
  ConsumerState<ShowWebWidget> createState() => ShowWebWidgetState();
}

class ShowWebWidgetState extends ConsumerState<ShowWebWidget> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();

    if (kIsWeb) {
      // Defer the redirect slightly so the widget tree can safely mount first
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _performWebRedirect();
      });
    } else {
      // Initialize the controller exactly ONCE for mobile
      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.disabled)
        ..setNavigationDelegate(
          NavigationDelegate(
            onProgress: (int progress) {},
            onPageStarted: (String url) {},
            onPageFinished: (String url) {},
            onWebResourceError: (WebResourceError error) {},
            onNavigationRequest: (NavigationRequest request) =>
                NavigationDecision.navigate,
          ),
        )
        ..loadRequest(Uri.parse(widget.route));
    }
  }

  Future<void> _performWebRedirect() async {
    // We use ref.read here safely since it's inside an isolated function
    final url = Uri.parse(widget.route);
    debugPrint(widget.route);
    
    if (await canLaunchUrl(url)) {
      // webOnlyWindowName: '_self' forces it to act as a redirect in the current tab
      await launchUrl(url);
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      
    } else {
      CustomErrorSnackBar.message(message: "Failed to open URL: ${widget.route}", type: CustomErrorSnackBarType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    // On the web, show a simple loading state while the browser executes the redirect
    if (kIsWeb) {
      return Scaffold(
        appBar: AppBar(
        title: Text(widget.title, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // Standard mobile UI
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: WebViewWidget(controller: _controller), // Passed the cached controller
      floatingActionButton: Padding(
        padding: const EdgeInsets.all(10),
        child: FloatingActionButton(
          heroTag: widget.key.toString(),
          onPressed: copyToClip, 
          child: const Icon(Icons.copy),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endDocked,
    );
  }

  void copyToClip() {
    Clipboard.setData(
      ClipboardData(text: widget.route),
    );
    
    Fluttertoast.showToast(
      msg: "${widget.title} url copied to clipboard", 
      toastLength: Toast.LENGTH_SHORT, 
      gravity: ToastGravity.CENTER,
    );
  }
}
