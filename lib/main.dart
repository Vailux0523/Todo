import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme/theme_provider.dart';
import 'core/services/notification_service.dart';
import 'screens/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/forgot_password_screen.dart';
import 'screens/setup/username_screen.dart';
import 'screens/home/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = (FlutterErrorDetails details) {
    // ignore: avoid_print
    print('FlutterError: \\n${details.exceptionAsString()}\\n${details.stack}');
  };
  // Start the app first to ensure first frame is drawn
  runApp(const MyApp());

  // Initialize local notifications in the background so failures don't block startup
  () async {
    try {
      final notifications = NotificationService();
      await notifications.init();
      await notifications.requestPermissions();
    } catch (e) {
      // Avoid blocking startup on notification errors
      // ignore: avoid_print
      print('Notification init error: $e');
    }
  }();
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ThemeProvider()..loadTheme(),
      child: Consumer<ThemeProvider>(
        builder: (context, theme, _) {
          return MaterialApp(
            title: 'Todo',
            debugShowCheckedModeBanner: false,
            themeMode: theme.themeMode,
            theme: theme.lightTheme,
            darkTheme: theme.darkTheme,
            initialRoute: SplashScreen.routeName,
            routes: {
              SplashScreen.routeName: (_) => const SplashScreen(),
              LoginScreen.routeName: (_) => const LoginScreen(),
              ForgotPasswordScreen.routeName: (_) => const ForgotPasswordScreen(),
              UsernameScreen.routeName: (_) => const UsernameScreen(),
              HomeScreen.routeName: (_) => const HomeScreen(),
            },
          );
        },
      ),
    );
  }
}
// End of file
