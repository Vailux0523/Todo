import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../core/services/firestore_service.dart';

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _addNote() async {
    final title = _titleController.text.trim();
    final text = _contentController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please add a title')));
      return;
    }
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please write a note')));
      return;
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await FirestoreService.instance.addNote(user.uid, title: title, content: text);
    _titleController.clear();
    _contentController.clear();
  }

  Future<void> _editNote(String noteId, String currentTitle, String currentContent) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final titleCtrl = TextEditingController(text: currentTitle);
    final contentCtrl = TextEditingController(text: currentContent);
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Note'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: contentCtrl,
              maxLines: 5,
              decoration: const InputDecoration(labelText: 'Content', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, {
              'title': titleCtrl.text.trim(),
              'content': contentCtrl.text.trim(),
            }),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result != null) {
      final newTitle = result['title'] ?? currentTitle;
      final newContent = result['content'] ?? currentContent;
      await FirestoreService.instance.updateNote(user.uid, noteId, title: newTitle, content: newContent);
    }
  }

  Future<void> _delete(String noteId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await FirestoreService.instance.deleteNote(user.uid, noteId);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Add Note', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'Title',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _contentController,
                    decoration: const InputDecoration(
                      labelText: 'Write a note...',
                    ),
                    maxLines: 4,
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _addNote,
                      icon: const Icon(Icons.save),
                      label: const Text('Save Note'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Builder(
              builder: (context) {
                final user = FirebaseAuth.instance.currentUser;
                if (user == null) return const Center(child: Text('Please login to see notes'));
                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirestoreService.instance.streamNotes(user.uid),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final docs = snapshot.data?.docs ?? [];
                    if (docs.isEmpty) return const Center(child: Text('No notes yet'));
                    return ListView.builder(
                      itemCount: docs.length,
                      itemBuilder: (context, i) {
                        final doc = docs[i];
                        final data = doc.data();
                        final title = data['title'] as String? ?? '';
                        final content = data['content'] as String? ?? '';
                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (title.isNotEmpty)
                                        Text(title, style: Theme.of(context).textTheme.titleMedium),
                                      if (title.isNotEmpty) const SizedBox(height: 6),
                                      Text(
                                        content,
                                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 17),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Column(
                                  children: [
                                    IconButton(
                                      tooltip: 'Edit',
                                      icon: const Icon(Icons.edit_outlined),
                                      onPressed: () => _editNote(doc.id, title, content),
                                    ),
                                    IconButton(
                                      tooltip: 'Delete',
                                      icon: const Icon(Icons.delete_outline),
                                      onPressed: () => _delete(doc.id),
                                    ),
                                  ],
                                )
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          )
        ],
      ),
    );
  }
}
