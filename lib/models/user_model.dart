import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a user in the library management system.
///
/// This model maps to the 'users' collection in Firestore and contains
/// information about library members and staff, including their personal
/// information, role, and borrowing limits.
class AppUser {
  /// Unique identifier for the user (Firebase Auth UID)
  final String uid;

  /// Full name of the user
  final String fullName;

  /// Email address of the user
  final String email;

  /// Role of the user in the system
  ///
  /// Possible values:
  /// - "member": Regular library member who can borrow books
  /// - "librarian": Library staff with administrative privileges
  final String role;

  /// Unique library card number assigned to the user
  final String cardNumber;

  /// Maximum number of books the user can borrow simultaneously
  final int maxBorrow;

  /// Current number of books borrowed by the user
  final int borrowedCount;

  /// Phone number of the user
  final String phone;

  /// Address of the user
  final String address;

  /// Timestamp when the user account was created
  final Timestamp createdAt;

  /// Creates a new [AppUser] instance.
  ///
  /// All parameters are required and must not be null.
  AppUser({
    required this.uid,
    required this.fullName,
    required this.email,
    required this.role,
    required this.cardNumber,
    required this.maxBorrow,
    required this.borrowedCount,
    required this.phone,
    required this.address,
    required this.createdAt,
  });

  /// Creates an [AppUser] instance from a Firestore document.
  ///
  /// Maps the Firestore document fields to the AppUser model properties.
  /// The document ID is used as the user's UID.
  ///
  /// Example:
  /// ```dart
  /// DocumentSnapshot doc = await FirebaseFirestore.instance
  ///     .collection('users')
  ///     .doc('userId')
  ///     .get();
  /// AppUser user = AppUser.fromDoc(doc);
  /// ```
  factory AppUser.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return AppUser(
      uid: doc.id,
      fullName: data['fullName'] as String? ?? '',
      email: data['email'] as String? ?? '',
      role: data['role'] as String? ?? 'member',
      cardNumber: data['cardNumber'] as String? ?? '',
      maxBorrow: data['maxBorrow'] as int? ?? 3,
      borrowedCount: data['borrowedCount'] as int? ?? 0,
      phone: data['phone'] as String? ?? '',
      address: data['address'] as String? ?? '',
      createdAt: data['createdAt'] as Timestamp? ?? Timestamp.now(),
    );
  }

  /// Converts the [AppUser] instance to a JSON map.
  ///
  /// This is useful for sending data to Firestore or serializing
  /// the user data for other purposes.
  ///
  /// Returns a map with all user properties except the UID,
  /// as Firestore document IDs are stored separately.
  Map<String, dynamic> toJson() {
    return {
      'fullName': fullName,
      'email': email,
      'role': role,
      'cardNumber': cardNumber,
      'maxBorrow': maxBorrow,
      'borrowedCount': borrowedCount,
      'phone': phone,
      'address': address,
      'createdAt': createdAt,
    };
  }

  /// Creates a copy of this [AppUser] with the given fields replaced.
  ///
  /// Useful for updating specific fields while keeping others unchanged.
  AppUser copyWith({
    String? uid,
    String? fullName,
    String? email,
    String? role,
    String? cardNumber,
    int? maxBorrow,
    int? borrowedCount,
    String? phone,
    String? address,
    Timestamp? createdAt,
  }) {
    return AppUser(
      uid: uid ?? this.uid,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      role: role ?? this.role,
      cardNumber: cardNumber ?? this.cardNumber,
      maxBorrow: maxBorrow ?? this.maxBorrow,
      borrowedCount: borrowedCount ?? this.borrowedCount,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Checks if the user is a librarian.
  bool get isLibrarian => role == 'librarian';

  /// Checks if the user is a member.
  bool get isMember => role == 'member';

  /// Checks if the user can borrow more books.
  bool get canBorrowMore => borrowedCount < maxBorrow;

  /// Gets the number of remaining books the user can borrow.
  int get remainingBorrowLimit => maxBorrow - borrowedCount;

  @override
  String toString() {
    return 'AppUser(uid: $uid, fullName: $fullName, email: $email, '
        'role: $role, cardNumber: $cardNumber, borrowedCount: $borrowedCount, '
        'maxBorrow: $maxBorrow)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is AppUser && other.uid == uid;
  }

  @override
  int get hashCode => uid.hashCode;
}
