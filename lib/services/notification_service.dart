import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Service class for handling Firebase Cloud Messaging (FCM) and push notifications.
///
/// This service manages device FCM tokens, registers/unregisters tokens for users,
/// and sends push notifications through Firebase Cloud Functions or direct FCM.
class NotificationService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Initializes the notification service and requests permissions.
  ///
  /// Should be called when the app starts or when user signs in.
  /// Requests notification permissions and sets up FCM token refresh listener.
  ///
  /// Returns the current FCM token if available, null otherwise.
  ///
  /// Example:
  /// ```dart
  /// final notificationService = NotificationService();
  /// await notificationService.initialize();
  /// ```
  Future<String?> initialize() async {
    try {
      // Request permission for notifications (iOS)
      final NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        debugPrint('User granted notification permission');
      } else if (settings.authorizationStatus ==
          AuthorizationStatus.provisional) {
        debugPrint('User granted provisional notification permission');
      } else {
        debugPrint('User declined or has not accepted notification permission');
        return null;
      }

      // Get the FCM token
      final String? token = await _messaging.getToken();

      if (token != null) {
        debugPrint('FCM Token: $token');

        // Register token for current user if signed in
        final User? currentUser = _auth.currentUser;
        if (currentUser != null) {
          await registerDeviceToken(currentUser.uid, token);
        }
      }

      // Listen for token refresh
      _messaging.onTokenRefresh.listen((newToken) {
        debugPrint('FCM Token refreshed: $newToken');
        final User? currentUser = _auth.currentUser;
        if (currentUser != null) {
          registerDeviceToken(currentUser.uid, newToken);
        }
      });

      return token;
    } catch (e) {
      debugPrint('Error initializing notification service: $e');
      return null;
    }
  }

  /// Registers a device FCM token for a specific user.
  ///
  /// Stores the token in the user's document under the `fcmTokens` array field.
  /// If the token already exists, it won't be duplicated.
  ///
  /// Parameters:
  /// - [userId]: The user's unique identifier
  /// - [token]: The FCM device token to register
  ///
  /// Throws:
  /// - [FirebaseException] for Firestore errors
  ///
  /// Example:
  /// ```dart
  /// await notificationService.registerDeviceToken(
  ///   'user123',
  ///   'fcm_token_abc...',
  /// );
  /// ```
  Future<void> registerDeviceToken(String userId, String token) async {
    try {
      if (userId.isEmpty || token.isEmpty) {
        throw Exception('User ID and token cannot be empty');
      }

      final DocumentReference userDoc = _firestore
          .collection('users')
          .doc(userId);

      // Use arrayUnion to add token only if it doesn't exist
      await userDoc.update({
        'fcmTokens': FieldValue.arrayUnion([token]),
        'lastTokenUpdate': FieldValue.serverTimestamp(),
      });

      debugPrint('Device token registered for user: $userId');
    } on FirebaseException catch (e) {
      if (e.code == 'not-found') {
        // Document doesn't exist, create it with the token
        await _firestore.collection('users').doc(userId).set({
          'fcmTokens': [token],
          'lastTokenUpdate': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        debugPrint('User document created with token for: $userId');
      } else {
        throw Exception('Error registering device token: ${e.message}');
      }
    } catch (e) {
      throw Exception('Unexpected error registering device token: $e');
    }
  }

  /// Unregisters a device FCM token for a specific user.
  ///
  /// Removes the token from the user's `fcmTokens` array field.
  /// Typically called when user signs out or app is uninstalled.
  ///
  /// Parameters:
  /// - [userId]: The user's unique identifier
  /// - [token]: The FCM device token to unregister
  ///
  /// Example:
  /// ```dart
  /// final token = await FirebaseMessaging.instance.getToken();
  /// await notificationService.unregisterDeviceToken('user123', token!);
  /// ```
  Future<void> unregisterDeviceToken(String userId, String token) async {
    try {
      if (userId.isEmpty || token.isEmpty) {
        throw Exception('User ID and token cannot be empty');
      }

      await _firestore.collection('users').doc(userId).update({
        'fcmTokens': FieldValue.arrayRemove([token]),
        'lastTokenUpdate': FieldValue.serverTimestamp(),
      });

      debugPrint('Device token unregistered for user: $userId');
    } on FirebaseException catch (e) {
      throw Exception('Error unregistering device token: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error unregistering device token: $e');
    }
  }

  /// Unregisters the current device's token when user signs out.
  ///
  /// Convenience method that gets the current token and removes it
  /// from the user's fcmTokens array.
  ///
  /// Should be called during the sign-out process.
  ///
  /// Example:
  /// ```dart
  /// await notificationService.unregisterCurrentDevice();
  /// await FirebaseAuth.instance.signOut();
  /// ```
  Future<void> unregisterCurrentDevice() async {
    try {
      final User? currentUser = _auth.currentUser;
      if (currentUser == null) {
        debugPrint('No user signed in, skipping token unregistration');
        return;
      }

      final String? token = await _messaging.getToken();
      if (token != null) {
        await unregisterDeviceToken(currentUser.uid, token);
      }
    } catch (e) {
      debugPrint('Error unregistering current device: $e');
      // Don't throw, as this is called during sign-out
    }
  }

  /// Sends a push notification to a specific user via Cloud Function.
  ///
  /// This method calls a Firebase Cloud Function that handles sending
  /// the notification to all registered devices for the user.
  ///
  /// Parameters:
  /// - [userId]: The target user's unique identifier
  /// - [title]: Notification title
  /// - [body]: Notification body/message
  /// - [data]: Optional custom data payload to send with the notification
  ///
  /// Returns true if notification was sent successfully, false otherwise.
  ///
  /// Throws:
  /// - [FirebaseException] for Cloud Functions or Firestore errors
  ///
  /// Example:
  /// ```dart
  /// await notificationService.sendPushNotification(
  ///   'user123',
  ///   'Book Overdue',
  ///   'Your book is 3 days overdue. Please return it.',
  ///   {'type': 'overdue', 'loanId': 'loan456'},
  /// );
  /// ```
  Future<bool> sendPushNotification(
    String userId,
    String title,
    String body,
    Map<String, dynamic>? data,
  ) async {
    try {
      if (userId.isEmpty) {
        throw Exception('User ID cannot be empty');
      }

      if (title.isEmpty || body.isEmpty) {
        throw Exception('Title and body cannot be empty');
      }

      // Get user's FCM tokens from Firestore
      final DocumentSnapshot userDoc = await _firestore
          .collection('users')
          .doc(userId)
          .get();

      if (!userDoc.exists) {
        throw Exception('User not found');
      }

      final userData = userDoc.data() as Map<String, dynamic>?;
      final List<dynamic>? fcmTokens = userData?['fcmTokens'] as List<dynamic>?;

      if (fcmTokens == null || fcmTokens.isEmpty) {
        debugPrint('No FCM tokens found for user: $userId');
        return false;
      }

      // Create notification document in Firestore
      // This can be picked up by Cloud Functions or used for notification history
      await _firestore.collection('notifications').add({
        'userId': userId,
        'title': title,
        'body': body,
        'data': data ?? {},
        'tokens': fcmTokens,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      debugPrint('Notification queued for user: $userId');

      // Note: Actual sending is handled by Cloud Functions watching the 'notifications' collection
      // Alternatively, you can call a Cloud Function directly:
      // final callable = FirebaseFunctions.instance.httpsCallable('sendNotification');
      // final result = await callable.call({
      //   'userId': userId,
      //   'title': title,
      //   'body': body,
      //   'data': data,
      // });

      return true;
    } on FirebaseException catch (e) {
      throw Exception('Error sending push notification: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error sending notification: $e');
    }
  }

  /// Sends push notifications to multiple users in batch.
  ///
  /// Efficiently sends the same notification to multiple users.
  ///
  /// Parameters:
  /// - [userIds]: List of user IDs to send notification to
  /// - [title]: Notification title
  /// - [body]: Notification body/message
  /// - [data]: Optional custom data payload
  ///
  /// Returns the number of users who were sent notifications successfully.
  ///
  /// Example:
  /// ```dart
  /// final sentCount = await notificationService.sendBatchNotifications(
  ///   ['user1', 'user2', 'user3'],
  ///   'Library Closing',
  ///   'The library will be closed tomorrow.',
  ///   {'type': 'announcement'},
  /// );
  /// print('Sent to $sentCount users');
  /// ```
  Future<int> sendBatchNotifications(
    List<String> userIds,
    String title,
    String body,
    Map<String, dynamic>? data,
  ) async {
    int successCount = 0;

    for (final userId in userIds) {
      try {
        final success = await sendPushNotification(userId, title, body, data);
        if (success) successCount++;
      } catch (e) {
        debugPrint('Failed to send notification to user $userId: $e');
        // Continue with next user
      }
    }

    return successCount;
  }

  /// Gets the current FCM token for this device.
  ///
  /// Returns the token string if available, null otherwise.
  ///
  /// Example:
  /// ```dart
  /// final token = await notificationService.getCurrentToken();
  /// print('My FCM token: $token');
  /// ```
  Future<String?> getCurrentToken() async {
    try {
      return await _messaging.getToken();
    } catch (e) {
      debugPrint('Error getting current token: $e');
      return null;
    }
  }

  /// Deletes the current FCM token.
  ///
  /// This will cause FCM to generate a new token on next app launch.
  /// Useful for testing or when migrating to a new FCM project.
  ///
  /// Example:
  /// ```dart
  /// await notificationService.deleteToken();
  /// ```
  Future<void> deleteToken() async {
    try {
      await _messaging.deleteToken();
      debugPrint('FCM token deleted');
    } catch (e) {
      debugPrint('Error deleting token: $e');
    }
  }

  /// Sets up foreground message handler.
  ///
  /// Configures how the app handles notifications when it's in the foreground.
  /// Should be called during app initialization.
  ///
  /// Parameters:
  /// - [onMessage]: Callback function to handle incoming messages
  ///
  /// Example:
  /// ```dart
  /// notificationService.setupForegroundHandler((message) {
  ///   print('Received: ${message.notification?.title}');
  ///   // Show in-app notification or update UI
  /// });
  /// ```
  void setupForegroundHandler(Function(RemoteMessage) onMessage) {
    FirebaseMessaging.onMessage.listen(onMessage);
  }

  /// Sets up background message handler.
  ///
  /// Configures how the app handles notifications when it's in the background.
  /// Must be a top-level function (not a class method).
  ///
  /// Example:
  /// ```dart
  /// // In main.dart, before runApp()
  /// FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  ///
  /// @pragma('vm:entry-point')
  /// Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  ///   await Firebase.initializeApp();
  ///   print('Handling background message: ${message.messageId}');
  /// }
  /// ```
  static void setupBackgroundHandler(
    Future<void> Function(RemoteMessage) handler,
  ) {
    FirebaseMessaging.onBackgroundMessage(handler);
  }

  /// Sets up notification tap handler.
  ///
  /// Configures what happens when user taps on a notification.
  ///
  /// Parameters:
  /// - [onTap]: Callback function to handle notification taps
  ///
  /// Example:
  /// ```dart
  /// notificationService.setupNotificationTapHandler((message) {
  ///   final loanId = message.data['loanId'];
  ///   // Navigate to loan detail screen
  ///   Navigator.pushNamed(context, '/loan-detail', arguments: loanId);
  /// });
  /// ```
  void setupNotificationTapHandler(Function(RemoteMessage) onTap) {
    FirebaseMessaging.onMessageOpenedApp.listen(onTap);
  }

  /// Checks and handles initial notification if app was opened from notification.
  ///
  /// Should be called during app initialization to handle cold start from notification.
  ///
  /// Returns the RemoteMessage if app was opened from notification, null otherwise.
  ///
  /// Example:
  /// ```dart
  /// final initialMessage = await notificationService.getInitialMessage();
  /// if (initialMessage != null) {
  ///   // Handle the notification that opened the app
  ///   final loanId = initialMessage.data['loanId'];
  ///   // Navigate to specific screen
  /// }
  /// ```
  Future<RemoteMessage?> getInitialMessage() async {
    try {
      return await _messaging.getInitialMessage();
    } catch (e) {
      debugPrint('Error getting initial message: $e');
      return null;
    }
  }
}
