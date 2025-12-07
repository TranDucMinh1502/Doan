import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/book_model.dart';
import '../models/book_item_model.dart';
import '../models/loan_model.dart';
import '../models/reservation_model.dart';
import '../core/constants.dart';

/// Root CRUD service for all Firestore operations.
///
/// Provides centralized access to all database operations including users,
/// books, book items, loans, and reservations. Uses transactions where
/// necessary to ensure data consistency.
class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Collection references
  CollectionReference<Map<String, dynamic>> get _usersCollection =>
      _firestore.collection(FirestoreCollections.users);

  CollectionReference<Map<String, dynamic>> get _booksCollection =>
      _firestore.collection(FirestoreCollections.books);

  CollectionReference<Map<String, dynamic>> get _bookItemsCollection =>
      _firestore.collection(FirestoreCollections.bookItems);

  CollectionReference<Map<String, dynamic>> get _loansCollection =>
      _firestore.collection(FirestoreCollections.loans);

  CollectionReference<Map<String, dynamic>> get _reservationsCollection =>
      _firestore.collection(FirestoreCollections.reservations);

  // ============================================================================
  // USER OPERATIONS
  // ============================================================================

  /// Creates a new user in Firestore.
  ///
  /// Throws [FirebaseException] if the operation fails.
  /// Throws [Exception] with readable error message for common issues.
  ///
  /// Example:
  /// ```dart
  /// await firestoreService.createUser(newUser);
  /// ```
  Future<void> createUser(AppUser user) async {
    try {
      await _usersCollection.doc(user.uid).set(user.toJson());
    } on FirebaseException catch (e) {
      throw Exception('Failed to create user: ${e.message}');
    } catch (e) {
      throw Exception('An unexpected error occurred while creating user: $e');
    }
  }

  /// Retrieves a user by their UID.
  ///
  /// Returns the [AppUser] if found, null otherwise.
  /// Throws [Exception] with readable error message if operation fails.
  ///
  /// Example:
  /// ```dart
  /// final user = await firestoreService.getUser('user123');
  /// ```
  Future<AppUser?> getUser(String uid) async {
    try {
      final doc = await _usersCollection.doc(uid).get();
      if (!doc.exists) {
        return null;
      }
      return AppUser.fromDoc(doc);
    } on FirebaseException catch (e) {
      throw Exception('Failed to retrieve user: ${e.message}');
    } catch (e) {
      throw Exception('An unexpected error occurred while retrieving user: $e');
    }
  }

  /// Updates an existing user in Firestore.
  ///
  /// Throws [Exception] if the user doesn't exist or operation fails.
  ///
  /// Example:
  /// ```dart
  /// await firestoreService.updateUser(updatedUser);
  /// ```
  Future<void> updateUser(AppUser user) async {
    try {
      final doc = await _usersCollection.doc(user.uid).get();
      if (!doc.exists) {
        throw Exception('User with UID ${user.uid} does not exist');
      }
      await _usersCollection.doc(user.uid).update(user.toJson());
    } on FirebaseException catch (e) {
      throw Exception('Failed to update user: ${e.message}');
    } catch (e) {
      throw Exception('An unexpected error occurred while updating user: $e');
    }
  }

  // ============================================================================
  // BOOK OPERATIONS
  // ============================================================================

  /// Adds a new book to the library with optional initial copies.
  ///
  /// If [copies] is provided, creates that many book items automatically.
  /// Uses a batch operation to ensure all items are created atomically.
  ///
  /// Throws [Exception] if book ID already exists or operation fails.
  ///
  /// Example:
  /// ```dart
  /// await firestoreService.addBook(newBook, copies: 5);
  /// ```
  Future<void> addBook(Book book, {int copies = 0}) async {
    try {
      // Check if book already exists
      final doc = await _booksCollection.doc(book.id).get();
      if (doc.exists) {
        throw Exception('Book with ID ${book.id} already exists');
      }

      if (copies < 0) {
        throw Exception('Number of copies cannot be negative');
      }

      // Use batch to create book and items atomically
      final batch = _firestore.batch();

      // Add the book
      batch.set(_booksCollection.doc(book.id), book.toJson());

      // Create book items if copies specified
      if (copies > 0) {
        for (int i = 0; i < copies; i++) {
          final itemRef = _bookItemsCollection.doc();
          final bookItem = BookItem(
            id: itemRef.id,
            bookId: book.id,
            barcode: '${book.isbn}-${i + 1}',
            location: 'Pending Assignment',
            status: 'available',
            condition: 'good',
            createdAt: Timestamp.now(),
          );
          batch.set(itemRef, bookItem.toJson());
        }
      }

      await batch.commit();
    } on FirebaseException catch (e) {
      throw Exception('Failed to add book: ${e.message}');
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('An unexpected error occurred while adding book: $e');
    }
  }

  /// Updates an existing book in Firestore.
  ///
  /// Note: This does not update associated book items.
  /// Use separate methods to manage book items.
  ///
  /// Throws [Exception] if the book doesn't exist or operation fails.
  ///
  /// Example:
  /// ```dart
  /// await firestoreService.updateBook(updatedBook);
  /// ```
  Future<void> updateBook(Book book) async {
    try {
      final doc = await _booksCollection.doc(book.id).get();
      if (!doc.exists) {
        throw Exception('Book with ID ${book.id} does not exist');
      }
      await _booksCollection.doc(book.id).update(book.toJson());
    } on FirebaseException catch (e) {
      throw Exception('Failed to update book: ${e.message}');
    } catch (e) {
      throw Exception('An unexpected error occurred while updating book: $e');
    }
  }

  /// Deletes a book from the library.
  ///
  /// WARNING: This permanently deletes the book and all associated data.
  /// Consider using transactions to ensure related data is cleaned up.
  ///
  /// Throws [Exception] if the book doesn't exist or operation fails.
  ///
  /// Example:
  /// ```dart
  /// await firestoreService.deleteBook('book123');
  /// ```
  Future<void> deleteBook(String bookId) async {
    try {
      final doc = await _booksCollection.doc(bookId).get();
      if (!doc.exists) {
        throw Exception('Book with ID $bookId does not exist');
      }

      // Check if there are active loans for this book
      final activeLoans = await _loansCollection
          .where('bookId', isEqualTo: bookId)
          .where('status', isEqualTo: 'borrowed')
          .limit(1)
          .get();

      if (activeLoans.docs.isNotEmpty) {
        throw Exception(
          'Cannot delete book with active loans. Please ensure all copies are returned first.',
        );
      }

      // Delete the book
      await _booksCollection.doc(bookId).delete();
    } on FirebaseException catch (e) {
      throw Exception('Failed to delete book: ${e.message}');
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('An unexpected error occurred while deleting book: $e');
    }
  }

  /// Fetches all books from the library.
  ///
  /// Returns a list of [Book] objects.
  /// Throws [Exception] with readable error message if operation fails.
  ///
  /// Example:
  /// ```dart
  /// final books = await firestoreService.fetchBooks();
  /// ```
  Future<List<Book>> fetchBooks() async {
    try {
      final snapshot = await _booksCollection.get();
      return snapshot.docs.map((doc) => Book.fromDoc(doc)).toList();
    } on FirebaseException catch (e) {
      throw Exception('Failed to fetch books: ${e.message}');
    } catch (e) {
      throw Exception('An unexpected error occurred while fetching books: $e');
    }
  }

  // ============================================================================
  // BOOK ITEM OPERATIONS
  // ============================================================================

  /// Adds a new book item (physical copy) to a book.
  ///
  /// Validates that the parent book exists before creating the item.
  /// Automatically updates the book's totalCopies and availableCopies counts.
  ///
  /// Throws [Exception] if parent book doesn't exist or operation fails.
  ///
  /// Example:
  /// ```dart
  /// await firestoreService.addBookItem('book123', newBookItem);
  /// ```
  Future<void> addBookItem(String bookId, BookItem bookItem) async {
    try {
      // Validate parent book exists
      final bookDoc = await _booksCollection.doc(bookId).get();
      if (!bookDoc.exists) {
        throw Exception('Parent book with ID $bookId does not exist');
      }

      // Use transaction to ensure atomic update of book and creation of item
      await _firestore.runTransaction((transaction) async {
        final bookRef = _booksCollection.doc(bookId);
        final bookSnapshot = await transaction.get(bookRef);

        if (!bookSnapshot.exists) {
          throw Exception('Book not found during transaction');
        }

        final bookData = bookSnapshot.data()!;
        final totalCopies = (bookData['totalCopies'] as num).toInt();
        final availableCopies = (bookData['availableCopies'] as num).toInt();

        // Add the book item
        final itemRef = _bookItemsCollection.doc(bookItem.id);
        transaction.set(itemRef, bookItem.toJson());

        // Update book counts
        transaction.update(bookRef, {
          'totalCopies': totalCopies + 1,
          'availableCopies': bookItem.status == 'available'
              ? availableCopies + 1
              : availableCopies,
        });
      });
    } on FirebaseException catch (e) {
      throw Exception('Failed to add book item: ${e.message}');
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception(
        'An unexpected error occurred while adding book item: $e',
      );
    }
  }

  /// Retrieves all available book items for a specific book.
  ///
  /// Returns a list of [BookItem] objects with status 'available'.
  /// Throws [Exception] with readable error message if operation fails.
  ///
  /// Example:
  /// ```dart
  /// final availableItems = await firestoreService.getAvailableBookItems('book123');
  /// ```
  Future<List<BookItem>> getAvailableBookItems(String bookId) async {
    try {
      final snapshot = await _bookItemsCollection
          .where('bookId', isEqualTo: bookId)
          .where('status', isEqualTo: 'available')
          .get();

      return snapshot.docs.map((doc) => BookItem.fromDoc(doc)).toList();
    } on FirebaseException catch (e) {
      throw Exception('Failed to fetch available book items: ${e.message}');
    } catch (e) {
      throw Exception(
        'An unexpected error occurred while fetching available book items: $e',
      );
    }
  }

  // ============================================================================
  // LOAN OPERATIONS (Transaction-Safe)
  // ============================================================================

  /// Issues a book to a user (creates a loan).
  ///
  /// This is a transaction-safe operation that:
  /// 1. Validates user exists and hasn't exceeded borrow limit
  /// 2. Validates book item is available
  /// 3. Creates the loan record
  /// 4. Updates book item status to 'borrowed'
  /// 5. Updates book's available copies count
  /// 6. Increments user's borrowed count
  ///
  /// Throws [Exception] with readable error messages for validation failures.
  ///
  /// Example:
  /// ```dart
  /// await firestoreService.issueBook('user123', 'item456', 'book789');
  /// ```
  Future<String> issueBook(String userId, String itemId, String bookId) async {
    try {
      String loanId = '';

      await _firestore.runTransaction((transaction) async {
        // Get user
        final userRef = _usersCollection.doc(userId);
        final userSnapshot = await transaction.get(userRef);
        if (!userSnapshot.exists) {
          throw Exception('User not found');
        }
        final userData = userSnapshot.data()!;
        final borrowedCount = (userData['borrowedCount'] as num).toInt();
        final maxBorrow = (userData['maxBorrow'] as num).toInt();

        // Check borrow limit
        if (borrowedCount >= maxBorrow) {
          throw Exception(
            'User has reached maximum borrow limit of $maxBorrow books',
          );
        }

        // Get book item
        final itemRef = _bookItemsCollection.doc(itemId);
        final itemSnapshot = await transaction.get(itemRef);
        if (!itemSnapshot.exists) {
          throw Exception('Book item not found');
        }
        final itemData = itemSnapshot.data()!;
        if (itemData['status'] != 'available') {
          throw Exception('Book item is not available for borrowing');
        }

        // Get book
        final bookRef = _booksCollection.doc(bookId);
        final bookSnapshot = await transaction.get(bookRef);
        if (!bookSnapshot.exists) {
          throw Exception('Book not found');
        }
        final bookData = bookSnapshot.data()!;
        final availableCopies = (bookData['availableCopies'] as num).toInt();

        if (availableCopies <= 0) {
          throw Exception('No available copies of this book');
        }

        // Create loan
        final loanRef = _loansCollection.doc();
        loanId = loanRef.id;
        final now = Timestamp.now();
        final dueDate = Timestamp.fromDate(
          DateTime.now().add(const Duration(days: 14)), // Default 14 days
        );

        final loan = Loan(
          id: loanId,
          userId: userId,
          itemId: itemId,
          bookId: bookId,
          issueDate: now,
          dueDate: dueDate,
          returnDate: null,
          status: 'borrowed',
          fine: 0.0,
          renewCount: 0,
        );

        transaction.set(loanRef, loan.toJson());

        // Update book item status
        transaction.update(itemRef, {'status': 'borrowed'});

        // Update book available copies
        transaction.update(bookRef, {'availableCopies': availableCopies - 1});

        // Update user borrowed count
        transaction.update(userRef, {'borrowedCount': borrowedCount + 1});
      });

      return loanId;
    } on FirebaseException catch (e) {
      throw Exception('Failed to issue book: ${e.message}');
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('An unexpected error occurred while issuing book: $e');
    }
  }

  /// Returns a borrowed book (completes a loan).
  ///
  /// This is a transaction-safe operation that:
  /// 1. Validates loan exists and is in 'borrowed' status
  /// 2. Updates loan status to 'returned' and sets return date
  /// 3. Updates book item status to 'available'
  /// 4. Increments book's available copies count
  /// 5. Decrements user's borrowed count
  ///
  /// Throws [Exception] with readable error messages for validation failures.
  ///
  /// Example:
  /// ```dart
  /// await firestoreService.returnBook('loan123');
  /// ```
  Future<void> returnBook(String loanId) async {
    try {
      await _firestore.runTransaction((transaction) async {
        // Get loan
        final loanRef = _loansCollection.doc(loanId);
        final loanSnapshot = await transaction.get(loanRef);
        if (!loanSnapshot.exists) {
          throw Exception('Loan not found');
        }
        final loanData = loanSnapshot.data()!;

        if (loanData['status'] == 'returned') {
          throw Exception('This book has already been returned');
        }

        if (loanData['status'] != 'borrowed' &&
            loanData['status'] != 'overdue') {
          throw Exception('Invalid loan status for return operation');
        }

        final userId = loanData['userId'] as String;
        final itemId = loanData['itemId'] as String;
        final bookId = loanData['bookId'] as String;

        // Get user
        final userRef = _usersCollection.doc(userId);
        final userSnapshot = await transaction.get(userRef);
        if (!userSnapshot.exists) {
          throw Exception('User not found');
        }
        final userData = userSnapshot.data()!;
        final borrowedCount = (userData['borrowedCount'] as num).toInt();

        // Get book item
        final itemRef = _bookItemsCollection.doc(itemId);
        final itemSnapshot = await transaction.get(itemRef);
        if (!itemSnapshot.exists) {
          throw Exception('Book item not found');
        }

        // Get book
        final bookRef = _booksCollection.doc(bookId);
        final bookSnapshot = await transaction.get(bookRef);
        if (!bookSnapshot.exists) {
          throw Exception('Book not found');
        }
        final bookData = bookSnapshot.data()!;
        final availableCopies = (bookData['availableCopies'] as num).toInt();

        // Update loan
        transaction.update(loanRef, {
          'status': 'returned',
          'returnDate': Timestamp.now(),
        });

        // Update book item status
        transaction.update(itemRef, {'status': 'available'});

        // Update book available copies
        transaction.update(bookRef, {'availableCopies': availableCopies + 1});

        // Update user borrowed count
        transaction.update(userRef, {
          'borrowedCount': borrowedCount > 0 ? borrowedCount - 1 : 0,
        });
      });
    } on FirebaseException catch (e) {
      throw Exception('Failed to return book: ${e.message}');
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('An unexpected error occurred while returning book: $e');
    }
  }

  // ============================================================================
  // RESERVATION OPERATIONS
  // ============================================================================

  /// Creates a reservation for a book.
  ///
  /// Validates that:
  /// - User exists
  /// - Book exists
  /// - User doesn't already have an active reservation for this book
  ///
  /// Throws [Exception] with readable error messages for validation failures.
  ///
  /// Example:
  /// ```dart
  /// await firestoreService.reserveBook('user123', 'book456');
  /// ```
  Future<String> reserveBook(String userId, String bookId) async {
    try {
      // Validate user exists
      final userDoc = await _usersCollection.doc(userId).get();
      if (!userDoc.exists) {
        throw Exception('User not found');
      }

      // Validate book exists
      final bookDoc = await _booksCollection.doc(bookId).get();
      if (!bookDoc.exists) {
        throw Exception('Book not found');
      }

      // Check for existing active reservation
      final existingReservations = await _reservationsCollection
          .where('userId', isEqualTo: userId)
          .where('bookId', isEqualTo: bookId)
          .where('status', isEqualTo: 'waiting')
          .limit(1)
          .get();

      if (existingReservations.docs.isNotEmpty) {
        throw Exception('User already has an active reservation for this book');
      }

      // Create reservation
      final reservationRef = _reservationsCollection.doc();
      final reservation = Reservation(
        id: reservationRef.id,
        userId: userId,
        bookId: bookId,
        itemId: null,
        reservedAt: Timestamp.now(),
        status: 'waiting',
      );

      await reservationRef.set(reservation.toJson());
      return reservationRef.id;
    } on FirebaseException catch (e) {
      throw Exception('Failed to create reservation: ${e.message}');
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception(
        'An unexpected error occurred while creating reservation: $e',
      );
    }
  }

  /// Retrieves and removes the next reservation in the queue for a book.
  ///
  /// Returns the oldest 'waiting' reservation for the specified book.
  /// Updates the reservation status to 'notified'.
  ///
  /// Returns null if no waiting reservations exist.
  /// Throws [Exception] with readable error message if operation fails.
  ///
  /// Example:
  /// ```dart
  /// final reservation = await firestoreService.popNextReservation('book123');
  /// ```
  Future<Reservation?> popNextReservation(String bookId) async {
    try {
      // Get oldest waiting reservation
      final snapshot = await _reservationsCollection
          .where('bookId', isEqualTo: bookId)
          .where('status', isEqualTo: 'waiting')
          .orderBy('reservedAt', descending: false)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        return null;
      }

      final reservationDoc = snapshot.docs.first;
      final reservation = Reservation.fromDoc(reservationDoc);

      // Update reservation status to notified
      await _reservationsCollection.doc(reservation.id).update({
        'status': 'notified',
      });

      return reservation;
    } on FirebaseException catch (e) {
      throw Exception('Failed to pop next reservation: ${e.message}');
    } catch (e) {
      throw Exception(
        'An unexpected error occurred while popping next reservation: $e',
      );
    }
  }

  // ============================================================================
  // UTILITY METHODS
  // ============================================================================

  /// Gets a real-time stream of books.
  ///
  /// Useful for UI that needs to update automatically when books change.
  ///
  /// Example:
  /// ```dart
  /// firestoreService.getBooksStream().listen((books) {
  ///   // Update UI
  /// });
  /// ```
  Stream<List<Book>> getBooksStream() {
    return _booksCollection.snapshots().map(
      (snapshot) => snapshot.docs.map((doc) => Book.fromDoc(doc)).toList(),
    );
  }

  /// Gets a real-time stream of loans for a specific user.
  ///
  /// Example:
  /// ```dart
  /// firestoreService.getUserLoansStream('user123').listen((loans) {
  ///   // Update UI
  /// });
  /// ```
  Stream<List<Loan>> getUserLoansStream(String userId) {
    return _loansCollection
        .where('userId', isEqualTo: userId)
        .orderBy('issueDate', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map((doc) => Loan.fromDoc(doc)).toList(),
        );
  }

  /// Gets a real-time stream of reservations for a specific user.
  ///
  /// Example:
  /// ```dart
  /// firestoreService.getUserReservationsStream('user123').listen((reservations) {
  ///   // Update UI
  /// });
  /// ```
  Stream<List<Reservation>> getUserReservationsStream(String userId) {
    return _reservationsCollection
        .where('userId', isEqualTo: userId)
        .orderBy('reservedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => Reservation.fromDoc(doc)).toList(),
        );
  }
}
