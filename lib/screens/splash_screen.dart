import 'dart:async';
import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import 'auth/login_screen.dart';
import 'home/home_screen.dart';
import 'setup/username_screen.dart';
import '../firebase_options.dart';

class SplashScreen extends StatefulWidget {
  static const routeName = '/';
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _prepareAndGo();
  }

  Future<void> _prepareAndGo() async {
    // Small delay to show splash animation
    debugPrint('[Splash] start delay');
    await Future.delayed(const Duration(milliseconds: 1200));

    // Ensure Firebase is initialized (moved from main)
    bool firebaseReady = false;
    try {
      debugPrint('[Splash] initializing Firebase');
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      ).timeout(const Duration(seconds: 8));
      debugPrint('[Splash] Firebase initialized');
      firebaseReady = Firebase.apps.isNotEmpty;
    } catch (e) {
      debugPrint('[Splash] Firebase init error: $e');
      firebaseReady = Firebase.apps.isNotEmpty;
    }

    // If Firebase isn't ready, skip auth and go to Login
    if (!firebaseReady) {
      if (!mounted) return;
      debugPrint('[Splash] Firebase not ready, going to LoginScreen');
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 600),
          pageBuilder: (_, __, ___) => const LoginScreen(),
          transitionsBuilder: (_, animation, __, child) => FadeThroughTransition(
            animation: animation,
            secondaryAnimation: const AlwaysStoppedAnimation(0.0),
            child: child,
          ),
        ),
      );
      return;
    }

    // Wait for the first auth state to become available
    User? user;
    try {
      debugPrint('[Splash] waiting for authStateChanges().first');
      user = await FirebaseAuth.instance.authStateChanges().first.timeout(
        const Duration(seconds: 5),
        onTimeout: () => FirebaseAuth.instance.currentUser,
      );
    } catch (_) {
      debugPrint('[Splash] authStateChanges() threw, using currentUser');
      user = FirebaseAuth.instance.currentUser;
    }

    if (!mounted) {
      debugPrint('[Splash] not mounted, abort');
      return;
    }

    Widget next;
    if (user == null) {
      debugPrint('[Splash] user == null -> LoginScreen');
      next = const LoginScreen();
    } else if ((user.displayName == null || user.displayName!.trim().isEmpty)) {
      debugPrint('[Splash] user has no displayName -> UsernameScreen');
      next = const UsernameScreen();
    } else {
      debugPrint('[Splash] user ok -> HomeScreen');
      next = const HomeScreen();
    }

    if (!mounted) {
      debugPrint('[Splash] not mounted before navigation, abort');
      return;
    }
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 600),
        pageBuilder: (_, __, ___) => next,
        transitionsBuilder: (_, animation, __, child) => FadeThroughTransition(
          animation: animation,
          secondaryAnimation: const AlwaysStoppedAnimation(0.0),
          child: child,
        ),
      ),
    );
    debugPrint('[Splash] navigation pushed');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Local Lottie asset for splash
            Lottie.asset('assets/todo.json', width: 200, repeat: true),
            const SizedBox(height: 24),
            Text(
              'Todo',
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
