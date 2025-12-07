import 'package:flutter/material.dart';

/// Application-wide constants for colors, text styles, configuration, and collection names.
///
/// This class contains all static constant values used throughout the application
/// to ensure consistency and make it easy to update values in one place.
class AppConstants {
  AppConstants._(); // Private constructor to prevent instantiation
}

/// Color palette used throughout the application.
///
/// Defines the main colors for consistent theming across all screens.
class AppColors {
  AppColors._(); // Private constructor to prevent instantiation

  /// Primary color used for app bars, buttons, and main UI elements
  static const Color primaryColor = Color(0xFF2196F3); // Blue

  /// Secondary color used for accents and highlights
  static const Color secondaryColor = Color(0xFF03A9F4); // Light Blue

  /// Background color for screens and cards
  static const Color backgroundColor = Color(0xFFF5F5F5); // Light Grey

  /// Error color for warnings and error messages
  static const Color errorColor = Color(0xFFD32F2F); // Red

  /// Success color for positive actions and confirmations
  static const Color successColor = Color(0xFF388E3C); // Green

  /// Warning color for caution messages
  static const Color warningColor = Color(0xFFFFA726); // Orange

  /// Text color for primary content
  static const Color textPrimary = Color(0xFF212121); // Dark Grey

  /// Text color for secondary/hint content
  static const Color textSecondary = Color(0xFF757575); // Medium Grey

  /// Divider and border color
  static const Color dividerColor = Color(0xFFBDBDBD); // Light Grey
}

/// Text styles used throughout the application.
///
/// Defines consistent typography for different text elements.
class AppTextStyles {
  AppTextStyles._(); // Private constructor to prevent instantiation

  /// Large title text style (used for page headers)
  static const TextStyle title = TextStyle(
    fontSize: 24.0,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
    letterSpacing: 0.5,
  );

  /// Medium subtitle text style (used for section headers)
  static const TextStyle subtitle = TextStyle(
    fontSize: 18.0,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    letterSpacing: 0.25,
  );

  /// Regular body text style (used for main content)
  static const TextStyle body = TextStyle(
    fontSize: 14.0,
    fontWeight: FontWeight.normal,
    color: AppColors.textPrimary,
    height: 1.5,
  );

  /// Small caption text style (used for hints and secondary info)
  static const TextStyle caption = TextStyle(
    fontSize: 12.0,
    fontWeight: FontWeight.normal,
    color: AppColors.textSecondary,
  );

  /// Button text style
  static const TextStyle button = TextStyle(
    fontSize: 16.0,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
  );
}

/// Application configuration constants.
///
/// Contains business logic settings such as loan durations and fine amounts.
class AppConfig {
  AppConfig._(); // Private constructor to prevent instantiation

  /// Default number of days a book can be borrowed
  ///
  /// Standard loan period for all books unless specified otherwise.
  static const int defaultBorrowDays = 14;

  /// Fine amount per day for overdue books (in VND)
  ///
  /// Members are charged this amount for each day a book is overdue.
  static const int finePerDay = 5000;

  /// Maximum number of books a regular member can borrow simultaneously
  static const int maxBooksPerMember = 3;

  /// Maximum number of books a librarian can borrow simultaneously
  static const int maxBooksPerLibrarian = 10;

  /// Maximum number of times a loan can be renewed
  static const int maxRenewals = 2;

  /// Number of days to extend loan when renewed
  static const int renewalExtensionDays = 7;

  /// Number of days a reservation remains valid before automatic cancellation
  static const int reservationExpiryDays = 3;
}

/// Firestore collection names used in the database.
///
/// Centralized location for all Firestore collection paths to avoid typos
/// and ensure consistency across the application.
class FirestoreCollections {
  FirestoreCollections._(); // Private constructor to prevent instantiation

  /// Collection storing user profile information
  ///
  /// Contains documents with user details, roles, and authentication data.
  static const String users = 'users';

  /// Collection storing book catalog information
  ///
  /// Contains documents with book metadata like title, ISBN, authors, etc.
  static const String books = 'books';

  /// Collection storing physical book item/copy information
  ///
  /// Contains documents for each physical copy of a book with barcode and status.
  static const String bookItems = 'bookItems';

  /// Collection storing loan transaction records
  ///
  /// Contains documents tracking when books are borrowed and returned.
  static const String loans = 'loans';

  /// Collection storing book reservation records
  ///
  /// Contains documents for when users reserve books that are currently unavailable.
  static const String reservations = 'reservations';

  /// Collection storing notification records
  ///
  /// Contains documents for in-app notifications sent to users.
  static const String notifications = 'notifications';
}

/// API endpoint constants (if needed for future external integrations).
class ApiEndpoints {
  ApiEndpoints._(); // Private constructor to prevent instantiation

  /// Base URL for external book information API (e.g., Google Books API)
  static const String bookInfoBaseUrl = 'https://www.googleapis.com/books/v1';

  /// Timeout duration for API calls in seconds
  static const int apiTimeoutSeconds = 30;
}

/// Asset path constants for images and icons.
class AssetPaths {
  AssetPaths._(); // Private constructor to prevent instantiation

  /// Default book cover image when no cover is available
  static const String defaultBookCover = 'assets/images/default_book_cover.png';

  /// App logo image
  static const String appLogo = 'assets/images/app_logo.png';

  /// User avatar placeholder
  static const String defaultAvatar = 'assets/images/default_avatar.png';
}

/// Validation constants for form inputs.
class ValidationConstants {
  ValidationConstants._(); // Private constructor to prevent instantiation

  /// Minimum length for password
  static const int minPasswordLength = 6;

  /// Maximum length for password
  static const int maxPasswordLength = 50;

  /// ISBN length (ISBN-13 standard)
  static const int isbnLength = 13;

  /// Regular expression pattern for email validation
  static const String emailPattern =
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$';

  /// Regular expression pattern for phone number validation (Vietnamese format)
  static const String phonePattern = r'^(0|\+84)[0-9]{9}$';
}

/// Date and time format constants.
class DateTimeFormats {
  DateTimeFormats._(); // Private constructor to prevent instantiation

  /// Display format for dates (e.g., "25/12/2023")
  static const String displayDate = 'dd/MM/yyyy';

  /// Display format for date and time (e.g., "25/12/2023 14:30")
  static const String displayDateTime = 'dd/MM/yyyy HH:mm';

  /// Display format for time only (e.g., "14:30")
  static const String displayTime = 'HH:mm';
}
