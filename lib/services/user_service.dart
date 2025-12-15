import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

/// Service for managing user data.
class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Gets a user by ID.
  Future<AppUser?> getUserById(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (!doc.exists) return null;
      return AppUser.fromDoc(doc);
    } catch (e) {
      throw Exception('Error loading user: $e');
    }
  }

  /// Gets all members (users with isMember = true).
  Future<List<AppUser>> getAllMembers() async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .where('isMember', isEqualTo: true)
          .orderBy('fullName')
          .get();

      return snapshot.docs.map((doc) => AppUser.fromDoc(doc)).toList();
    } catch (e) {
      throw Exception('Error loading members: $e');
    }
  }

  /// Gets all members as a stream.
  Stream<List<AppUser>> getAllMembersStream() {
    return _firestore
        .collection('users')
        .where('isMember', isEqualTo: true)
        .orderBy('fullName')
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => AppUser.fromDoc(doc)).toList(),
        );
  }

  /// Updates user's borrowed count.
  Future<void> updateBorrowedCount(String userId, int increment) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'borrowedCount': FieldValue.increment(increment),
      });
    } catch (e) {
      throw Exception('Error updating borrowed count: $e');
    }
  }

  /// Updates user profile.
  Future<void> updateUserProfile({
    required String userId,
    required Map<String, dynamic> data,
  }) async {
    try {
      await _firestore.collection('users').doc(userId).update(data);
    } catch (e) {
      throw Exception('Error updating user profile: $e');
    }
  }
}
