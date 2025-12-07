import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/book_model.dart';
import '../models/book_item_model.dart';

/// Service class for handling book-related operations with Firestore.
///
/// This service provides CRUD operations for managing books in the library
/// system, including creating book records and their physical copies (book items).
class BookService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Adds a new book to the library and creates its physical copies.
  ///
  /// Creates a document in the 'books' collection and generates the specified
  /// number of book item documents in the 'bookItems' collection.
  /// Each book item is created with a unique barcode and default status "available".
  ///
  /// Parameters:
  /// - [book]: The book object to add (id field will be auto-generated)
  /// - [numberOfCopies]: Number of physical copies to create
  ///
  /// Throws:
  /// - [FirebaseException] for Firestore errors
  /// - [Exception] for validation or unexpected errors
  ///
  /// Example:
  /// ```dart
  /// final book = Book(
  ///   id: '', // Will be auto-generated
  ///   title: 'The Great Gatsby',
  ///   isbn: '9780743273565',
  ///   authors: ['F. Scott Fitzgerald'],
  ///   categories: ['Fiction', 'Classic'],
  ///   publishedAt: Timestamp.now(),
  ///   coverUrl: 'https://example.com/cover.jpg',
  ///   totalCopies: 5,
  ///   availableCopies: 5,
  /// );
  /// await bookService.addBook(book, 5);
  /// ```
  Future<void> addBook(Book book, int numberOfCopies) async {
    try {
      // Validate number of copies
      if (numberOfCopies <= 0) {
        throw Exception('Number of copies must be greater than 0.');
      }

      // Create book document reference
      final DocumentReference bookRef = _firestore.collection('books').doc();

      // Create book with updated values
      final Book newBook = book.copyWith(
        id: bookRef.id,
        totalCopies: numberOfCopies,
        availableCopies: numberOfCopies,
      );

      // Use batch write for atomic operation
      final WriteBatch batch = _firestore.batch();

      // Add book document
      batch.set(bookRef, newBook.toJson());

      // Create book items (physical copies)
      for (int i = 0; i < numberOfCopies; i++) {
        final DocumentReference itemRef = _firestore
            .collection('bookItems')
            .doc();

        final BookItem bookItem = BookItem(
          id: itemRef.id,
          bookId: bookRef.id,
          barcode: _generateBarcode(bookRef.id, i + 1),
          location: 'General Section', // Default location
          status: 'available',
          condition: 'good',
          createdAt: Timestamp.now(),
        );

        batch.set(itemRef, bookItem.toJson());
      }

      // Commit batch operation
      await batch.commit();
    } on FirebaseException catch (e) {
      throw Exception('Database error while adding book: ${e.message}');
    } catch (e) {
      throw Exception('An unexpected error occurred: $e');
    }
  }

  /// Fetches all books from the library.
  ///
  /// Retrieves all documents from the 'books' collection and converts
  /// them to Book objects.
  ///
  /// Returns a list of [Book] objects. Returns empty list if no books exist.
  ///
  /// Throws:
  /// - [FirebaseException] for Firestore errors
  ///
  /// Example:
  /// ```dart
  /// try {
  ///   final books = await bookService.fetchAllBooks();
  ///   print('Found ${books.length} books');
  /// } catch (e) {
  ///   print('Error: $e');
  /// }
  /// ```
  Future<List<Book>> fetchAllBooks() async {
    try {
      final QuerySnapshot snapshot = await _firestore
          .collection('books')
          .orderBy('title')
          .get();

      return snapshot.docs.map((doc) => Book.fromDoc(doc)).toList();
    } on FirebaseException catch (e) {
      throw Exception('Database error while fetching books: ${e.message}');
    } catch (e) {
      throw Exception('An unexpected error occurred: $e');
    }
  }

  /// Gets a specific book by its ID.
  ///
  /// Retrieves a single book document from Firestore by its ID.
  ///
  /// Parameters:
  /// - [bookId]: The unique identifier of the book
  ///
  /// Returns the [Book] object if found, null if not found.
  ///
  /// Throws:
  /// - [FirebaseException] for Firestore errors
  ///
  /// Example:
  /// ```dart
  /// try {
  ///   final book = await bookService.getBookById('book123');
  ///   if (book != null) {
  ///     print('Found: ${book.title}');
  ///   }
  /// } catch (e) {
  ///   print('Error: $e');
  /// }
  /// ```
  Future<Book?> getBookById(String bookId) async {
    try {
      if (bookId.isEmpty) {
        throw Exception('Book ID cannot be empty.');
      }

      final DocumentSnapshot doc = await _firestore
          .collection('books')
          .doc(bookId)
          .get();

      if (!doc.exists) {
        return null;
      }

      return Book.fromDoc(doc);
    } on FirebaseException catch (e) {
      throw Exception('Database error while fetching book: ${e.message}');
    } catch (e) {
      throw Exception('An unexpected error occurred: $e');
    }
  }

  /// Updates an existing book's information.
  ///
  /// Updates the book document in Firestore. Note: This does not update
  /// the book items. Use separate methods to manage book items.
  ///
  /// Parameters:
  /// - [book]: The book object with updated information
  ///
  /// Throws:
  /// - [FirebaseException] for Firestore errors
  /// - [Exception] if book doesn't exist
  ///
  /// Example:
  /// ```dart
  /// try {
  ///   final updatedBook = book.copyWith(title: 'New Title');
  ///   await bookService.updateBook(updatedBook);
  /// } catch (e) {
  ///   print('Error: $e');
  /// }
  /// ```
  Future<void> updateBook(Book book) async {
    try {
      if (book.id.isEmpty) {
        throw Exception('Book ID cannot be empty.');
      }

      // Check if book exists
      final DocumentSnapshot doc = await _firestore
          .collection('books')
          .doc(book.id)
          .get();

      if (!doc.exists) {
        throw Exception('Book not found.');
      }

      // Update book document
      await _firestore.collection('books').doc(book.id).update(book.toJson());
    } on FirebaseException catch (e) {
      throw Exception('Database error while updating book: ${e.message}');
    } catch (e) {
      throw Exception('An unexpected error occurred: $e');
    }
  }

  /// Deletes a book and all its associated book items.
  ///
  /// Removes the book document and all related book item documents from Firestore.
  /// This operation uses a batch write for atomicity.
  ///
  /// Parameters:
  /// - [bookId]: The unique identifier of the book to delete
  ///
  /// Throws:
  /// - [FirebaseException] for Firestore errors
  /// - [Exception] if book doesn't exist or has active loans
  ///
  /// Example:
  /// ```dart
  /// try {
  ///   await bookService.deleteBook('book123');
  ///   print('Book deleted successfully');
  /// } catch (e) {
  ///   print('Error: $e');
  /// }
  /// ```
  Future<void> deleteBook(String bookId) async {
    try {
      if (bookId.isEmpty) {
        throw Exception('Book ID cannot be empty.');
      }

      // Check if book exists
      final DocumentSnapshot bookDoc = await _firestore
          .collection('books')
          .doc(bookId)
          .get();

      if (!bookDoc.exists) {
        throw Exception('Book not found.');
      }

      // Check if any copies are currently borrowed
      final QuerySnapshot borrowedItems = await _firestore
          .collection('bookItems')
          .where('bookId', isEqualTo: bookId)
          .where('status', isEqualTo: 'borrowed')
          .get();

      if (borrowedItems.docs.isNotEmpty) {
        throw Exception(
          'Cannot delete book with borrowed copies. '
          '${borrowedItems.docs.length} copies are currently on loan.',
        );
      }

      // Get all book items to delete
      final QuerySnapshot bookItems = await _firestore
          .collection('bookItems')
          .where('bookId', isEqualTo: bookId)
          .get();

      // Use batch write for atomic deletion
      final WriteBatch batch = _firestore.batch();

      // Delete book document
      batch.delete(_firestore.collection('books').doc(bookId));

      // Delete all book items
      for (final doc in bookItems.docs) {
        batch.delete(doc.reference);
      }

      // Commit batch operation
      await batch.commit();
    } on FirebaseException catch (e) {
      throw Exception('Database error while deleting book: ${e.message}');
    } catch (e) {
      throw Exception('An unexpected error occurred: $e');
    }
  }

  /// Searches for books with advanced filtering and pagination.
  ///
  /// Supports filtering by text query (title/authors), category, and pagination.
  /// Due to Firestore limitations on full-text search, the query uses a combination
  /// of where clauses and in-memory filtering for optimal performance.
  ///
  /// Parameters:
  /// - [query]: Search query string (searches in title and authors). If empty, returns all books.
  /// - [category]: Optional category filter (uses array-contains on categories field)
  /// - [limit]: Maximum number of results to return (default: 20)
  /// - [startAfter]: Document snapshot to start after for pagination (default: null)
  ///
  /// Returns a list of matching [Book] objects, limited by the specified count.
  ///
  /// Example:
  /// ```dart
  /// // Simple search
  /// final results = await bookService.searchBooks(query: 'gatsby');
  ///
  /// // Search with category filter
  /// final fiction = await bookService.searchBooks(
  ///   query: 'mystery',
  ///   category: 'Fiction',
  ///   limit: 10,
  /// );
  ///
  /// // Pagination
  /// final firstPage = await bookService.searchBooks(query: 'harry', limit: 10);
  /// final lastDoc = await _firestore.collection('books').doc(firstPage.last.id).get();
  /// final secondPage = await bookService.searchBooks(
  ///   query: 'harry',
  ///   limit: 10,
  ///   startAfter: lastDoc,
  /// );
  /// ```
  ///
  /// Throws:
  /// - [FirebaseException] for Firestore errors
  Future<List<Book>> searchBooks({
    String query = '',
    String? category,
    int limit = 20,
    DocumentSnapshot? startAfter,
  }) async {
    try {
      Query<Map<String, dynamic>> booksQuery = _firestore.collection('books');

      // Apply category filter if provided
      if (category != null && category.isNotEmpty) {
        booksQuery = booksQuery.where('categories', arrayContains: category);
      }

      // Order by title for consistent pagination
      booksQuery = booksQuery.orderBy('title');

      // Apply pagination if startAfter provided
      if (startAfter != null) {
        booksQuery = booksQuery.startAfterDocument(startAfter);
      }

      // Apply limit
      booksQuery = booksQuery.limit(limit);

      // Execute query
      final QuerySnapshot snapshot = await booksQuery.get();
      List<Book> books = snapshot.docs.map((doc) => Book.fromDoc(doc)).toList();

      // If query is provided, filter results in memory
      // Firestore doesn't support full-text search or LIKE queries natively
      if (query.isNotEmpty) {
        final String lowerQuery = query.toLowerCase();

        books = books.where((book) {
          // Check if query matches title
          final titleMatch = book.title.toLowerCase().contains(lowerQuery);

          // Check if query matches any author
          final authorMatch = book.authors.any(
            (author) => author.toLowerCase().contains(lowerQuery),
          );

          // Check if query matches ISBN
          final isbnMatch = book.isbn.toLowerCase().contains(lowerQuery);

          return titleMatch || authorMatch || isbnMatch;
        }).toList();
      }

      return books;
    } on FirebaseException catch (e) {
      throw Exception('Database error while searching books: ${e.message}');
    } catch (e) {
      throw Exception('An unexpected error occurred while searching: $e');
    }
  }

  /// Gets books by category.
  ///
  /// Parameters:
  /// - [category]: Category name to filter by
  ///
  /// Returns a list of [Book] objects in the specified category.
  Future<List<Book>> getBooksByCategory(String category) async {
    try {
      final QuerySnapshot snapshot = await _firestore
          .collection('books')
          .where('categories', arrayContains: category)
          .orderBy('title')
          .get();

      return snapshot.docs.map((doc) => Book.fromDoc(doc)).toList();
    } on FirebaseException catch (e) {
      throw Exception(
        'Database error while fetching books by category: ${e.message}',
      );
    } catch (e) {
      throw Exception('An unexpected error occurred: $e');
    }
  }

  /// Gets available books (books with at least one available copy).
  ///
  /// Returns a list of [Book] objects that have available copies.
  Future<List<Book>> getAvailableBooks() async {
    try {
      final QuerySnapshot snapshot = await _firestore
          .collection('books')
          .where('availableCopies', isGreaterThan: 0)
          .orderBy('availableCopies', descending: true)
          .orderBy('title')
          .get();

      return snapshot.docs.map((doc) => Book.fromDoc(doc)).toList();
    } on FirebaseException catch (e) {
      throw Exception(
        'Database error while fetching available books: ${e.message}',
      );
    } catch (e) {
      throw Exception('An unexpected error occurred: $e');
    }
  }

  /// Generates a unique barcode for a book item.
  ///
  /// Format: BOOK-{bookId_first8}-{copyNumber}
  ///
  /// Parameters:
  /// - [bookId]: The book's ID
  /// - [copyNumber]: The copy number (1-indexed)
  String _generateBarcode(String bookId, int copyNumber) {
    final String shortId = bookId.substring(0, 8).toUpperCase();
    final String paddedCopy = copyNumber.toString().padLeft(3, '0');
    return 'BOOK-$shortId-$paddedCopy';
  }

  /// Returns a stream of all books for real-time updates.
  ///
  /// Useful for listening to changes in the books collection.
  Stream<List<Book>> getBooksStream() {
    return _firestore
        .collection('books')
        .orderBy('title')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map((doc) => Book.fromDoc(doc)).toList(),
        );
  }
}
