import 'package:flutter/material.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            Text('TodoList App', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'A modern, animated productivity app to manage your daily tasks and notes. '
              'Built with Flutter and Firebase to sync your data securely across devices.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            Text('Highlights', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            const _Bullet(text: 'Beautiful splash animation and smooth transitions'),
            const _Bullet(text: 'Email/Password and Google sign-in'),
            const _Bullet(text: 'Per-user tasks with priority, time, and status'),
            const _Bullet(text: 'Notes with quick edit and delete'),
            const _Bullet(text: 'Light/Dark theme'),
            const _Bullet(text: 'Profile with editable display name'),
            const SizedBox(height: 24),
            Text('Version', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('1.0.0', style: Theme.of(context).textTheme.bodyLarge),
          ],
        ),
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• '),
          Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyLarge)),
        ],
      ),
    );
  }
}
