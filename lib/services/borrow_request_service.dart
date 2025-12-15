import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/borrow_request_model.dart';

/// Service for managing borrow requests.
///
/// Handles creating, updating, and querying borrow requests
/// for both members and librarians.
class BorrowRequestService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Creates a new borrow request from a member.
  ///
  /// Parameters:
  /// - [userId]: ID of the user making the request
  /// - [bookId]: ID of the book being requested
  /// - [itemId]: Optional ID of specific book item member wants to borrow
  /// - [memberNote]: Optional note from member
  ///
  /// Throws [Exception] if validation fails or database error occurs.
  Future<String> createBorrowRequest({
    required String userId,
    required String bookId,
    String? itemId,
    String? memberNote,
  }) async {
    try {
      // Validate inputs
      if (userId.isEmpty || bookId.isEmpty) {
        throw Exception('User ID and Book ID are required');
      }

      // If itemId provided, verify it's available
      if (itemId != null && itemId.isNotEmpty) {
        final itemDoc = await _firestore
            .collection('bookItems')
            .doc(itemId)
            .get();
        if (!itemDoc.exists) {
          throw Exception('Book item not found');
        }
        final itemData = itemDoc.data()!;
        if (itemData['status'] != 'available') {
          throw Exception('This book item is not available');
        }
        if (itemData['bookId'] != bookId) {
          throw Exception('Book item does not belong to this book');
        }
      }

      // Check if user already has a pending request for this book
      final existingRequests = await _firestore
          .collection('borrowRequests')
          .where('userId', isEqualTo: userId)
          .where('bookId', isEqualTo: bookId)
          .where('status', isEqualTo: 'pending')
          .get();

      if (existingRequests.docs.isNotEmpty) {
        throw Exception('You already have a pending request for this book');
      }

      // Check if user already has this book on loan
      final activeLoans = await _firestore
          .collection('loans')
          .where('userId', isEqualTo: userId)
          .where('bookId', isEqualTo: bookId)
          .where('status', whereIn: ['borrowed', 'overdue'])
          .get();

      if (activeLoans.docs.isNotEmpty) {
        throw Exception('You already have an active loan for this book');
      }

      // Check user's borrow limit
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) {
        throw Exception('User not found');
      }

      final userData = userDoc.data()!;
      final borrowedCount = userData['borrowedCount'] as int? ?? 0;
      final maxBorrow = userData['maxBorrow'] as int? ?? 3;

      if (borrowedCount >= maxBorrow) {
        throw Exception('You have reached your borrowing limit');
      }

      // Verify book exists
      final bookDoc = await _firestore.collection('books').doc(bookId).get();
      if (!bookDoc.exists) {
        throw Exception('Book not found');
      }

      // Create the request
      final requestRef = _firestore.collection('borrowRequests').doc();
      final request = BorrowRequest(
        id: requestRef.id,
        userId: userId,
        bookId: bookId,
        itemId: itemId,
        requestedAt: Timestamp.now(),
        status: 'pending',
        memberNote: memberNote?.trim(),
      );

      await requestRef.set(request.toJson());

      return requestRef.id;
    } on FirebaseException catch (e) {
      // Check for permission denied errors
      if (e.code == 'permission-denied') {
        throw Exception(
          'PERMISSION_DENIED: Firebase rules chưa cho phép tạo borrow request. Vui lòng deploy rules.',
        );
      }
      throw Exception('Database error: ${e.code} - ${e.message}');
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Unexpected error: $e');
    }
  }

  /// Cancels a pending borrow request.
  ///
  /// Only the member who created the request can cancel it.
  Future<void> cancelBorrowRequest(String requestId, String userId) async {
    try {
      final requestDoc = await _firestore
          .collection('borrowRequests')
          .doc(requestId)
          .get();

      if (!requestDoc.exists) {
        throw Exception('Request not found');
      }

      final request = BorrowRequest.fromDoc(requestDoc);

      if (request.userId != userId) {
        throw Exception('You can only cancel your own requests');
      }

      if (request.status != 'pending') {
        throw Exception('Only pending requests can be cancelled');
      }

      await _firestore.collection('borrowRequests').doc(requestId).update({
        'status': 'cancelled',
        'processedAt': Timestamp.now(),
      });
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Error cancelling request: $e');
    }
  }

  /// Gets all borrow requests for a specific user.
  Future<List<BorrowRequest>> getUserBorrowRequests(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('borrowRequests')
          .where('userId', isEqualTo: userId)
          .orderBy('requestedAt', descending: true)
          .limit(100)
          .get();

      return snapshot.docs.map((doc) => BorrowRequest.fromDoc(doc)).toList();
    } catch (e) {
      throw Exception('Error loading requests: $e');
    }
  }

  /// Gets all borrow requests for a specific user as a stream.
  Stream<List<BorrowRequest>> getUserBorrowRequestsStream(String userId) {
    return _firestore
        .collection('borrowRequests')
        .where('userId', isEqualTo: userId)
        .orderBy('requestedAt', descending: true)
        .limit(100)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => BorrowRequest.fromDoc(doc)).toList(),
        );
  }

  /// Gets all borrow requests (for librarian).
  Future<List<BorrowRequest>> getAllBorrowRequests() async {
    try {
      final snapshot = await _firestore
          .collection('borrowRequests')
          .orderBy('requestedAt', descending: true)
          .get();

      return snapshot.docs.map((doc) => BorrowRequest.fromDoc(doc)).toList();
    } catch (e) {
      throw Exception('Error loading requests: $e');
    }
  }

  /// Gets all borrow requests as a stream (for librarian).
  Stream<List<BorrowRequest>> getAllBorrowRequestsStream() {
    return _firestore
        .collection('borrowRequests')
        .orderBy('requestedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => BorrowRequest.fromDoc(doc)).toList(),
        );
  }

  /// Approves a borrow request and issues the book.
  ///
  /// This should be called by librarians only.
  Future<void> approveBorrowRequest({
    required String requestId,
    required String itemId,
    required String librarianId,
    String? librarianNote,
  }) async {
    try {
      await _firestore.runTransaction((transaction) async {
        // Get request
        final requestRef = _firestore
            .collection('borrowRequests')
            .doc(requestId);
        final requestDoc = await transaction.get(requestRef);

        if (!requestDoc.exists) {
          throw Exception('Request not found');
        }

        final request = BorrowRequest.fromDoc(requestDoc);

        if (request.status != 'pending') {
          throw Exception('Request is not pending');
        }

        // Get book item
        final itemRef = _firestore.collection('bookItems').doc(itemId);
        final itemDoc = await transaction.get(itemRef);

        if (!itemDoc.exists) {
          throw Exception('Book item not found');
        }

        final itemData = itemDoc.data()!;
        if (itemData['status'] != 'available') {
          throw Exception('Book item is not available');
        }

        // Get user
        final userRef = _firestore.collection('users').doc(request.userId);
        final userDoc = await transaction.get(userRef);

        if (!userDoc.exists) {
          throw Exception('User not found');
        }

        final userData = userDoc.data()!;
        final borrowedCount = userData['borrowedCount'] as int? ?? 0;
        final maxBorrow = userData['maxBorrow'] as int? ?? 3;

        if (borrowedCount >= maxBorrow) {
          throw Exception('User has reached borrowing limit');
        }

        // Get book
        final bookRef = _firestore.collection('books').doc(request.bookId);
        final bookDoc = await transaction.get(bookRef);

        if (!bookDoc.exists) {
          throw Exception('Book not found');
        }

        // Create loan
        final loanRef = _firestore.collection('loans').doc();
        final now = Timestamp.now();
        final dueDate = Timestamp.fromDate(
          DateTime.now().add(const Duration(days: 15)),
        );

        transaction.set(loanRef, {
          'userId': request.userId,
          'itemId': itemId,
          'bookId': request.bookId,
          'issueDate': now,
          'dueDate': dueDate,
          'status': 'borrowed',
          'fine': 0.0,
          'renewCount': 0,
          'finePaid': false,
          'issuedBy': librarianId,
        });

        // Update book item status
        transaction.update(itemRef, {'status': 'borrowed'});

        // Update book available copies
        transaction.update(bookRef, {
          'availableCopies': FieldValue.increment(-1),
        });

        // Update user borrowed count
        transaction.update(userRef, {'borrowedCount': FieldValue.increment(1)});

        // Update request status
        transaction.update(requestRef, {
          'status': 'approved',
          'itemId': itemId,
          'librarianNote': librarianNote?.trim(),
          'processedBy': librarianId,
          'processedAt': now,
        });
      });
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Error approving request: $e');
    }
  }

  /// Rejects a borrow request.
  ///
  /// This should be called by librarians only.
  Future<void> rejectBorrowRequest({
    required String requestId,
    required String librarianId,
    required String reason,
  }) async {
    try {
      final requestDoc = await _firestore
          .collection('borrowRequests')
          .doc(requestId)
          .get();

      if (!requestDoc.exists) {
        throw Exception('Request not found');
      }

      final request = BorrowRequest.fromDoc(requestDoc);

      if (request.status != 'pending') {
        throw Exception('Request is not pending');
      }

      await _firestore.collection('borrowRequests').doc(requestId).update({
        'status': 'rejected',
        'librarianNote': reason.trim(),
        'processedBy': librarianId,
        'processedAt': Timestamp.now(),
      });
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Error rejecting request: $e');
    }
  }
}
