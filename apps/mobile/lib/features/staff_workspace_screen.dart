import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import '../core/controller.dart';
import '../core/staff_workspace.dart';

bool staffNavigationAllowed(Uri origin, String url) {
  final uri = Uri.tryParse(url);
  return uri != null &&
      uri.scheme == 'https' &&
      uri.userInfo.isEmpty &&
      uri.origin == origin.origin &&
      uri.path == '/' &&
      !uri.hasQuery &&
      (!uri.hasFragment || uri.fragment == 'main');
}

class StaffWorkspaceScreen extends ConsumerStatefulWidget {
  const StaffWorkspaceScreen({super.key});
  @override
  ConsumerState<StaffWorkspaceScreen> createState() =>
      _StaffWorkspaceScreenState();
}

class _StaffWorkspaceScreenState extends ConsumerState<StaffWorkspaceScreen> {
  StaffWorkspace? _workspace;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _workspace = ref.read(appControllerProvider).staffWorkspace;
      unawaited(_workspace!.open());
    });
  }

  @override
  void dispose() {
    // Disposal can run during a router rebuild. Invalidate now, so an older
    // route cannot schedule cleanup after a new route has opened staff access.
    _workspace?.close(notify: false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = ref.watch(appControllerProvider), model = app.staffWorkspace;
    final text = app.text;
    final receipt = model.accessRequest;
    final code = model.error?.code;
    final fresh = [
      'STAFF_FRESH_SIGN_IN_REQUIRED',
      'UNAUTHENTICATED',
      'STAFF_PHONE_SIGN_IN_REQUIRED'
    ].contains(code);
    final denied = code == 'STAFF_ACCESS_NOT_APPROVED';
    return Scaffold(
      appBar: AppBar(
        title: Text(text('Staff workspace', 'ஊழியர் பணியிடம்')),
        leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: text('Back to Profile', 'சுயவிவரத்திற்குத் திரும்பு'),
            onPressed: () {
              model.close();
              context.go('/profile');
            }),
      ),
      body: model.ready
          ? StaffBrowser(key: ValueKey(model.cookieGeneration), model: model)
          : ListView(padding: const EdgeInsets.all(24), children: [
              Text(text('Separate staff access', 'தனியான ஊழியர் அணுகல்'),
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 16),
              Text(text(
                  'Only accounts with staff permission can open this workspace. Customer and Listener modes stay the same.',
                  'ஊழியர் அனுமதி உள்ள கணக்குகள் மட்டுமே இந்த பணியிடத்தைத் திறக்கலாம். வாடிக்கையாளர் மற்றும் கேட்பவர் முறைகள் மாறாது.')),
              const SizedBox(height: 24),
              if (model.busy) ...[
                const LinearProgressIndicator(),
                const SizedBox(height: 12),
                Text(text('Checking staff access…',
                    'ஊழியர் அணுகல் சரிபார்க்கப்படுகிறது…')),
              ] else ...[
                Text(fresh
                    ? text(
                        'Sign out of NightShift, then sign in again with a new SMS code before opening staff access.',
                        'NightShift இலிருந்து வெளியேறி, புதிய குறுஞ்செய்திக் குறியீட்டுடன் மீண்டும் உள்நுழைந்த பிறகு ஊழியர் அணுகலைத் திறக்கவும்.')
                    : denied
                        ? text(
                            'Staff access has not been approved for this account.',
                            'இந்தக் கணக்கிற்கு ஊழியர் அணுகல் இன்னும் அங்கீகரிக்கப்படவில்லை.')
                        : code == 'STAFF_SESSION_EXPIRED'
                            ? text(
                                'Staff access expired. Check access again to continue.',
                                'ஊழியர் அணுகல் காலாவதியானது. தொடர மீண்டும் சரிபார்க்கவும்.')
                            : text(
                                'Staff access is unavailable right now. You can check again.',
                                'ஊழியர் அணுகல் தற்போது கிடைக்கவில்லை. மீண்டும் சரிபார்க்கலாம்.')),
                if (receipt != null) ...[
                  const SizedBox(height: 16),
                  Text(receipt.status == 'pending'
                      ? text('Access request pending',
                          'அணுகல் கோரிக்கை நிலுவையில் உள்ளது')
                      : text('Access request provisioned. Check access again.',
                          'அணுகல் கோரிக்கை வழங்கப்பட்டது. மீண்டும் சரிபார்க்கவும்.')),
                  const SizedBox(height: 8),
                  SelectableText(text(
                      'Account reference: ${receipt.accountReference}',
                      'கணக்கு குறிப்பு: ${receipt.accountReference}')),
                  SelectableText(text('Request reference: ${receipt.requestId}',
                      'கோரிக்கை குறிப்பு: ${receipt.requestId}')),
                  Text(text(
                      'A pending request does not grant staff permissions.',
                      'நிலுவையில் உள்ள கோரிக்கை ஊழியர் அனுமதிகளை வழங்காது.')),
                ],
                const SizedBox(height: 24),
                if (model.canRequest)
                  OutlinedButton(
                      onPressed: model.requestAccess,
                      child: Text(text(
                          'Request staff access', 'ஊழியர் அணுகலைக் கோரவும்'))),
                const SizedBox(height: 12),
                FilledButton(
                    onPressed: model.open,
                    child: Text(
                        text('Check staff access', 'ஊழியர் அணுகலைச் சரிபார்'))),
              ],
            ]),
    );
  }
}

class StaffBrowser extends StatefulWidget {
  const StaffBrowser({super.key, required this.model});
  final StaffWorkspace model;
  @override
  State<StaffBrowser> createState() => _StaffBrowserState();
}

class _StaffBrowserState extends State<StaffBrowser> {
  WebViewController? _controller;
  bool _loaded = false;
  late final int generation;
  bool get current =>
      mounted &&
      widget.model.ready &&
      widget.model.cookieGeneration == generation;
  @override
  void initState() {
    super.initState();
    generation = widget.model.cookieGeneration!;
    unawaited(_prepare());
  }

  Future<void> _prepare() async {
    try {
      final model = widget.model, origin = model.origin!;
      final controller =
          WebViewController(onPermissionRequest: (request) => request.deny());
      _controller = controller;
      if (controller.platform is! AndroidWebViewController) {
        throw StateError('Unavailable');
      }
      final android = controller.platform as AndroidWebViewController;
      await AndroidWebViewController.enableDebugging(false);
      if (!current) return;
      await controller.setNavigationDelegate(NavigationDelegate(
        onNavigationRequest: (request) =>
            current && staffNavigationAllowed(origin, request.url)
                ? NavigationDecision.navigate
                : NavigationDecision.prevent,
        onUrlChange: (change) {
          if (current &&
              change.url != null &&
              !staffNavigationAllowed(origin, change.url!)) {
            model.browserFailed();
          }
        },
        onSslAuthError: (error) {
          error.cancel();
          if (current) model.browserFailed();
        },
        onWebResourceError: (error) {
          if (current && error.isForMainFrame == true) model.browserFailed();
        },
        onHttpError: (error) {
          if (current &&
              error.request?.uri == origin.resolve('/') &&
              (error.response?.statusCode ?? 500) >= 400) {
            model.browserFailed();
          }
        },
      ));
      for (final action in <Future<void> Function()>[
        () => android.setAllowFileAccess(false),
        () => android.setAllowContentAccess(false),
        () => android.setGeolocationEnabled(false),
        () => android.setMixedContentMode(MixedContentMode.neverAllow),
        () => android.setMediaPlaybackRequiresUserGesture(true),
        () => android.setOnShowFileSelector((_) async => <String>[]),
        () => (WebViewCookieManager().platform as AndroidWebViewCookieManager)
            .setAcceptThirdPartyCookies(android, false),
        () => controller.setJavaScriptMode(JavaScriptMode.unrestricted),
        () => model.cookies.harden(android.webViewIdentifier, generation),
      ]) {
        if (!current) return;
        await action();
      }
      if (!current) return;
      // No custom header, token, HTML, JavaScript bridge or URL parameter.
      await controller.loadRequest(origin.resolve('/'));
      if (!current) return;
      setState(() => _loaded = true);
    } catch (_) {
      if (current) widget.model.browserFailed();
    }
  }

  @override
  void dispose() {
    unawaited(_controller?.clearCache().catchError((Object _) {}) ??
        Future<void>.value());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => !_loaded || !current
      ? const Center(child: CircularProgressIndicator())
      : WebViewWidget(controller: _controller!);
}
