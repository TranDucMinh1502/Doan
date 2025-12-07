import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/loan_model.dart';

/// Service class for handling loan-related operations with Firestore.
///
/// This service manages the borrowing and returning of books, ensuring
/// data consistency across loans, book items, and book collections.
class LoanService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Default number of days for a loan period
  static const int defaultBorrowDays = 15;

  /// Issues a book to a user.
  ///
  /// Creates a loan transaction and updates related collections atomically:
  /// - Creates a new loan document with status "borrowed"
  /// - Updates the book item status to "borrowed"
  /// - Decrements the book's availableCopies count
  /// - Increments the user's borrowedCount
  ///
  /// All operations are performed in a single transaction for data consistency.
  ///
  /// Parameters:
  /// - [userId]: The ID of the user borrowing the book
  /// - [itemId]: The ID of the specific book item being borrowed
  /// - [bookId]: The ID of the book
  ///
  /// Throws:
  /// - [FirebaseException] for Firestore errors
  /// - [Exception] for validation errors or business logic violations
  ///
  /// Example:
  /// ```dart
  /// try {
  ///   await loanService.issueBook(
  ///     userId: 'user123',
  ///     itemId: 'item456',
  ///     bookId: 'book789',
  ///   );
  ///   print('Book issued successfully');
  /// } catch (e) {
  ///   print('Error: $e');
  /// }
  /// ```
  Future<void> issueBook({
    required String userId,
    required String itemId,
    required String bookId,
  }) async {
    try {
      // Validate input parameters
      if (userId.isEmpty || itemId.isEmpty || bookId.isEmpty) {
        throw Exception('User ID, Item ID, and Book ID cannot be empty.');
      }

      await _firestore.runTransaction((transaction) async {
        // Get references
        final userRef = _firestore.collection('users').doc(userId);
        final itemRef = _firestore.collection('bookItems').doc(itemId);
        final bookRef = _firestore.collection('books').doc(bookId);

        // Read all documents
        final userDoc = await transaction.get(userRef);
        final itemDoc = await transaction.get(itemRef);
        final bookDoc = await transaction.get(bookRef);

        // Validate documents exist
        if (!userDoc.exists) {
          throw Exception('User not found.');
        }
        if (!itemDoc.exists) {
          throw Exception('Book item not found.');
        }
        if (!bookDoc.exists) {
          throw Exception('Book not found.');
        }

        // Extract data
        final userData = userDoc.data() as Map<String, dynamic>;
        final itemData = itemDoc.data() as Map<String, dynamic>;
        final bookData = bookDoc.data() as Map<String, dynamic>;

        // Validate book item status
        final itemStatus = itemData['status'] as String? ?? '';
        if (itemStatus != 'available') {
          throw Exception(
            'Book item is not available. Current status: $itemStatus',
          );
        }

        // Validate book item belongs to the correct book
        final itemBookId = itemData['bookId'] as String? ?? '';
        if (itemBookId != bookId) {
          throw Exception('Book item does not belong to the specified book.');
        }

        // Check user's borrow limit
        final maxBorrow = userData['maxBorrow'] as int? ?? 3;
        final borrowedCount = userData['borrowedCount'] as int? ?? 0;
        if (borrowedCount >= maxBorrow) {
          throw Exception(
            'User has reached maximum borrow limit ($maxBorrow books).',
          );
        }

        // Check available copies
        final availableCopies = bookData['availableCopies'] as int? ?? 0;
        if (availableCopies <= 0) {
          throw Exception('No available copies of this book.');
        }

        // Calculate dates
        final now = Timestamp.now();
        final dueDate = Timestamp.fromDate(
          DateTime.now().add(Duration(days: defaultBorrowDays)),
        );

        // Create loan document
        final loanRef = _firestore.collection('loans').doc();
        final Loan loan = Loan(
          id: loanRef.id,
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

        // Write operations
        transaction.set(loanRef, loan.toJson());

        // Update book item status
        transaction.update(itemRef, {'status': 'borrowed'});

        // Decrement available copies
        transaction.update(bookRef, {
          'availableCopies': FieldValue.increment(-1),
        });

        // Increment user's borrowed count
        transaction.update(userRef, {'borrowedCount': FieldValue.increment(1)});
      });
    } on FirebaseException catch (e) {
      throw Exception('Database error while issuing book: ${e.message}');
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }
      throw Exception('An unexpected error occurred: $e');
    }
  }

  /// Returns a borrowed book.
  ///
  /// Updates the loan record and related collections atomically:
  /// - Updates loan status to "returned" and sets returnDate
  /// - Updates book item status to "available"
  /// - Increments the book's availableCopies count
  /// - Decrements the user's borrowedCount
  ///
  /// All operations are performed in a single transaction for data consistency.
  ///
  /// Parameters:
  /// - [loanId]: The ID of the loan to return
  ///
  /// Throws:
  /// - [FirebaseException] for Firestore errors
  /// - [Exception] for validation errors or business logic violations
  ///
  /// Example:
  /// ```dart
  /// try {
  ///   await loanService.returnBook('loan123');
  ///   print('Book returned successfully');
  /// } catch (e) {
  ///   print('Error: $e');
  /// }
  /// ```
  Future<void> returnBook(String loanId) async {
    try {
      // Validate input
      if (loanId.isEmpty) {
        throw Exception('Loan ID cannot be empty.');
      }

      await _firestore.runTransaction((transaction) async {
        // Get loan reference and document
        final loanRef = _firestore.collection('loans').doc(loanId);
        final loanDoc = await transaction.get(loanRef);

        // Validate loan exists
        if (!loanDoc.exists) {
          throw Exception('Loan not found.');
        }

        // Extract loan data
        final loanData = loanDoc.data() as Map<String, dynamic>;
        final loanStatus = loanData['status'] as String? ?? '';

        // Validate loan status
        if (loanStatus == 'returned') {
          throw Exception('This book has already been returned.');
        }
        if (loanStatus != 'borrowed' && loanStatus != 'overdue') {
          throw Exception('Invalid loan status: $loanStatus');
        }

        // Get related IDs
        final userId = loanData['userId'] as String? ?? '';
        final itemId = loanData['itemId'] as String? ?? '';
        final bookId = loanData['bookId'] as String? ?? '';

        if (userId.isEmpty || itemId.isEmpty || bookId.isEmpty) {
          throw Exception('Invalid loan data: missing user, item, or book ID.');
        }

        // Get references
        final userRef = _firestore.collection('users').doc(userId);
        final itemRef = _firestore.collection('bookItems').doc(itemId);
        final bookRef = _firestore.collection('books').doc(bookId);

        // Read documents for validation
        final itemDoc = await transaction.get(itemRef);
        final bookDoc = await transaction.get(bookRef);
        final userDoc = await transaction.get(userRef);

        if (!itemDoc.exists) {
          throw Exception('Book item not found.');
        }
        if (!bookDoc.exists) {
          throw Exception('Book not found.');
        }
        if (!userDoc.exists) {
          throw Exception('User not found.');
        }

        // Calculate fine if overdue
        final dueDate = loanData['dueDate'] as Timestamp?;
        final now = Timestamp.now();
        double fine = loanData['fine'] as double? ?? 0.0;

        if (dueDate != null && now.toDate().isAfter(dueDate.toDate())) {
          // Calculate overdue fine (e.g., $1 per day)
          final overdueDays = now.toDate().difference(dueDate.toDate()).inDays;
          fine += overdueDays * 1.0; // $1 per day
        }

        // Write operations

        // Update loan document
        transaction.update(loanRef, {
          'status': 'returned',
          'returnDate': now,
          'fine': fine,
        });

        // Update book item status
        transaction.update(itemRef, {'status': 'available'});

        // Increment available copies
        transaction.update(bookRef, {
          'availableCopies': FieldValue.increment(1),
        });

        // Decrement user's borrowed count
        transaction.update(userRef, {
          'borrowedCount': FieldValue.increment(-1),
        });
      });
    } on FirebaseException catch (e) {
      throw Exception('Database error while returning book: ${e.message}');
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }
      throw Exception('An unexpected error occurred: $e');
    }
  }

  /// Gets all active loans for a specific user.
  ///
  /// Parameters:
  /// - [userId]: The ID of the user
  ///
  /// Returns a list of active [Loan] objects.
  Future<List<Loan>> getUserActiveLoans(String userId) async {
    try {
      if (userId.isEmpty) {
        throw Exception('User ID cannot be empty.');
      }

      // Fetch all user loans without orderBy to avoid index requirement
      final QuerySnapshot snapshot = await _firestore
          .collection('loans')
          .where('userId', isEqualTo: userId)
          .get();

      // Filter for active loans and sort in memory
      final loans = snapshot.docs
          .map((doc) => Loan.fromDoc(doc))
          .where(
            (loan) => loan.status == 'borrowed' || loan.status == 'overdue',
          )
          .toList();

      // Sort by issue date descending (newest first)
      loans.sort((a, b) => b.issueDate.compareTo(a.issueDate));

      return loans;
    } on FirebaseException catch (e) {
      throw Exception('Database error while fetching user loans: ${e.message}');
    } catch (e) {
      throw Exception('An unexpected error occurred: $e');
    }
  }

  /// Gets loan history for a specific user.
  ///
  /// Parameters:
  /// - [userId]: The ID of the user
  ///
  /// Returns a list of all [Loan] objects for the user.
  Future<List<Loan>> getUserLoanHistory(String userId) async {
    try {
      if (userId.isEmpty) {
        throw Exception('User ID cannot be empty.');
      }

      final QuerySnapshot snapshot = await _firestore
          .collection('loans')
          .where('userId', isEqualTo: userId)
          .orderBy('issueDate', descending: true)
          .get();

      return snapshot.docs.map((doc) => Loan.fromDoc(doc)).toList();
    } on FirebaseException catch (e) {
      throw Exception(
        'Database error while fetching loan history: ${e.message}',
      );
    } catch (e) {
      throw Exception('An unexpected error occurred: $e');
    }
  }

  /// Gets all overdue loans in the system.
  ///
  /// Updates loan status to "overdue" if past due date.
  ///
  /// Returns a list of overdue [Loan] objects.
  Future<List<Loan>> getOverdueLoans() async {
    try {
      final now = Timestamp.now();

      final QuerySnapshot snapshot = await _firestore
          .collection('loans')
          .where('status', isEqualTo: 'borrowed')
          .where('dueDate', isLessThan: now)
          .get();

      // Update status to overdue
      final WriteBatch batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.update(doc.reference, {'status': 'overdue'});
      }
      await batch.commit();

      return snapshot.docs.map((doc) => Loan.fromDoc(doc)).toList();
    } on FirebaseException catch (e) {
      throw Exception(
        'Database error while fetching overdue loans: ${e.message}',
      );
    } catch (e) {
      throw Exception('An unexpected error occurred: $e');
    }
  }

  /// Renews a loan, extending its due date.
  ///
  /// Parameters:
  /// - [loanId]: The ID of the loan to renew
  /// - [additionalDays]: Number of days to extend (default: 15)
  ///
  /// Throws if loan cannot be renewed (e.g., already returned, max renewals reached).
  Future<void> renewLoan(String loanId, {int additionalDays = 15}) async {
    try {
      if (loanId.isEmpty) {
        throw Exception('Loan ID cannot be empty.');
      }

      final loanRef = _firestore.collection('loans').doc(loanId);
      final loanDoc = await loanRef.get();

      if (!loanDoc.exists) {
        throw Exception('Loan not found.');
      }

      final loanData = loanDoc.data() as Map<String, dynamic>;
      final status = loanData['status'] as String? ?? '';
      final renewCount = loanData['renewCount'] as int? ?? 0;

      // Validate renewal eligibility
      if (status != 'borrowed') {
        throw Exception('Only active loans can be renewed.');
      }

      if (renewCount >= 2) {
        throw Exception('Maximum renewal limit (2) reached.');
      }

      // Calculate new due date
      final currentDueDate = loanData['dueDate'] as Timestamp?;
      if (currentDueDate == null) {
        throw Exception('Invalid loan data: missing due date.');
      }

      final newDueDate = Timestamp.fromDate(
        currentDueDate.toDate().add(Duration(days: additionalDays)),
      );

      // Update loan
      await loanRef.update({
        'dueDate': newDueDate,
        'renewCount': renewCount + 1,
      });
    } on FirebaseException catch (e) {
      throw Exception('Database error while renewing loan: ${e.message}');
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }
      throw Exception('An unexpected error occurred: $e');
    }
  }

  /// Returns a stream of active loans for a user for real-time updates.
  ///
  /// Parameters:
  /// - [userId]: The ID of the user
  Stream<List<Loan>> getUserActiveLoansStream(String userId) {
    return _firestore
        .collection('loans')
        .where('userId', isEqualTo: userId)
        .where('status', whereIn: ['borrowed', 'overdue'])
        .orderBy('issueDate', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map((doc) => Loan.fromDoc(doc)).toList(),
        );
  }
}
