import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a book in the library system.
///
/// This model maps to the 'books' collection in Firestore and contains
/// information about a book including its metadata, authors, categories,
/// and availability status.
class Book {
  /// Unique identifier for the book
  final String id;

  /// Title of the book
  final String title;

  /// International Standard Book Number
  final String isbn;

  /// List of authors who wrote the book
  final List<String> authors;

  /// List of categories/genres the book belongs to
  final List<String> categories;

  /// Date when the book was published
  final Timestamp publishedAt;

  /// URL to the book's cover image
  final String coverUrl;

  /// Total number of copies owned by the library
  final int totalCopies;

  /// Number of copies currently available for loan
  final int availableCopies;

  /// Creates a new [Book] instance.
  ///
  /// All parameters are required and must not be null.
  Book({
    required this.id,
    required this.title,
    required this.isbn,
    required this.authors,
    required this.categories,
    required this.publishedAt,
    required this.coverUrl,
    required this.totalCopies,
    required this.availableCopies,
  });

  /// Creates a [Book] instance from a Firestore document.
  ///
  /// Maps the Firestore document fields to the Book model properties.
  /// The document ID is used as the book's ID.
  ///
  /// Example:
  /// ```dart
  /// DocumentSnapshot doc = await FirebaseFirestore.instance
  ///     .collection('books')
  ///     .doc('bookId')
  ///     .get();
  /// Book book = Book.fromDoc(doc);
  /// ```
  factory Book.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return Book(
      id: doc.id,
      title: data['title'] as String? ?? '',
      isbn: data['isbn'] as String? ?? '',
      authors: _parseStringList(data['authors']),
      categories: _parseStringList(data['categories']),
      publishedAt: data['publishedAt'] as Timestamp? ?? Timestamp.now(),
      coverUrl: data['coverUrl'] as String? ?? '',
      totalCopies: (data['totalCopies'] as num?)?.toInt() ?? 0,
      availableCopies: (data['availableCopies'] as num?)?.toInt() ?? 0,
    );
  }

  /// Helper method to safely parse string or list to List<String>
  static List<String> _parseStringList(dynamic value) {
    if (value == null) return [];
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }
    if (value is String) {
      return value.isEmpty ? [] : [value];
    }
    return [];
  }

  /// Converts the [Book] instance to a JSON map.
  ///
  /// This is useful for sending data to Firestore or serializing
  /// the book data for other purposes.
  ///
  /// Returns a map with all book properties except the ID,
  /// as Firestore document IDs are stored separately.
  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'isbn': isbn,
      'authors': authors,
      'categories': categories,
      'publishedAt': publishedAt,
      'coverUrl': coverUrl,
      'totalCopies': totalCopies,
      'availableCopies': availableCopies,
    };
  }

  /// Creates a copy of this [Book] with the given fields replaced.
  ///
  /// Useful for updating specific fields while keeping others unchanged.
  Book copyWith({
    String? id,
    String? title,
    String? isbn,
    List<String>? authors,
    List<String>? categories,
    Timestamp? publishedAt,
    String? coverUrl,
    int? totalCopies,
    int? availableCopies,
  }) {
    return Book(
      id: id ?? this.id,
      title: title ?? this.title,
      isbn: isbn ?? this.isbn,
      authors: authors ?? this.authors,
      categories: categories ?? this.categories,
      publishedAt: publishedAt ?? this.publishedAt,
      coverUrl: coverUrl ?? this.coverUrl,
      totalCopies: totalCopies ?? this.totalCopies,
      availableCopies: availableCopies ?? this.availableCopies,
    );
  }

  @override
  String toString() {
    return 'Book(id: $id, title: $title, isbn: $isbn, authors: $authors, '
        'categories: $categories, totalCopies: $totalCopies, '
        'availableCopies: $availableCopies)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is Book && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
