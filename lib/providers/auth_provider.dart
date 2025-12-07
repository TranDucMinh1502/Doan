import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';

/// Provider for managing authentication state.
///
/// Uses [ChangeNotifier] to notify listeners when authentication state changes.
/// Integrates [AuthService] for Firebase Auth operations and [FirestoreService]
/// for user profile management.
class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();

  /// The currently authenticated user's profile.
  ///
  /// This is null if no user is authenticated or if the profile hasn't been loaded yet.
  AppUser? _currentUser;

  /// Indicates whether an authentication operation is in progress.
  ///
  /// Used to show loading indicators in the UI during login, logout, etc.
  bool _isLoading = false;

  /// Gets the current user profile.
  AppUser? get currentUser => _currentUser;

  /// Gets the loading state.
  bool get isLoading => _isLoading;

  /// Checks if a user is currently authenticated.
  bool get isAuthenticated => _currentUser != null;

  /// Checks if the current user is a librarian.
  bool get isLibrarian => _currentUser?.isLibrarian ?? false;

  /// Checks if the current user is a member.
  bool get isMember => _currentUser?.isMember ?? false;

  /// Logs in a user with email and password.
  ///
  /// Sets [isLoading] to true during the operation and automatically
  /// loads the user profile after successful authentication.
  ///
  /// Parameters:
  /// - [email]: User's email address
  /// - [password]: User's password
  ///
  /// Throws [Exception] with a readable error message if login fails.
  ///
  /// Example:
  /// ```dart
  /// try {
  ///   await authProvider.login('user@example.com', 'password123');
  ///   // Navigate to home screen
  /// } catch (e) {
  ///   // Show error message
  /// }
  /// ```
  Future<void> login(String email, String password) async {
    try {
      _isLoading = true;
      notifyListeners();

      // Sign in with Firebase Auth
      await _authService.signIn(email, password);

      // Load user profile from Firestore
      await loadProfile();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _currentUser = null;
      notifyListeners();
      rethrow; // Re-throw to let the UI handle the error
    }
  }

  /// Registers a new user with email, password, and full name.
  ///
  /// Creates a new Firebase Auth account and user profile in Firestore.
  /// Sets [isLoading] to true during the operation and automatically
  /// loads the user profile after successful registration.
  ///
  /// Parameters:
  /// - [email]: User's email address
  /// - [password]: User's password (minimum 6 characters)
  /// - [fullName]: User's full name
  ///
  /// Throws [Exception] with a readable error message if registration fails.
  ///
  /// Example:
  /// ```dart
  /// try {
  ///   await authProvider.register(
  ///     'newuser@example.com',
  ///     'password123',
  ///     'John Doe',
  ///   );
  ///   // Navigate to home screen
  /// } catch (e) {
  ///   // Show error message
  /// }
  /// ```
  Future<void> register(String email, String password, String fullName) async {
    try {
      _isLoading = true;
      notifyListeners();

      // Register with Firebase Auth (default role is 'member')
      await _authService.signUp(email, password, fullName, 'member');

      // Load user profile from Firestore
      await loadProfile();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _currentUser = null;
      notifyListeners();
      rethrow; // Re-throw to let the UI handle the error
    }
  }

  /// Logs out the current user.
  ///
  /// Signs out from Firebase Auth, clears the current user profile,
  /// and unregisters the device's FCM token.
  ///
  /// Sets [isLoading] to true during the operation.
  ///
  /// Throws [Exception] with a readable error message if logout fails.
  ///
  /// Example:
  /// ```dart
  /// try {
  ///   await authProvider.logout();
  ///   // Navigate to login screen
  /// } catch (e) {
  ///   // Show error message
  /// }
  /// ```
  Future<void> logout() async {
    try {
      _isLoading = true;
      notifyListeners();

      // Sign out from Firebase
      await _authService.signOut();

      // Clear current user
      _currentUser = null;

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow; // Re-throw to let the UI handle the error
    }
  }

  /// Loads the current user's profile from Firestore.
  ///
  /// Fetches the authenticated user's profile data using [FirestoreService].
  /// This should be called after login, registration, or when the app starts
  /// to restore the user session.
  ///
  /// Sets [currentUser] to null if no user is authenticated or profile is not found.
  ///
  /// Throws [Exception] with a readable error message if profile loading fails.
  ///
  /// Example:
  /// ```dart
  /// try {
  ///   await authProvider.loadProfile();
  ///   if (authProvider.currentUser != null) {
  ///     print('Profile loaded for ${authProvider.currentUser!.fullName}');
  ///   }
  /// } catch (e) {
  ///   // Handle error
  /// }
  /// ```
  Future<void> loadProfile() async {
    try {
      // Get current Firebase Auth user
      final firebaseUser = _authService.currentUser;

      if (firebaseUser == null) {
        _currentUser = null;
        notifyListeners();
        return;
      }

      // Load user profile from Firestore
      final userProfile = await _firestoreService.getUser(firebaseUser.uid);

      _currentUser = userProfile;
      notifyListeners();
    } catch (e) {
      _currentUser = null;
      notifyListeners();
      throw Exception('Failed to load user profile: $e');
    }
  }

  /// Updates the current user profile in memory and optionally in Firestore.
  ///
  /// This is useful for updating the UI after profile changes without
  /// reloading from the database.
  ///
  /// Parameters:
  /// - [user]: Updated user profile
  /// - [persistToDb]: If true, saves changes to Firestore (default: false)
  ///
  /// Example:
  /// ```dart
  /// final updatedUser = authProvider.currentUser!.copyWith(
  ///   fullName: 'New Name',
  /// );
  /// await authProvider.updateUser(updatedUser, persistToDb: true);
  /// ```
  Future<void> updateUser(AppUser user, {bool persistToDb = false}) async {
    try {
      if (persistToDb) {
        _isLoading = true;
        notifyListeners();

        await _firestoreService.updateUser(user);

        _isLoading = false;
      }

      _currentUser = user;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      throw Exception('Failed to update user profile: $e');
    }
  }

  /// Refreshes the current user profile from Firestore.
  ///
  /// Useful for ensuring the profile is up-to-date after potential
  /// external changes (e.g., borrowing a book, admin updates).
  ///
  /// Example:
  /// ```dart
  /// await authProvider.refreshProfile();
  /// ```
  Future<void> refreshProfile() async {
    if (_currentUser == null) return;

    try {
      _isLoading = true;
      notifyListeners();

      await loadProfile();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      throw Exception('Failed to refresh user profile: $e');
    }
  }
}
