import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<UserCredential?> signInWithGoogle({
    bool forceAccountSelection = false,
  }) async {
    final googleSignIn = GoogleSignIn();
    if (forceAccountSelection) {
      // Force the account chooser by signing out any currently signed-in Google account first
      try {
        await googleSignIn.signOut();
      } catch (_) {}
    }

    final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
    if (googleUser == null) return null; // user cancelled

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final userCredential = await _auth.signInWithCredential(credential);

    // Ensure Firestore user document exists
    final user = userCredential.user;
    if (user == null) return userCredential;

    final userRef = _db.collection('users').doc(user.uid);
    final userSnap = await userRef.get();
    if (!userSnap.exists) {
      await userRef.set({
        'fullName': user.displayName ?? user.email?.split('@')[0] ?? 'User',
        'email': user.email ?? '',
        'phone': user.phoneNumber ?? '',
        'address': '',
        'role': 'member',
        'borrowedCount': 0,
        'maxBorrow': 3,
        'fcmTokens': [],
        'cardNumber': 'LIB-${user.uid.substring(0, 8).toUpperCase()}',
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    return userCredential;
  }

  Future<void> signOut() async {
    await GoogleSignIn().signOut();
    await _auth.signOut();
  }
}
