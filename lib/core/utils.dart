import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

/// Utility functions used throughout the application.
///
/// This file contains helper functions for common tasks like date formatting,
/// currency formatting, displaying snackbars, generating IDs, and safe printing.

/// Formats a DateTime object to a readable string format.
///
/// Converts a DateTime to the format "dd/MM/yyyy" (e.g., "25/12/2023").
/// Returns "N/A" if the input is null.
///
/// Parameters:
/// - [date]: The DateTime object to format
///
/// Returns a formatted date string.
///
/// Example:
/// ```dart
/// final date = DateTime(2023, 12, 25);
/// print(formatDate(date)); // Output: "25/12/2023"
/// ```
String formatDate(DateTime? date) {
  if (date == null) return 'N/A';
  return DateFormat('dd/MM/yyyy').format(date);
}

/// Formats a DateTime object to a readable string with time.
///
/// Converts a DateTime to the format "dd/MM/yyyy HH:mm" (e.g., "25/12/2023 14:30").
/// Returns "N/A" if the input is null.
///
/// Parameters:
/// - [dateTime]: The DateTime object to format
///
/// Returns a formatted date-time string.
///
/// Example:
/// ```dart
/// final dateTime = DateTime(2023, 12, 25, 14, 30);
/// print(formatDateTime(dateTime)); // Output: "25/12/2023 14:30"
/// ```
String formatDateTime(DateTime? dateTime) {
  if (dateTime == null) return 'N/A';
  return DateFormat('dd/MM/yyyy HH:mm').format(dateTime);
}

/// Formats a Firestore Timestamp to a readable date string.
///
/// Converts a Firestore Timestamp to the format "dd/MM/yyyy".
/// Returns "N/A" if the input is null.
///
/// Parameters:
/// - [timestamp]: The Firestore Timestamp to format
///
/// Returns a formatted date string.
///
/// Example:
/// ```dart
/// final timestamp = Timestamp.now();
/// print(formatTimestamp(timestamp)); // Output: "06/12/2025"
/// ```
String formatTimestamp(Timestamp? timestamp) {
  if (timestamp == null) return 'N/A';
  return formatDate(timestamp.toDate());
}

/// Formats an integer value as Vietnamese currency (VND).
///
/// Converts an integer to a currency string with thousand separators
/// and the "đ" symbol (e.g., "15.000đ").
///
/// Parameters:
/// - [value]: The amount to format (in VND)
///
/// Returns a formatted currency string.
///
/// Example:
/// ```dart
/// print(formatCurrency(15000)); // Output: "15.000đ"
/// print(formatCurrency(1234567)); // Output: "1.234.567đ"
/// ```
String formatCurrency(int value) {
  final formatter = NumberFormat('#,##0', 'vi_VN');
  return '${formatter.format(value)}đ';
}

/// Formats a double value as Vietnamese currency (VND).
///
/// Converts a double to a currency string with thousand separators
/// and the "đ" symbol.
///
/// Parameters:
/// - [value]: The amount to format (in VND)
///
/// Returns a formatted currency string.
///
/// Example:
/// ```dart
/// print(formatCurrencyDouble(15000.50)); // Output: "15.000đ"
/// ```
String formatCurrencyDouble(double value) {
  return formatCurrency(value.toInt());
}

/// Displays a snackbar message at the bottom of the screen.
///
/// Shows a brief message to the user using Material Design's SnackBar.
/// The message appears at the bottom of the screen and automatically dismisses.
///
/// Parameters:
/// - [context]: The BuildContext for showing the snackbar
/// - [message]: The text message to display
/// - [isError]: Whether this is an error message (changes background color)
/// - [duration]: How long to show the snackbar (default: 3 seconds)
///
/// Example:
/// ```dart
/// showSnack(context, 'Book borrowed successfully!');
/// showSnack(context, 'Error: Book not found', isError: true);
/// ```
void showSnack(
  BuildContext context,
  String message, {
  bool isError = false,
  Duration duration = const Duration(seconds: 3),
}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: isError ? Colors.red : null,
      duration: duration,
      behavior: SnackBarBehavior.floating,
      action: SnackBarAction(
        label: 'Đóng',
        textColor: Colors.white,
        onPressed: () {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
        },
      ),
    ),
  );
}

/// Displays a success snackbar message.
///
/// Convenience method to show a success message with green background.
///
/// Parameters:
/// - [context]: The BuildContext for showing the snackbar
/// - [message]: The success message to display
///
/// Example:
/// ```dart
/// showSuccessSnack(context, 'Book returned successfully!');
/// ```
void showSuccessSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.white),
          const SizedBox(width: 8),
          Expanded(child: Text(message)),
        ],
      ),
      backgroundColor: Colors.green,
      duration: const Duration(seconds: 3),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

/// Displays an error snackbar message.
///
/// Convenience method to show an error message with red background.
///
/// Parameters:
/// - [context]: The BuildContext for showing the snackbar
/// - [message]: The error message to display
///
/// Example:
/// ```dart
/// showErrorSnack(context, 'Failed to borrow book');
/// ```
void showErrorSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          const Icon(Icons.error, color: Colors.white),
          const SizedBox(width: 8),
          Expanded(child: Text(message)),
        ],
      ),
      backgroundColor: Colors.red,
      duration: const Duration(seconds: 4),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

/// Generates a unique ID using Firestore's auto-ID generation.
///
/// Creates a random, unique identifier similar to Firestore's auto-generated
/// document IDs. Useful for creating IDs before saving to Firestore.
///
/// Returns a unique string identifier (20 characters).
///
/// Example:
/// ```dart
/// final newId = generateId();
/// print(newId); // Output: "k5j2h4g1k9l0m3n5p7q8"
/// ```
String generateId() {
  return FirebaseFirestore.instance.collection('temp').doc().id;
}

/// Safe print function that handles null values gracefully.
///
/// Wrapper around Dart's print function that safely converts objects to strings
/// and handles null values without throwing errors. Useful for debugging.
///
/// Parameters:
/// - [object]: The object to print (can be null)
/// - [label]: Optional label prefix for the print statement
///
/// Example:
/// ```dart
/// safePrint('Hello'); // Output: "Hello"
/// safePrint(null); // Output: "null"
/// safePrint('User ID', label: 'DEBUG'); // Output: "DEBUG: User ID"
/// ```
void safePrint(Object? object, {String? label}) {
  try {
    if (label != null) {
      // ignore: avoid_print
      print('$label: ${object?.toString() ?? 'null'}');
    } else {
      // ignore: avoid_print
      print(object?.toString() ?? 'null');
    }
  } catch (e) {
    // If printing fails, try to print the error
    // ignore: avoid_print
    print('Error printing object: $e');
  }
}

/// Validates if an email address is valid.
///
/// Checks if the email matches the standard email format pattern.
///
/// Parameters:
/// - [email]: The email address to validate
///
/// Returns true if valid, false otherwise.
///
/// Example:
/// ```dart
/// print(isValidEmail('user@example.com')); // Output: true
/// print(isValidEmail('invalid-email')); // Output: false
/// ```
bool isValidEmail(String email) {
  final emailRegex = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );
  return emailRegex.hasMatch(email);
}

/// Validates if a phone number is valid (Vietnamese format).
///
/// Checks if the phone number matches Vietnamese phone number patterns.
/// Accepts formats starting with 0 or +84 followed by 9 digits.
///
/// Parameters:
/// - [phone]: The phone number to validate
///
/// Returns true if valid, false otherwise.
///
/// Example:
/// ```dart
/// print(isValidPhone('0912345678')); // Output: true
/// print(isValidPhone('+84912345678')); // Output: true
/// print(isValidPhone('123456')); // Output: false
/// ```
bool isValidPhone(String phone) {
  final phoneRegex = RegExp(r'^(0|\+84)[0-9]{9}$');
  return phoneRegex.hasMatch(phone);
}

/// Calculates the number of days between two dates.
///
/// Returns the absolute difference in days between two DateTime objects.
///
/// Parameters:
/// - [start]: The start date
/// - [end]: The end date
///
/// Returns the number of days between the dates.
///
/// Example:
/// ```dart
/// final start = DateTime(2023, 12, 1);
/// final end = DateTime(2023, 12, 25);
/// print(daysBetween(start, end)); // Output: 24
/// ```
int daysBetween(DateTime start, DateTime end) {
  final difference = end.difference(start);
  return difference.inDays.abs();
}

/// Shows a confirmation dialog with Yes/No options.
///
/// Displays a dialog asking the user to confirm an action.
///
/// Parameters:
/// - [context]: The BuildContext for showing the dialog
/// - [title]: The dialog title
/// - [message]: The confirmation message
/// - [confirmText]: Text for the confirm button (default: "Xác nhận")
/// - [cancelText]: Text for the cancel button (default: "Hủy")
///
/// Returns true if user confirms, false if cancelled.
///
/// Example:
/// ```dart
/// final confirmed = await showConfirmDialog(
///   context,
///   'Delete Book',
///   'Are you sure you want to delete this book?',
/// );
/// if (confirmed) {
///   // Delete the book
/// }
/// ```
Future<bool> showConfirmDialog(
  BuildContext context,
  String title,
  String message, {
  String confirmText = 'Xác nhận',
  String cancelText = 'Hủy',
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(cancelText),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(confirmText),
        ),
      ],
    ),
  );
  return result ?? false;
}
