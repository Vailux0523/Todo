import 'package:flutter/material.dart';
import '../setup/username_screen.dart';
import '../home/home_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/firestore_service.dart';
import '../../core/services/notification_service.dart';

class LoginScreen extends StatefulWidget {
  static const routeName = '/login';
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();

  bool _isLogin = true;
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _firstName.dispose();
    _lastName.dispose();
    super.dispose();
  }

  void _toggle() => setState(() => _isLogin = !_isLogin);

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      UserCredential cred;
      if (_isLogin) {
        cred = await AuthService.instance.signInWithEmail(
          _email.text.trim(),
          _password.text.trim(),
        );
      } else {
        cred = await AuthService.instance.registerWithEmail(
          _email.text.trim(),
          _password.text.trim(),
        );
        final fullName = '${_firstName.text.trim()} ${_lastName.text.trim()}'
            .trim();
        if (fullName.isNotEmpty) {
          await AuthService.instance.updateDisplayName(fullName);
        }
      }
      final user = cred.user!;
      await FirestoreService.instance.ensureUser(
        user.uid,
        email: user.email ?? _email.text.trim(),
        displayName: user.displayName,
      );
      if (!_isLogin) {
        // New user flow: go set username
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, UsernameScreen.routeName);
      } else {
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, HomeScreen.routeName);
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Auth error: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _google() async {
    setState(() => _loading = true);
    try {
      final cred = await AuthService.instance.signInWithGoogle();
      final user = cred.user!;
      await FirestoreService.instance.ensureUser(
        user.uid,
        email: user.email ?? '',
        displayName: user.displayName,
      );
      if ((user.displayName == null || user.displayName!.trim().isEmpty)) {
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, UsernameScreen.routeName);
      } else {
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, HomeScreen.routeName);
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Google sign-in error: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isLogin ? 'Login' : 'Register'),
        actions: [
          IconButton(
            tooltip: 'Test notify now',
            icon: const Icon(Icons.notifications_active_outlined),
            onPressed: () async {
              await NotificationService().showNow(
                id: 100,
                title: 'Todo',
                body: 'Local notification test',
              );
            },
          ),
          IconButton(
            tooltip: 'Schedule (5s)',
            icon: const Icon(Icons.alarm_add_outlined),
            onPressed: () async {
              await NotificationService().scheduleAt(
                id: 101,
                title: 'Todo Reminder',
                body: 'Scheduled in 5 seconds',
                scheduledTime: DateTime.now().add(const Duration(seconds: 5)),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!_isLogin) ...[
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _firstName,
                              decoration: const InputDecoration(
                                labelText: 'First name',
                              ),
                              textCapitalization: TextCapitalization.words,
                              validator: (v) => v != null && v.trim().isNotEmpty
                                  ? null
                                  : 'Required',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _lastName,
                              decoration: const InputDecoration(
                                labelText: 'Last name',
                              ),
                              textCapitalization: TextCapitalization.words,
                              validator: (v) => v != null && v.trim().isNotEmpty
                                  ? null
                                  : 'Required',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextFormField(
                      controller: _email,
                      decoration: const InputDecoration(labelText: 'Email'),
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) => v != null && v.contains('@')
                          ? null
                          : 'Enter valid email',
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _password,
                      decoration: const InputDecoration(labelText: 'Password'),
                      obscureText: true,
                      validator: (v) =>
                          v != null && v.length >= 6 ? null : 'Min 6 chars',
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _isLogin
                            ? () => Navigator.of(
                                context,
                              ).pushNamed('/forgot-password')
                            : null,
                        child: const Text('Forgot password?'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: _loading ? null : _submit,
                      child: Text(_isLogin ? 'Login' : 'Create account'),
                    ),
                    TextButton(
                      onPressed: _toggle,
                      child: Text(
                        _isLogin
                            ? "New here? Register"
                            : "Have an account? Login",
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Row(
                      children: [
                        Expanded(child: Divider()),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Text('OR'),
                        ),
                        Expanded(child: Divider()),
                      ],
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: _loading ? null : _google,
                      borderRadius: BorderRadius.circular(12),
                      child: Ink(
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 16,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Image.asset(
                              'assets/images/google.png',
                              width: 22,
                              height: 22,
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Sign in with Google',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_loading)
                      const Padding(
                        padding: EdgeInsets.only(top: 16.0),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
