import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import 'notification_service.dart';

/// Service class for handling user authentication with Firebase Auth.
///
/// This service provides methods for user registration, login, logout,
/// and retrieving user profile information from Firestore.
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationService _notificationService = NotificationService();

  /// Signs up a new user with email and password.
  ///
  /// Creates a Firebase Auth account and stores additional user information
  /// in the Firestore 'users' collection.
  ///
  /// Parameters:
  /// - [email]: User's email address
  /// - [password]: User's password (minimum 6 characters)
  /// - [fullName]: User's full name
  /// - [role]: User's role in the system ("member" or "librarian")
  ///
  /// Returns a [UserCredential] containing the created user information.
  ///
  /// Throws:
  /// - [FirebaseAuthException] for authentication errors
  /// - [FirebaseException] for Firestore errors
  ///
  /// Example:
  /// ```dart
  /// try {
  ///   final credential = await authService.signUp(
  ///     'user@example.com',
  ///     'password123',
  ///     'John Doe',
  ///     'member',
  ///   );
  ///   print('User created: ${credential.user?.uid}');
  /// } catch (e) {
  ///   print('Error: $e');
  /// }
  /// ```
  Future<UserCredential> signUp(
    String email,
    String password,
    String fullName,
    String role, {
    String? phone,
    String? address,
  }) async {
    try {
      // Create user account with Firebase Auth
      final UserCredential credential = await _auth
          .createUserWithEmailAndPassword(email: email, password: password);

      // Generate a unique card number for the user
      final String cardNumber = _generateCardNumber(credential.user!.uid);

      // Create user profile in Firestore
      final AppUser newUser = AppUser(
        uid: credential.user!.uid,
        fullName: fullName,
        email: email,
        role: role,
        cardNumber: cardNumber,
        maxBorrow: role == 'librarian' ? 10 : 3, // Librarians can borrow more
        borrowedCount: 0,
        phone: phone ?? '',
        address: address ?? '',
        createdAt: Timestamp.now(),
      );

      // Save user profile to Firestore
      await _firestore
          .collection('users')
          .doc(credential.user!.uid)
          .set(newUser.toJson());

      return credential;
    } on FirebaseAuthException catch (e) {
      // Handle specific Firebase Auth errors
      switch (e.code) {
        case 'weak-password':
          throw Exception('The password provided is too weak.');
        case 'email-already-in-use':
          throw Exception('An account already exists for this email.');
        case 'invalid-email':
          throw Exception('The email address is not valid.');
        default:
          throw Exception('Authentication error: ${e.message}');
      }
    } on FirebaseException catch (e) {
      throw Exception('Database error: ${e.message}');
    } catch (e) {
      throw Exception('An unexpected error occurred: $e');
    }
  }

  /// Signs in an existing user with email and password.
  ///
  /// Parameters:
  /// - [email]: User's email address
  /// - [password]: User's password
  ///
  /// Returns a [UserCredential] containing the signed-in user information.
  ///
  /// Throws:
  /// - [FirebaseAuthException] for authentication errors
  ///
  /// Example:
  /// ```dart
  /// try {
  ///   final credential = await authService.signIn(
  ///     'user@example.com',
  ///     'password123',
  ///   );
  ///   print('User signed in: ${credential.user?.email}');
  /// } catch (e) {
  ///   print('Error: $e');
  /// }
  /// ```
  Future<UserCredential> signIn(String email, String password) async {
    try {
      final UserCredential credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Register FCM token after successful sign-in
      try {
        await _notificationService.initialize();
      } catch (e) {
        // Don't throw if FCM token registration fails
        // User can still use the app without notifications
        print('Warning: Failed to register FCM token: $e');
      }

      return credential;
    } on FirebaseAuthException catch (e) {
      // Handle specific Firebase Auth errors
      switch (e.code) {
        case 'user-not-found':
          throw Exception('No user found with this email.');
        case 'wrong-password':
          throw Exception('Incorrect password.');
        case 'invalid-email':
          throw Exception('The email address is not valid.');
        case 'user-disabled':
          throw Exception('This user account has been disabled.');
        case 'invalid-credential':
          throw Exception('Invalid email or password.');
        default:
          throw Exception('Authentication error: ${e.message}');
      }
    } catch (e) {
      throw Exception('An unexpected error occurred: $e');
    }
  }

  /// Signs out the currently authenticated user.
  ///
  /// Also unregisters the device's FCM token to stop receiving notifications.
  ///
  /// Throws:
  /// - [FirebaseAuthException] if sign out fails
  ///
  /// Example:
  /// ```dart
  /// try {
  ///   await authService.signOut();
  ///   print('User signed out successfully');
  /// } catch (e) {
  ///   print('Error: $e');
  /// }
  /// ```
  Future<void> signOut() async {
    try {
      // Unregister FCM token before signing out
      try {
        await _notificationService.unregisterCurrentDevice();
      } catch (e) {
        // Don't throw if token unregistration fails
        print('Warning: Failed to unregister FCM token: $e');
      }

      await _auth.signOut();
    } on FirebaseAuthException catch (e) {
      throw Exception('Sign out error: ${e.message}');
    } catch (e) {
      throw Exception('An unexpected error occurred: $e');
    }
  }

  /// Retrieves the current user's profile from Firestore.
  ///
  /// Fetches the user document from the 'users' collection using the
  /// current authenticated user's UID and returns an [AppUser] object.
  ///
  /// Returns [AppUser] if user is authenticated and profile exists,
  /// otherwise returns null.
  ///
  /// Throws:
  /// - [FirebaseException] for Firestore errors
  ///
  /// Example:
  /// ```dart
  /// try {
  ///   final user = await authService.getCurrentUserProfile();
  ///   if (user != null) {
  ///     print('Welcome, ${user.fullName}');
  ///   } else {
  ///     print('No user is signed in');
  ///   }
  /// } catch (e) {
  ///   print('Error: $e');
  /// }
  /// ```
  Future<AppUser?> getCurrentUserProfile() async {
    try {
      // Check if user is authenticated
      final User? currentUser = _auth.currentUser;

      if (currentUser == null) {
        return null;
      }

      // Fetch user profile from Firestore
      final DocumentSnapshot doc = await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .get();

      // Check if document exists
      if (!doc.exists) {
        return null;
      }

      // Convert document to AppUser object
      return AppUser.fromDoc(doc);
    } on FirebaseException catch (e) {
      throw Exception('Database error: ${e.message}');
    } catch (e) {
      throw Exception('An unexpected error occurred: $e');
    }
  }

  /// Gets the currently authenticated Firebase user.
  ///
  /// Returns the [User] object if authenticated, otherwise null.
  User? get currentUser => _auth.currentUser;

  /// Returns a stream of authentication state changes.
  ///
  /// Useful for listening to login/logout events in the app.
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Generates a unique library card number based on user UID.
  ///
  /// Creates a card number in format: LIB-XXXXXXXX
  /// where X is derived from the user's UID.
  String _generateCardNumber(String uid) {
    // Take first 8 characters of UID and convert to uppercase
    final String shortId = uid.substring(0, 8).toUpperCase();
    return 'LIB-$shortId';
  }

  /// Sends a password reset email to the specified email address.
  ///
  /// Parameters:
  /// - [email]: Email address to send the reset link to
  ///
  /// Throws:
  /// - [FirebaseAuthException] for authentication errors
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'user-not-found':
          throw Exception('No user found with this email.');
        case 'invalid-email':
          throw Exception('The email address is not valid.');
        default:
          throw Exception('Error sending password reset: ${e.message}');
      }
    } catch (e) {
      throw Exception('An unexpected error occurred: $e');
    }
  }

  /// Updates the current user's password.
  ///
  /// Parameters:
  /// - [newPassword]: The new password (minimum 6 characters)
  ///
  /// Throws:
  /// - [FirebaseAuthException] for authentication errors
  Future<void> updatePassword(String newPassword) async {
    try {
      final User? user = _auth.currentUser;
      if (user == null) {
        throw Exception('No user is currently signed in.');
      }
      await user.updatePassword(newPassword);
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'weak-password':
          throw Exception('The password provided is too weak.');
        case 'requires-recent-login':
          throw Exception('Please sign in again to change your password.');
        default:
          throw Exception('Error updating password: ${e.message}');
      }
    } catch (e) {
      throw Exception('An unexpected error occurred: $e');
    }
  }
}
