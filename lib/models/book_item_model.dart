import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a physical copy of a book in the library system.
///
/// This model maps to the 'bookItems' collection in Firestore.
/// Each BookItem represents an individual copy of a book that can be
/// borrowed, reserved, or made available for circulation.
class BookItem {
  /// Unique identifier for the book item
  final String id;

  /// Reference to the parent book this item belongs to
  final String bookId;

  /// Unique barcode for tracking this specific copy
  final String barcode;

  /// Physical location in the library (e.g., "Shelf A-12", "Section B")
  final String location;

  /// Current status of the book item
  ///
  /// Possible values:
  /// - "available": Ready to be borrowed
  /// - "borrowed": Currently on loan
  /// - "reserved": Reserved for a member
  /// - "maintenance": Under repair or processing
  /// - "lost": Reported as lost
  final String status;

  /// Physical condition of the book
  ///
  /// Examples: "excellent", "good", "fair", "poor", "damaged"
  final String condition;

  /// Timestamp when this book item was added to the system
  final Timestamp createdAt;

  /// Creates a new [BookItem] instance.
  ///
  /// All parameters are required and must not be null.
  BookItem({
    required this.id,
    required this.bookId,
    required this.barcode,
    required this.location,
    required this.status,
    required this.condition,
    required this.createdAt,
  });

  /// Creates a [BookItem] instance from a Firestore document.
  ///
  /// Maps the Firestore document fields to the BookItem model properties.
  /// The document ID is used as the book item's ID.
  ///
  /// Example:
  /// ```dart
  /// DocumentSnapshot doc = await FirebaseFirestore.instance
  ///     .collection('bookItems')
  ///     .doc('itemId')
  ///     .get();
  /// BookItem bookItem = BookItem.fromDoc(doc);
  /// ```
  factory BookItem.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return BookItem(
      id: doc.id,
      bookId: data['bookId'] as String? ?? '',
      barcode: data['barcode'] as String? ?? '',
      location: data['location'] as String? ?? '',
      status: data['status'] as String? ?? 'available',
      condition: data['condition'] as String? ?? 'good',
      createdAt: data['createdAt'] as Timestamp? ?? Timestamp.now(),
    );
  }

  /// Converts the [BookItem] instance to a JSON map.
  ///
  /// This is useful for sending data to Firestore or serializing
  /// the book item data for other purposes.
  ///
  /// Returns a map with all book item properties except the ID,
  /// as Firestore document IDs are stored separately.
  Map<String, dynamic> toJson() {
    return {
      'bookId': bookId,
      'barcode': barcode,
      'location': location,
      'status': status,
      'condition': condition,
      'createdAt': createdAt,
    };
  }

  /// Creates a copy of this [BookItem] with the given fields replaced.
  ///
  /// Useful for updating specific fields while keeping others unchanged.
  BookItem copyWith({
    String? id,
    String? bookId,
    String? barcode,
    String? location,
    String? status,
    String? condition,
    Timestamp? createdAt,
  }) {
    return BookItem(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      barcode: barcode ?? this.barcode,
      location: location ?? this.location,
      status: status ?? this.status,
      condition: condition ?? this.condition,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Checks if the book item is currently available for borrowing.
  bool get isAvailable => status == 'available';

  /// Checks if the book item is currently borrowed.
  bool get isBorrowed => status == 'borrowed';

  /// Checks if the book item is currently reserved.
  bool get isReserved => status == 'reserved';

  @override
  String toString() {
    return 'BookItem(id: $id, bookId: $bookId, barcode: $barcode, '
        'location: $location, status: $status, condition: $condition)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is BookItem && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
