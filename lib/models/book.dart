import 'package:cloud_firestore/cloud_firestore.dart';

class Book {
  final String id;
  final String title;
  final List<String> authors;
  final String isbn;
  final int totalCopies;
  final int availableCopies;
  final String description;
  final String? coverImageUrl;

  Book({
    required this.id,
    required this.title,
    this.authors = const [],
    required this.isbn,
    this.totalCopies = 0,
    this.availableCopies = 0,
    this.description = '',
    this.coverImageUrl,
  });

  factory Book.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return Book(
      id: doc.id,
      title: data['title'] ?? '',
      authors: List<String>.from(data['authors'] ?? []),
      isbn: data['isbn'] ?? '',
      totalCopies: data['totalCopies'] ?? 0,
      availableCopies: data['availableCopies'] ?? 0,
      description: data['description'] ?? '',
      coverImageUrl: data['coverUrl'] ?? data['coverImageUrl'],
    );
  }

  Map<String, dynamic> toMap() => {
    'title': title,
    'authors': authors,
    'isbn': isbn,
    'totalCopies': totalCopies,
    'availableCopies': availableCopies,
    'description': description,
    'coverImageUrl': coverImageUrl,
  };
}
