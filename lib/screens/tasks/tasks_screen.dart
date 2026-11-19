import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../core/services/firestore_service.dart';
import '../../core/services/notification_service.dart';
import 'package:permission_handler/permission_handler.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  final _title = TextEditingController();
  TimeOfDay? _time;
  String _priority = 'Normal';
  final _player = AudioPlayer();
  bool _notifAllowed = true;

  @override
  void initState() {
    super.initState();
    // Ensure we have notification permission when entering tasks
    _ensureNotifPermission();
  }

  @override
  void dispose() {
    _title.dispose();
    _player.dispose();
    super.dispose();
  }

  Future<void> _ensureNotifPermission() async {
    try {
      final granted = await NotificationService().requestPermissions();
      if (mounted) setState(() => _notifAllowed = granted);
    } catch (_) {
      if (mounted) setState(() => _notifAllowed = false);
    }
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (t != null) setState(() => _time = t);
  }

  Future<void> _addTask() async {
    if (_title.text.trim().isEmpty) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    DateTime? dueAt;
    if (_time != null) {
      final now = DateTime.now();
      var candidate = DateTime(now.year, now.month, now.day, _time!.hour, _time!.minute);
      // If the chosen time already passed today, schedule for tomorrow
      if (candidate.isBefore(now)) {
        candidate = candidate.add(const Duration(days: 1));
      }
      dueAt = candidate;
    }
    await FirestoreService.instance.addTask(
      user.uid,
      title: _title.text.trim(),
      priority: _priority,
      dueAt: dueAt,
    );
    // Schedule a local notification if a due time is provided
    if (dueAt != null) {
      try {
        await NotificationService().scheduleAt(
          id: DateTime.now().millisecondsSinceEpoch.remainder(1000000),
          title: 'Todo Reminder',
          body: 'Task: ${_title.text.trim()} (${_priority})',
          scheduledTime: dueAt,
        );
        // Also inform user that the task is pending
        await NotificationService().showNow(
          id: DateTime.now().millisecondsSinceEpoch.remainder(1000000),
          title: 'Your task is pending',
          body: _title.text.trim(),
        );
      } catch (_) {}
    }
    _title.clear();
    setState(() => _time = null);
    // Play sound for task added (pending)
    try {
      await _player.stop();
      await _player.play(AssetSource('audio/pending.mpeg'));
    } catch (_) {}
  }

  Future<void> _setStatus(String taskId, String status) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await FirestoreService.instance.setTaskStatus(user.uid, taskId, status);
    // Play sound based on status
    try {
      await _player.stop();
      switch (status) {
        case 'completed':
          await _player.play(AssetSource('audio/complete.mpeg'));
          // Notify completion
          await NotificationService().showNow(
            id: DateTime.now().millisecondsSinceEpoch.remainder(1000000),
            title: 'Task completed',
            body: 'Great job! Your task was marked completed.',
          );
          break;
        case 'missed':
          await _player.play(AssetSource('audio/missed.mpeg'));
          // Notify missed
          await NotificationService().showNow(
            id: DateTime.now().millisecondsSinceEpoch.remainder(1000000),
            title: 'Your task is missed',
            body: 'Open Todo to review and reschedule.',
          );
          break;
        default:
          // no sound for switching back to pending here
          break;
      }
    } catch (_) {}
  }

  Future<void> _deleteTask(String taskId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await FirestoreService.instance.deleteTask(user.uid, taskId);
  }

  Future<void> _editTask(String taskId, Map<String, dynamic> data) async {
    final titleCtrl = TextEditingController(text: (data['title'] as String?) ?? '');
    String priority = (data['priority'] as String?) ?? 'Normal';
    TimeOfDay? time;
    final ts = data['dueAt'] as Timestamp?;
    if (ts != null) {
      final dt = ts.toDate();
      time = TimeOfDay.fromDateTime(dt);
    }

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setStateSB) {
          return AlertDialog(
            title: const Text('Edit Task'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(labelText: 'Title'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: priority,
                    decoration: const InputDecoration(labelText: 'Priority'),
                    items: const [
                      DropdownMenuItem(value: 'Low', child: Text('Low')),
                      DropdownMenuItem(value: 'Normal', child: Text('Normal')),
                      DropdownMenuItem(value: 'High', child: Text('High')),
                    ],
                    onChanged: (v) => setStateSB(() => priority = v ?? 'Normal'),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final pick = await showTimePicker(
                              context: context,
                              initialTime: time ?? TimeOfDay.now(),
                            );
                            if (pick != null) setStateSB(() => time = pick);
                          },
                          icon: const Icon(Icons.access_time),
                          label: Text(time == null ? 'Pick time' : time!.format(context)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: 'Clear time',
                        onPressed: () => setStateSB(() => time = null),
                        icon: const Icon(Icons.clear),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              FilledButton(
                onPressed: () async {
                  final user = FirebaseAuth.instance.currentUser;
                  if (user == null) return;
                  DateTime? dueAt;
                  if (time != null) {
                    final now = DateTime.now();
                    var candidate = DateTime(now.year, now.month, now.day, time!.hour, time!.minute);
                    if (candidate.isBefore(now)) candidate = candidate.add(const Duration(days: 1));
                    dueAt = candidate;
                  }
                  await FirestoreService.instance.updateTask(
                    user.uid,
                    taskId,
                    title: titleCtrl.text.trim(),
                    priority: priority,
                    dueAt: dueAt,
                  );
                  if (dueAt != null) {
                    try {
                      await NotificationService().scheduleAt(
                        id: DateTime.now().millisecondsSinceEpoch.remainder(1000000),
                        title: 'Todo Reminder',
                        body: 'Task: ${titleCtrl.text.trim()} ($priority)',
                        scheduledTime: dueAt,
                      );
                    } catch (_) {}
                  }
                  if (context.mounted) Navigator.pop(ctx);
                },
                child: const Text('Save'),
              ),
            ],
          );
        });
      },
    );
  }

  Future<void> _autoMarkMissed(DocumentSnapshot<Map<String, dynamic>> doc) async {
    final data = doc.data();
    if (data == null) return;
    if (data['status'] == 'pending' && data['dueAt'] != null) {
      final due = (data['dueAt'] as Timestamp).toDate();
      if (DateTime.now().isAfter(due)) {
        await _setStatus(doc.id, 'missed');
        // Show a notification for missed task
        try {
          await NotificationService().showNow(
            id: DateTime.now().millisecondsSinceEpoch.remainder(1000000),
            title: 'Your task is missed',
            body: (data['title'] as String?) ?? 'Open Todo to review and reschedule.',
          );
        } catch (_) {}
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          if (!_notifAllowed)
            Card(
              color: Colors.amber.shade100,
              child: ListTile(
                leading: const Icon(Icons.notifications_off_outlined),
                title: const Text('Notifications are disabled'),
                subtitle: const Text('Enable notifications to get task reminders.'),
                trailing: TextButton(
                  onPressed: () async {
                    try {
                      final granted = await NotificationService().requestPermissions();
                      if (!granted) {
                        // Open OS app settings as a fallback
                        // ignore: use_build_context_synchronously
                        await openAppSettings();
                      }
                      // Re-check when returning
                      await _ensureNotifPermission();
                    } catch (_) {}
                  },
                  child: const Text('Enable'),
                ),
              ),
            ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Add Task', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _title,
                    decoration: const InputDecoration(labelText: 'Title'),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _priority,
                          decoration: const InputDecoration(labelText: 'Priority'),
                          items: const [
                            DropdownMenuItem(value: 'Low', child: Text('Low')),
                            DropdownMenuItem(value: 'Normal', child: Text('Normal')),
                            DropdownMenuItem(value: 'High', child: Text('High')),
                          ],
                          onChanged: (v) => setState(() => _priority = v ?? 'Normal'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pickTime,
                          icon: const Icon(Icons.access_time),
                          label: Text(_time == null ? 'Pick time' : _time!.format(context)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _addTask,
                      icon: const Icon(Icons.save),
                      label: const Text('Save Task'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (user == null)
            const Expanded(child: Center(child: Text('Please login to see tasks')))
          else
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>> (
                stream: FirestoreService.instance.streamTasks(user.uid),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final docs = snapshot.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return const Center(child: Text('No tasks yet'));
                  }
                  return ListView.separated(
                    itemBuilder: (context, i) {
                      final doc = docs[i];
                      _autoMarkMissed(doc); // fire-and-forget
                      final data = doc.data();
                      final title = data['title'] as String? ?? '';
                      final priority = data['priority'] as String? ?? 'Normal';
                      final status = data['status'] as String? ?? 'pending';
                      final Timestamp? dueTs = data['dueAt'] as Timestamp?;
                      final dueStr = dueTs != null ? TimeOfDay.fromDateTime(dueTs.toDate()).format(context) : null;
                      Color? statusColor;
                      IconData statusIcon = Icons.radio_button_unchecked;
                      switch (status) {
                        case 'completed':
                          statusColor = Colors.green;
                          statusIcon = Icons.check_circle;
                          break;
                        case 'missed':
                          statusColor = Colors.redAccent;
                          statusIcon = Icons.error_outline;
                          break;
                        default:
                          statusColor = null;
                      }
                      return Dismissible(
                        key: ValueKey(doc.id),
                        background: Container(color: Colors.redAccent),
                        onDismissed: (_) => _deleteTask(doc.id),
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(title, style: Theme.of(context).textTheme.titleMedium),
                                      const SizedBox(height: 4),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 4,
                                        children: [
                                          Chip(label: Text('Priority: $priority')),
                                          if (dueStr != null) Chip(label: Text('Time: $dueStr')),
                                          Chip(
                                            label: Text('Status: $status'),
                                            backgroundColor: status == 'completed'
                                                ? Colors.green.withOpacity(0.15)
                                                : status == 'missed'
                                                    ? Colors.redAccent.withOpacity(0.15)
                                                    : null,
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(statusIcon, color: statusColor),
                                  onPressed: () => _setStatus(doc.id, status == 'completed' ? 'pending' : 'completed'),
                                ),
                                IconButton(
                                  tooltip: 'Edit',
                                  icon: const Icon(Icons.edit_outlined),
                                  onPressed: () => _editTask(doc.id, data),
                                ),
                                IconButton(
                                  tooltip: 'Delete',
                                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                  onPressed: () async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: const Text('Delete Task?'),
                                        content: Text('Are you sure you want to delete "$title"?'),
                                        actions: [
                                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                          FilledButton(
                                            onPressed: () => Navigator.pop(ctx, true),
                                            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
                                            child: const Text('Delete'),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirm == true) {
                                      await _deleteTask(doc.id);
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemCount: docs.length,
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
