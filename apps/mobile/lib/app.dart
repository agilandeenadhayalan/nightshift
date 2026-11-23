import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'core/controller.dart';
import 'features/screens.dart';
import 'features/account_screens.dart';
import 'features/privacy_screens.dart';
import 'features/listener_application_screen.dart';
import 'features/staff_workspace_screen.dart';
import 'features/matching_screen.dart';
import 'features/redesign/design_system.dart';
import 'features/redesign/design_catalog.dart';
import 'features/redesign/commerce_designs.dart';
import 'features/redesign/entry_designs.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final state = ref.read(appControllerProvider);
  final router = GoRouter(
    initialLocation: state.initializing ? '/loading' : state.lastPath,
    restorationScopeId: 'nightshift-router',
    refreshListenable: state,
    redirect: (context, route) {
      final path = route.matchedLocation;
      if (state.initializing) return path == '/loading' ? null : '/loading';
      if (!kReleaseMode &&
          path.startsWith('/designs') &&
          !state.hasCall &&
          !state.showMatching) {
        return null;
      }
      if (state.user == null) {
        if (path == '/privacy' && state.privacy.receipt != null) {
          return '/deletion-status';
        }
        return ['/login', '/phone-login', '/deletion-status'].contains(path)
            ? null
            : '/login';
      }
      if (state.needsOnboarding) {
        return ['/onboarding', '/privacy', '/deletion-status'].contains(path)
            ? null
            : '/onboarding';
      }
      if (state.showMatching) return path == '/matching' ? null : '/matching';
      if (state.hasCall) return path == '/call' ? null : '/call';
      if (path == '/earnings' && !state.isListener) return '/profile';
      if ([
        '/login',
        '/phone-login',
        '/onboarding',
        '/loading',
        '/call',
        '/matching'
      ].contains(path)) {
        return state.lastPath;
      }
      return null;
    },
    routes: [
      GoRoute(
          path: '/loading', builder: (_, __) => const NightshiftSplashScreen()),
      GoRoute(
          path: '/designs', builder: (_, __) => const DesignCollectionScreen()),
      GoRoute(
          path: '/designs/:id',
          builder: (_, route) => DesignReviewScreen(
              id: int.tryParse(route.pathParameters['id'] ?? '') ?? 0)),
      GoRoute(
          path: '/wallet',
          builder: (_, __) => const CommerceDesignScreen(designId: 15)),
      GoRoute(
          path: '/earnings',
          builder: (_, __) => const CommerceDesignScreen(designId: 10)),
      GoRoute(
          path: '/support',
          builder: (_, __) => const CommerceDesignScreen(designId: 35)),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(
          path: '/phone-login', builder: (_, __) => const PhoneLoginScreen()),
      GoRoute(
          path: '/onboarding', builder: (_, __) => const OnboardingScreen()),
      GoRoute(path: '/call', builder: (_, __) => const CallScreen()),
      GoRoute(path: '/matching', builder: (_, __) => const MatchingScreen()),
      GoRoute(path: '/privacy', builder: (_, __) => const PrivacyScreen()),
      GoRoute(path: '/staff', builder: (_, __) => const StaffWorkspaceScreen()),
      GoRoute(
          path: '/listener-application',
          builder: (_, __) => const ListenerApplicationScreen()),
      GoRoute(
          path: '/deletion-status',
          builder: (_, __) => const DeletionStatusScreen()),
      ShellRoute(
          builder: (_, route, child) =>
              HomeShell(path: route.matchedLocation, child: child),
          routes: [
            GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
            GoRoute(
                path: '/history', builder: (_, __) => const HistoryScreen()),
            GoRoute(
                path: '/profile', builder: (_, __) => const ProfileScreen()),
          ]),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

class NightShiftApp extends ConsumerStatefulWidget {
  const NightShiftApp({super.key});
  @override
  ConsumerState<NightShiftApp> createState() => _NightShiftAppState();
}

class _NightShiftAppState extends ConsumerState<NightShiftApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = ref.read(appControllerProvider);
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(controller.setForeground(false));
    } else if (state == AppLifecycleState.resumed) {
      unawaited(controller.setForeground(true));
    }
    // Inactive can be the Android permission dialog. It must not cancel accepting a call.
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(appControllerProvider);
    return MaterialApp.router(
      title: 'NightShift',
      debugShowCheckedModeBanner: false,
      restorationScopeId: 'nightshift',
      locale: Locale(controller.locale),
      supportedLocales: const [Locale('en'), Locale('ta')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      routerConfig: ref.watch(routerProvider),
      theme: nightshiftTheme(),
      builder: (context, child) => kReleaseMode
          ? const Scaffold(
              body: Center(
                  child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                          'This development milestone has no production sign-in. Use the debug APK for test credits.'))))
          : child!,
    );
  }
}
