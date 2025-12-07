import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

/// Service class for calling Firebase Cloud Functions
///
/// This service provides convenient methods to call backend Cloud Functions
/// for tasks like checking overdue loans and sending notifications.
class CloudFunctionsService {
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  /// Manually trigger the overdue loan checker
  ///
  /// This function allows librarians to manually check for overdue loans
  /// without waiting for the scheduled daily run.
  ///
  /// Requires: User must be authenticated with librarian role
  ///
  /// Returns:
  /// - success: Whether the operation completed successfully
  /// - message: Human-readable result message
  /// - processedCount: Number of overdue loans processed
  /// - errorCount: Number of loans that failed to process
  /// - totalLoans: Total number of overdue loans found
  ///
  /// Throws:
  /// - Exception if user is not authenticated
  /// - Exception if user is not a librarian
  /// - Exception if Cloud Function call fails
  ///
  /// Example:
  /// ```dart
  /// try {
  ///   final result = await cloudFunctions.triggerOverdueCheck();
  ///   print('Processed ${result['processedCount']} loans');
  ///   print(result['message']);
  /// } catch (e) {
  ///   print('Error: $e');
  /// }
  /// ```
  Future<Map<String, dynamic>> triggerOverdueCheck() async {
    try {
      debugPrint('Triggering manual overdue check...');

      final callable = _functions.httpsCallable('manualOverdueCheck');
      final result = await callable.call();

      final data = result.data as Map<String, dynamic>;
      debugPrint('Overdue check result: ${data['message']}');

      return {
        'success': data['success'] ?? false,
        'message': data['message'] ?? 'Check completed',
        'processedCount': data['processedCount'] ?? 0,
        'errorCount': data['errorCount'] ?? 0,
        'totalLoans': data['totalLoans'] ?? 0,
      };
    } on FirebaseFunctionsException catch (e) {
      debugPrint('Cloud Function error: ${e.code} - ${e.message}');
      throw Exception('Failed to check overdue loans: ${e.message}');
    } catch (e) {
      debugPrint('Unexpected error calling overdue check: $e');
      throw Exception('Failed to check overdue loans: $e');
    }
  }

  /// Send a custom push notification to a specific user
  ///
  /// This function sends a notification through Firebase Cloud Messaging
  /// to all registered devices of the specified user.
  ///
  /// Parameters:
  /// - userId: The target user's unique identifier
  /// - title: Notification title (shown in notification tray)
  /// - body: Notification message content
  /// - data: Optional custom data payload (e.g., for deep linking)
  ///
  /// Returns:
  /// - success: Whether notification was sent successfully
  /// - successCount: Number of devices that received the notification
  /// - failureCount: Number of devices that failed to receive
  ///
  /// Example:
  /// ```dart
  /// await cloudFunctions.sendNotificationToUser(
  ///   userId: 'user123',
  ///   title: 'Book Available',
  ///   body: 'Your reserved book is ready for pickup',
  ///   data: {
  ///     'type': 'reservation_ready',
  ///     'bookId': 'book456',
  ///   },
  /// );
  /// ```
  Future<Map<String, dynamic>> sendNotificationToUser({
    required String userId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      if (userId.isEmpty || title.isEmpty || body.isEmpty) {
        throw Exception('userId, title, and body are required');
      }

      debugPrint('Sending notification to user: $userId');

      final callable = _functions.httpsCallable('sendNotification');
      final result = await callable.call({
        'userId': userId,
        'title': title,
        'body': body,
        'data': data ?? {},
      });

      final response = result.data as Map<String, dynamic>;
      debugPrint(
        'Notification sent: ${response['successCount']} success, '
        '${response['failureCount']} failures',
      );

      return {
        'success': response['success'] ?? false,
        'successCount': response['successCount'] ?? 0,
        'failureCount': response['failureCount'] ?? 0,
      };
    } on FirebaseFunctionsException catch (e) {
      debugPrint('Cloud Function error: ${e.code} - ${e.message}');
      throw Exception('Failed to send notification: ${e.message}');
    } catch (e) {
      debugPrint('Unexpected error sending notification: $e');
      throw Exception('Failed to send notification: $e');
    }
  }

  /// Send a notification to multiple users in batch
  ///
  /// This is a convenience method that sends the same notification
  /// to multiple users by calling sendNotificationToUser for each.
  ///
  /// Parameters:
  /// - userIds: List of user IDs to notify
  /// - title: Notification title
  /// - body: Notification message
  /// - data: Optional custom data payload
  ///
  /// Returns the number of users who were successfully notified.
  ///
  /// Example:
  /// ```dart
  /// final sentCount = await cloudFunctions.sendBatchNotifications(
  ///   userIds: ['user1', 'user2', 'user3'],
  ///   title: 'Library Closure',
  ///   body: 'The library will be closed tomorrow',
  ///   data: {'type': 'announcement'},
  /// );
  /// print('Notified $sentCount users');
  /// ```
  Future<int> sendBatchNotifications({
    required List<String> userIds,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    int successCount = 0;

    for (final userId in userIds) {
      try {
        final result = await sendNotificationToUser(
          userId: userId,
          title: title,
          body: body,
          data: data,
        );

        if (result['success'] == true) {
          successCount++;
        }
      } catch (e) {
        debugPrint('Failed to notify user $userId: $e');
        // Continue with next user
      }
    }

    return successCount;
  }

  /// Send a reminder notification for an upcoming due date
  ///
  /// Convenience method for sending due date reminders.
  ///
  /// Example:
  /// ```dart
  /// await cloudFunctions.sendDueDateReminder(
  ///   userId: 'user123',
  ///   bookTitle: 'The Great Gatsby',
  ///   daysUntilDue: 2,
  ///   loanId: 'loan456',
  /// );
  /// ```
  Future<void> sendDueDateReminder({
    required String userId,
    required String bookTitle,
    required int daysUntilDue,
    required String loanId,
  }) async {
    final body = daysUntilDue == 1
        ? '$bookTitle is due tomorrow. Please return it on time to avoid fines.'
        : '$bookTitle is due in $daysUntilDue days. Please plan to return it on time.';

    await sendNotificationToUser(
      userId: userId,
      title: 'Due Date Reminder',
      body: body,
      data: {
        'type': 'due_date_reminder',
        'loanId': loanId,
        'daysUntilDue': daysUntilDue.toString(),
      },
    );
  }

  /// Send a notification when a reserved book becomes available
  ///
  /// Example:
  /// ```dart
  /// await cloudFunctions.sendReservationReadyNotification(
  ///   userId: 'user123',
  ///   bookTitle: 'Harry Potter',
  ///   reservationId: 'res456',
  /// );
  /// ```
  Future<void> sendReservationReadyNotification({
    required String userId,
    required String bookTitle,
    required String reservationId,
  }) async {
    await sendNotificationToUser(
      userId: userId,
      title: 'Book Available',
      body:
          '$bookTitle is now available for pickup. '
          'Please collect it within 3 days or your reservation will be cancelled.',
      data: {'type': 'reservation_ready', 'reservationId': reservationId},
    );
  }

  /// Send a notification when a book is successfully borrowed
  ///
  /// Example:
  /// ```dart
  /// await cloudFunctions.sendBorrowConfirmation(
  ///   userId: 'user123',
  ///   bookTitle: 'To Kill a Mockingbird',
  ///   dueDate: DateTime.now().add(Duration(days: 14)),
  ///   loanId: 'loan456',
  /// );
  /// ```
  Future<void> sendBorrowConfirmation({
    required String userId,
    required String bookTitle,
    required DateTime dueDate,
    required String loanId,
  }) async {
    final dueDateStr = '${dueDate.day}/${dueDate.month}/${dueDate.year}';

    await sendNotificationToUser(
      userId: userId,
      title: 'Book Borrowed',
      body:
          'You have successfully borrowed $bookTitle. '
          'Please return it by $dueDateStr.',
      data: {
        'type': 'borrow_confirmation',
        'loanId': loanId,
        'dueDate': dueDate.toIso8601String(),
      },
    );
  }

  /// Send a notification when a book is successfully returned
  ///
  /// Example:
  /// ```dart
  /// await cloudFunctions.sendReturnConfirmation(
  ///   userId: 'user123',
  ///   bookTitle: '1984',
  ///   hadFine: true,
  ///   fineAmount: 3.50,
  /// );
  /// ```
  Future<void> sendReturnConfirmation({
    required String userId,
    required String bookTitle,
    bool hadFine = false,
    double fineAmount = 0.0,
  }) async {
    final body = hadFine
        ? '$bookTitle has been returned. Fine paid: \$${fineAmount.toStringAsFixed(2)}. '
              'Thank you!'
        : '$bookTitle has been returned successfully. Thank you!';

    await sendNotificationToUser(
      userId: userId,
      title: 'Book Returned',
      body: body,
      data: {
        'type': 'return_confirmation',
        'hadFine': hadFine.toString(),
        'fineAmount': fineAmount.toString(),
      },
    );
  }
}
