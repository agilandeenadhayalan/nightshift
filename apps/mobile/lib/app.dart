import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'core/controller.dart';
import 'features/screens.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final state = ref.read(appControllerProvider);
  final router = GoRouter(
    initialLocation: '/home',
    restorationScopeId: 'nightshift-router',
    refreshListenable: state,
    redirect: (context, route) {
      final path = route.matchedLocation;
      if (state.initializing) return path == '/loading' ? null : '/loading';
      if (state.user == null) return path == '/login' ? null : '/login';
      if (state.hasCall) return path == '/call' ? null : '/call';
      if (['/login', '/loading', '/call'].contains(path)) return state.lastPath;
      return null;
    },
    routes: [
      GoRoute(
          path: '/loading',
          builder: (_, __) =>
              const Scaffold(body: Center(child: CircularProgressIndicator()))),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/call', builder: (_, __) => const CallScreen()),
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
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF176B5B),
            surface: const Color(0xFFFAF8F3)),
        scaffoldBackgroundColor: const Color(0xFFFAF8F3),
        appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFFFAF8F3), scrolledUnderElevation: 0),
        inputDecorationTheme:
            const InputDecorationTheme(border: OutlineInputBorder()),
        filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(minimumSize: const Size(48, 52))),
        outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(minimumSize: const Size(48, 52))),
        cardTheme: const CardTheme(
            elevation: 0,
            margin: EdgeInsets.symmetric(vertical: 6),
            color: Color(0xFFF0EEE6)),
      ),
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
