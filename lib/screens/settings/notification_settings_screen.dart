import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/services/notification_service.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  bool? _granted;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _checking = true);
    final status = await Permission.notification.status;
    setState(() {
      _checking = false;
      _granted = status.isGranted;
    });
  }

  Future<void> _request() async {
    final ok = await NotificationService().requestPermissions();
    setState(() => _granted = ok);
    if (!ok) {
      await openAppSettings();
      await _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final granted = _granted == true;
    return Scaffold(
      appBar: AppBar(title: const Text('Notification Settings')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              color: granted ? Colors.green.withOpacity(0.1) : Colors.amber.withOpacity(0.2),
              child: ListTile(
                leading: Icon(granted ? Icons.notifications_active : Icons.notifications_off_outlined,
                    color: granted ? Colors.green : Colors.amber.shade800),
                title: Text(granted ? 'Notifications are enabled' : 'Notifications are disabled'),
                subtitle: const Text('Control permission and test reminders from here.'),
                trailing: _checking
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                    : TextButton(onPressed: _refresh, child: const Text('Refresh')),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _request,
              icon: const Icon(Icons.app_settings_alt),
              label: const Text('Request / Open App Settings'),
            ),
            const SizedBox(height: 24),
            Text('Test Notifications', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.tonalIcon(
                  onPressed: () async {
                    await NotificationService().showNow(
                      id: DateTime.now().millisecondsSinceEpoch.remainder(1000000),
                      title: 'Todo',
                      body: 'Immediate test notification',
                    );
                  },
                  icon: const Icon(Icons.notifications_active_outlined),
                  label: const Text('Show now'),
                ),
                FilledButton.tonalIcon(
                  onPressed: () async {
                    await NotificationService().scheduleAt(
                      id: DateTime.now().millisecondsSinceEpoch.remainder(1000000),
                      title: 'Todo Reminder',
                      body: 'Scheduled test (10s)',
                      scheduledTime: DateTime.now().add(const Duration(seconds: 10)),
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Scheduled in 10 seconds')),
                      );
                    }
                  },
                  icon: const Icon(Icons.alarm_add_outlined),
                  label: const Text('Schedule 10s'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'Tip: On some Android devices (MIUI/OneUI/ColorOS), enable heads-up/banners and allow lock screen content under App Notifications settings. Make sure Battery Optimization doesn\'t restrict notifications.',
            ),
          ],
        ),
      ),
    );
  }
}
