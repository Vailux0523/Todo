import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  FirestoreService._();
  static final instance = FirestoreService._();

  final _db = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> userDoc(String uid) => _db.collection('users').doc(uid);
  CollectionReference<Map<String, dynamic>> tasksCol(String uid) => userDoc(uid).collection('tasks');
  CollectionReference<Map<String, dynamic>> notesCol(String uid) => userDoc(uid).collection('notes');

  Future<void> ensureUser(String uid, {required String email, String? displayName}) async {
    final ref = userDoc(uid);
    final snap = await ref.get();
    if (!snap.exists) {
      await ref.set({
        'email': email,
        'displayName': displayName ?? '',
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> updateDisplayName(String uid, String name) async {
    await userDoc(uid).set({'displayName': name}, SetOptions(merge: true));
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> streamTasks(String uid) {
    return tasksCol(uid).orderBy('dueAt', descending: false).snapshots();
  }

  Future<void> addTask(String uid, {
    required String title,
    required String priority, // Low, Normal, High
    DateTime? dueAt,
  }) async {
    await tasksCol(uid).add({
      'title': title,
      'priority': priority,
      'dueAt': dueAt != null ? Timestamp.fromDate(dueAt) : null,
      'status': 'pending', // pending, completed, missed
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> setTaskStatus(String uid, String taskId, String status) async {
    await tasksCol(uid).doc(taskId).set({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> updateTask(
    String uid,
    String taskId, {
    String? title,
    String? priority,
    DateTime? dueAt,
  }) async {
    final data = <String, dynamic>{
      if (title != null) 'title': title,
      if (priority != null) 'priority': priority,
      'dueAt': dueAt != null ? Timestamp.fromDate(dueAt) : null,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    await tasksCol(uid).doc(taskId).set(data, SetOptions(merge: true));
  }

  Future<void> deleteTask(String uid, String taskId) async {
    await tasksCol(uid).doc(taskId).delete();
  }

  // Notes helpers
  Stream<QuerySnapshot<Map<String, dynamic>>> streamNotes(String uid) {
    return notesCol(uid).orderBy('updatedAt', descending: true).snapshots();
  }

  Future<void> addNote(String uid, {required String title, required String content}) async {
    await notesCol(uid).add({
      'title': title,
      'content': content,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateNote(String uid, String noteId, {String? title, String? content}) async {
    final data = <String, dynamic>{
      if (title != null) 'title': title,
      if (content != null) 'content': content,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    await notesCol(uid).doc(noteId).set(data, SetOptions(merge: true));
  }

  Future<void> deleteNote(String uid, String noteId) async {
    await notesCol(uid).doc(noteId).delete();
  }
}
