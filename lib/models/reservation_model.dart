import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a book reservation in the library system.
///
/// This model maps to the 'reservations' collection in Firestore and tracks
/// user reservations for books that are currently unavailable, managing
/// the queue and notification process when books become available.
class Reservation {
  /// Unique identifier for the reservation
  final String id;

  /// Reference to the user who made the reservation
  final String userId;

  /// Reference to the book being reserved
  final String bookId;

  /// Reference to the specific book item allocated for this reservation
  ///
  /// This is null until a specific copy is assigned to fulfill the reservation.
  final String? itemId;

  /// Date and time when the reservation was created
  final Timestamp reservedAt;

  /// Current status of the reservation
  ///
  /// Possible values:
  /// - "waiting": Reservation is active and waiting for book availability
  /// - "notified": User has been notified that a book is available
  /// - "fulfilled": Reservation was completed (book was borrowed)
  /// - "canceled": Reservation was canceled by user or system
  final String status;

  /// Creates a new [Reservation] instance.
  ///
  /// All parameters except [itemId] are required.
  /// [itemId] is nullable as it's only set when a book item is assigned.
  Reservation({
    required this.id,
    required this.userId,
    required this.bookId,
    this.itemId,
    required this.reservedAt,
    required this.status,
  });

  /// Creates a [Reservation] instance from a Firestore document.
  ///
  /// Maps the Firestore document fields to the Reservation model properties.
  /// The document ID is used as the reservation's ID.
  ///
  /// Example:
  /// ```dart
  /// DocumentSnapshot doc = await FirebaseFirestore.instance
  ///     .collection('reservations')
  ///     .doc('reservationId')
  ///     .get();
  /// Reservation reservation = Reservation.fromDoc(doc);
  /// ```
  factory Reservation.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return Reservation(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      bookId: data['bookId'] as String? ?? '',
      itemId: data['itemId'] as String?,
      reservedAt: data['reservedAt'] as Timestamp? ?? Timestamp.now(),
      status: data['status'] as String? ?? 'waiting',
    );
  }

  /// Converts the [Reservation] instance to a JSON map.
  ///
  /// This is useful for sending data to Firestore or serializing
  /// the reservation data for other purposes.
  ///
  /// Returns a map with all reservation properties except the ID,
  /// as Firestore document IDs are stored separately.
  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'bookId': bookId,
      'itemId': itemId,
      'reservedAt': reservedAt,
      'status': status,
    };
  }

  /// Creates a copy of this [Reservation] with the given fields replaced.
  ///
  /// Useful for updating specific fields while keeping others unchanged.
  Reservation copyWith({
    String? id,
    String? userId,
    String? bookId,
    String? itemId,
    Timestamp? reservedAt,
    String? status,
  }) {
    return Reservation(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      bookId: bookId ?? this.bookId,
      itemId: itemId ?? this.itemId,
      reservedAt: reservedAt ?? this.reservedAt,
      status: status ?? this.status,
    );
  }

  /// Checks if the reservation is currently active (waiting).
  bool get isWaiting => status == 'waiting';

  /// Checks if the user has been notified about book availability.
  bool get isNotified => status == 'notified';

  /// Checks if the reservation has been fulfilled.
  bool get isFulfilled => status == 'fulfilled';

  /// Checks if the reservation has been canceled.
  bool get isCanceled => status == 'canceled';

  /// Checks if the reservation is still active (not fulfilled or canceled).
  bool get isActive => status == 'waiting' || status == 'notified';

  /// Checks if a book item has been assigned to this reservation.
  bool get hasItemAssigned => itemId != null && itemId!.isNotEmpty;

  /// Calculates the number of days since the reservation was made.
  int get daysSinceReserved {
    final reserved = reservedAt.toDate();
    final now = DateTime.now();
    return now.difference(reserved).inDays;
  }

  @override
  String toString() {
    return 'Reservation(id: $id, userId: $userId, bookId: $bookId, '
        'itemId: $itemId, status: $status, reservedAt: ${reservedAt.toDate()})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is Reservation && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
