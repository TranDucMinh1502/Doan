import 'package:flutter/foundation.dart';
import '../models/book_model.dart';
import '../services/book_service.dart';

/// Provider for managing book state and operations.
///
/// Uses [ChangeNotifier] to notify listeners when book data changes.
/// Integrates [BookService] for all book-related operations with Firestore.
class BookProvider extends ChangeNotifier {
  final BookService _bookService = BookService();

  /// List of all books in the library.
  List<Book> _books = [];

  /// Indicates whether a book operation is in progress.
  bool _isLoading = false;

  /// Error message from the last operation (null if successful).
  String? _errorMessage;

  /// Gets the list of books.
  List<Book> get books => _books;

  /// Gets the loading state.
  bool get isLoading => _isLoading;

  /// Gets the error message from the last operation.
  String? get errorMessage => _errorMessage;

  /// Checks if there are any books available.
  bool get hasBooks => _books.isNotEmpty;

  /// Gets the total number of books.
  int get bookCount => _books.length;

  /// Loads all books from Firestore.
  ///
  /// Sets [isLoading] to true during the operation and populates
  /// the [books] list with all available books.
  ///
  /// Example:
  /// ```dart
  /// await bookProvider.loadBooks();
  /// print('Loaded ${bookProvider.bookCount} books');
  /// ```
  Future<void> loadBooks() async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      _books = await _bookService.fetchAllBooks();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Searches for books by query string.
  ///
  /// Searches in book title, authors, and ISBN. Updates the [books] list
  /// with search results.
  ///
  /// Parameters:
  /// - [query]: Search query string. If empty, loads all books.
  /// - [category]: Optional category filter
  /// - [limit]: Maximum number of results (default: 20)
  ///
  /// Example:
  /// ```dart
  /// await bookProvider.searchBooks('Harry Potter');
  /// // or with category
  /// await bookProvider.searchBooks('mystery', category: 'Fiction');
  /// ```
  Future<void> searchBooks(
    String query, {
    String? category,
    int limit = 20,
  }) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      if (query.trim().isEmpty && category == null) {
        // If no query or category, load all books
        _books = await _bookService.fetchAllBooks();
      } else {
        // Search with provided criteria
        _books = await _bookService.searchBooks(
          query: query,
          category: category,
          limit: limit,
        );
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Adds a new book to the library.
  ///
  /// Creates a new book record and the specified number of physical copies.
  /// Updates the [books] list after successful addition.
  ///
  /// Parameters:
  /// - [book]: The book to add
  /// - [numberOfCopies]: Number of physical copies to create (default: 1)
  ///
  /// Example:
  /// ```dart
  /// final newBook = Book(
  ///   id: '',
  ///   title: 'The Great Gatsby',
  ///   isbn: '9780743273565',
  ///   authors: ['F. Scott Fitzgerald'],
  ///   categories: ['Fiction'],
  ///   publishedAt: Timestamp.now(),
  ///   coverUrl: '',
  ///   totalCopies: 0,
  ///   availableCopies: 0,
  /// );
  /// await bookProvider.addBook(newBook, numberOfCopies: 5);
  /// ```
  Future<void> addBook(Book book, {int numberOfCopies = 1}) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      await _bookService.addBook(book, numberOfCopies);

      // Reload books to include the new book with its generated ID
      await loadBooks();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Updates an existing book's information.
  ///
  /// Updates the book in Firestore and refreshes the [books] list.
  ///
  /// Parameters:
  /// - [book]: The book with updated information
  ///
  /// Example:
  /// ```dart
  /// final updatedBook = book.copyWith(title: 'New Title');
  /// await bookProvider.updateBook(updatedBook);
  /// ```
  Future<void> updateBook(Book book) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      await _bookService.updateBook(book);

      // Update the book in the local list
      final index = _books.indexWhere((b) => b.id == book.id);
      if (index != -1) {
        _books[index] = book;
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Deletes a book and all its physical copies.
  ///
  /// Removes the book from Firestore and updates the [books] list.
  /// Throws an error if the book has active loans.
  ///
  /// Parameters:
  /// - [bookId]: The ID of the book to delete
  ///
  /// Example:
  /// ```dart
  /// try {
  ///   await bookProvider.deleteBook('book123');
  ///   // Show success message
  /// } catch (e) {
  ///   // Show error (e.g., book has active loans)
  /// }
  /// ```
  Future<void> deleteBook(String bookId) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      await _bookService.deleteBook(bookId);

      // Remove the book from the local list
      _books.removeWhere((book) => book.id == bookId);

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Gets a specific book by ID from the loaded books list.
  ///
  /// Returns null if the book is not found in the current list.
  ///
  /// Example:
  /// ```dart
  /// final book = bookProvider.getBookById('book123');
  /// ```
  Book? getBookById(String bookId) {
    try {
      return _books.firstWhere((book) => book.id == bookId);
    } catch (e) {
      return null;
    }
  }

  /// Fetches a specific book by ID from Firestore.
  ///
  /// This bypasses the local cache and fetches directly from the database.
  /// Useful when you need the most up-to-date information.
  ///
  /// Example:
  /// ```dart
  /// final book = await bookProvider.fetchBookById('book123');
  /// ```
  Future<Book?> fetchBookById(String bookId) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final book = await _bookService.getBookById(bookId);

      _isLoading = false;
      notifyListeners();

      return book;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Filters books by category from the loaded list.
  ///
  /// This performs in-memory filtering and doesn't query Firestore.
  ///
  /// Example:
  /// ```dart
  /// final fictionBooks = bookProvider.filterByCategory('Fiction');
  /// ```
  List<Book> filterByCategory(String category) {
    return _books.where((book) => book.categories.contains(category)).toList();
  }

  /// Gets all unique categories from the loaded books.
  ///
  /// Useful for building category filter UI.
  ///
  /// Example:
  /// ```dart
  /// final categories = bookProvider.getAllCategories();
  /// ```
  List<String> getAllCategories() {
    final Set<String> categories = {};
    for (final book in _books) {
      categories.addAll(book.categories);
    }
    return categories.toList()..sort();
  }

  /// Clears the current search/filter and reloads all books.
  ///
  /// Example:
  /// ```dart
  /// await bookProvider.clearSearch();
  /// ```
  Future<void> clearSearch() async {
    await loadBooks();
  }

  /// Clears any error messages.
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Refreshes the book list from Firestore.
  ///
  /// Alias for [loadBooks] but more semantically clear when used
  /// for refresh actions.
  ///
  /// Example:
  /// ```dart
  /// await bookProvider.refresh();
  /// ```
  Future<void> refresh() async {
    await loadBooks();
  }
}
