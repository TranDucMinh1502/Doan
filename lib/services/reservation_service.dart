import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/reservation_model.dart';

/// Service class for handling book reservation operations with Firestore.
///
/// This service manages the reservation queue for books, allowing users
/// to reserve unavailable books and be notified when they become available.
class ReservationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Reserves a book for a user.
  ///
  /// Creates a new reservation document in the 'reservations' collection
  /// with status "waiting". Validates that the user doesn't already have
  /// an active reservation for the same book.
  ///
  /// Parameters:
  /// - [userId]: The ID of the user making the reservation
  /// - [bookId]: The ID of the book to reserve
  ///
  /// Throws:
  /// - [FirebaseException] for Firestore errors
  /// - [Exception] for validation errors (duplicate reservation, etc.)
  ///
  /// Example:
  /// ```dart
  /// try {
  ///   await reservationService.reserveBook('user123', 'book456');
  ///   print('Book reserved successfully');
  /// } catch (e) {
  ///   print('Error: $e');
  /// }
  /// ```
  Future<void> reserveBook(String userId, String bookId) async {
    try {
      // Validate input parameters
      if (userId.isEmpty || bookId.isEmpty) {
        throw Exception('User ID and Book ID cannot be empty.');
      }

      // Check if user already has an active reservation for this book
      final existingReservations = await _firestore
          .collection('reservations')
          .where('userId', isEqualTo: userId)
          .where('bookId', isEqualTo: bookId)
          .where('status', whereIn: ['waiting', 'notified'])
          .get();

      if (existingReservations.docs.isNotEmpty) {
        throw Exception(
          'You already have an active reservation for this book.',
        );
      }

      // Verify the book exists
      final bookDoc = await _firestore.collection('books').doc(bookId).get();
      if (!bookDoc.exists) {
        throw Exception('Book not found.');
      }

      // Verify the user exists
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) {
        throw Exception('User not found.');
      }

      // Create reservation document
      final reservationRef = _firestore.collection('reservations').doc();
      final Reservation reservation = Reservation(
        id: reservationRef.id,
        userId: userId,
        bookId: bookId,
        itemId: null,
        reservedAt: Timestamp.now(),
        status: 'waiting',
      );

      // Save reservation to Firestore
      await reservationRef.set(reservation.toJson());
    } on FirebaseException catch (e) {
      throw Exception(
        'Database error while creating reservation: ${e.message}',
      );
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }
      throw Exception('An unexpected error occurred: $e');
    }
  }

  /// Cancels an existing reservation.
  ///
  /// Updates the reservation status to "canceled". Only active reservations
  /// (waiting or notified) can be canceled.
  ///
  /// Parameters:
  /// - [reservationId]: The ID of the reservation to cancel
  ///
  /// Throws:
  /// - [FirebaseException] for Firestore errors
  /// - [Exception] for validation errors
  ///
  /// Example:
  /// ```dart
  /// try {
  ///   await reservationService.cancelReservation('reservation123');
  ///   print('Reservation canceled successfully');
  /// } catch (e) {
  ///   print('Error: $e');
  /// }
  /// ```
  Future<void> cancelReservation(String reservationId) async {
    try {
      // Validate input
      if (reservationId.isEmpty) {
        throw Exception('Reservation ID cannot be empty.');
      }

      // Get reservation document
      final reservationRef = _firestore
          .collection('reservations')
          .doc(reservationId);
      final reservationDoc = await reservationRef.get();

      // Validate reservation exists
      if (!reservationDoc.exists) {
        throw Exception('Reservation not found.');
      }

      // Extract reservation data
      final reservationData = reservationDoc.data() as Map<String, dynamic>;
      final status = reservationData['status'] as String? ?? '';

      // Validate reservation can be canceled
      if (status == 'canceled') {
        throw Exception('Reservation is already canceled.');
      }

      if (status == 'fulfilled') {
        throw Exception('Cannot cancel a fulfilled reservation.');
      }

      if (status != 'waiting' && status != 'notified') {
        throw Exception('Invalid reservation status: $status');
      }

      // Update reservation status to canceled
      await reservationRef.update({'status': 'canceled'});
    } on FirebaseException catch (e) {
      throw Exception(
        'Database error while canceling reservation: ${e.message}',
      );
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }
      throw Exception('An unexpected error occurred: $e');
    }
  }

  /// Gets all reservations for a specific user.
  ///
  /// Retrieves all reservation documents for the user, ordered by
  /// reservation date (most recent first).
  ///
  /// Parameters:
  /// - [userId]: The ID of the user
  ///
  /// Returns a list of [Reservation] objects.
  ///
  /// Throws:
  /// - [FirebaseException] for Firestore errors
  ///
  /// Example:
  /// ```dart
  /// try {
  ///   final reservations = await reservationService.getUserReservations('user123');
  ///   print('Found ${reservations.length} reservations');
  /// } catch (e) {
  ///   print('Error: $e');
  /// }
  /// ```
  Future<List<Reservation>> getUserReservations(String userId) async {
    try {
      // Validate input
      if (userId.isEmpty) {
        throw Exception('User ID cannot be empty.');
      }

      // Fetch user's reservations
      final QuerySnapshot snapshot = await _firestore
          .collection('reservations')
          .where('userId', isEqualTo: userId)
          .orderBy('reservedAt', descending: true)
          .get();

      return snapshot.docs.map((doc) => Reservation.fromDoc(doc)).toList();
    } on FirebaseException catch (e) {
      throw Exception(
        'Database error while fetching reservations: ${e.message}',
      );
    } catch (e) {
      throw Exception('An unexpected error occurred: $e');
    }
  }

  /// Gets active (waiting or notified) reservations for a user.
  ///
  /// Parameters:
  /// - [userId]: The ID of the user
  ///
  /// Returns a list of active [Reservation] objects.
  Future<List<Reservation>> getUserActiveReservations(String userId) async {
    try {
      if (userId.isEmpty) {
        throw Exception('User ID cannot be empty.');
      }

      final QuerySnapshot snapshot = await _firestore
          .collection('reservations')
          .where('userId', isEqualTo: userId)
          .where('status', whereIn: ['waiting', 'notified'])
          .orderBy('reservedAt', descending: false)
          .get();

      return snapshot.docs.map((doc) => Reservation.fromDoc(doc)).toList();
    } on FirebaseException catch (e) {
      throw Exception(
        'Database error while fetching active reservations: ${e.message}',
      );
    } catch (e) {
      throw Exception('An unexpected error occurred: $e');
    }
  }

  /// Gets all waiting reservations for a specific book.
  ///
  /// Returns reservations in order of reservation date (first come, first served).
  ///
  /// Parameters:
  /// - [bookId]: The ID of the book
  ///
  /// Returns a list of [Reservation] objects ordered by reservedAt.
  Future<List<Reservation>> getBookReservations(String bookId) async {
    try {
      if (bookId.isEmpty) {
        throw Exception('Book ID cannot be empty.');
      }

      final QuerySnapshot snapshot = await _firestore
          .collection('reservations')
          .where('bookId', isEqualTo: bookId)
          .where('status', isEqualTo: 'waiting')
          .orderBy('reservedAt', descending: false)
          .get();

      return snapshot.docs.map((doc) => Reservation.fromDoc(doc)).toList();
    } on FirebaseException catch (e) {
      throw Exception(
        'Database error while fetching book reservations: ${e.message}',
      );
    } catch (e) {
      throw Exception('An unexpected error occurred: $e');
    }
  }

  /// Notifies the next user in queue when a book becomes available.
  ///
  /// Finds the oldest waiting reservation for a book and updates its status
  /// to "notified", optionally assigning a specific book item.
  ///
  /// Parameters:
  /// - [bookId]: The ID of the book that became available
  /// - [itemId]: Optional ID of the specific book item to assign
  ///
  /// Returns the reservation ID that was notified, or null if no waiting reservations.
  Future<String?> notifyNextReservation(String bookId, {String? itemId}) async {
    try {
      if (bookId.isEmpty) {
        throw Exception('Book ID cannot be empty.');
      }

      // Get the oldest waiting reservation
      final QuerySnapshot snapshot = await _firestore
          .collection('reservations')
          .where('bookId', isEqualTo: bookId)
          .where('status', isEqualTo: 'waiting')
          .orderBy('reservedAt', descending: false)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        return null; // No waiting reservations
      }

      final reservationDoc = snapshot.docs.first;
      final updateData = {
        'status': 'notified',
        if (itemId != null && itemId.isNotEmpty) 'itemId': itemId,
      };

      await reservationDoc.reference.update(updateData);
      return reservationDoc.id;
    } on FirebaseException catch (e) {
      throw Exception(
        'Database error while notifying reservation: ${e.message}',
      );
    } catch (e) {
      throw Exception('An unexpected error occurred: $e');
    }
  }

  /// Fulfills a reservation (when the user borrows the reserved book).
  ///
  /// Updates the reservation status to "fulfilled".
  ///
  /// Parameters:
  /// - [reservationId]: The ID of the reservation to fulfill
  Future<void> fulfillReservation(String reservationId) async {
    try {
      if (reservationId.isEmpty) {
        throw Exception('Reservation ID cannot be empty.');
      }

      final reservationRef = _firestore
          .collection('reservations')
          .doc(reservationId);
      final reservationDoc = await reservationRef.get();

      if (!reservationDoc.exists) {
        throw Exception('Reservation not found.');
      }

      final reservationData = reservationDoc.data() as Map<String, dynamic>;
      final status = reservationData['status'] as String? ?? '';

      if (status != 'notified') {
        throw Exception('Only notified reservations can be fulfilled.');
      }

      await reservationRef.update({'status': 'fulfilled'});
    } on FirebaseException catch (e) {
      throw Exception(
        'Database error while fulfilling reservation: ${e.message}',
      );
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }
      throw Exception('An unexpected error occurred: $e');
    }
  }

  /// Returns a stream of user reservations for real-time updates.
  ///
  /// Parameters:
  /// - [userId]: The ID of the user
  Stream<List<Reservation>> getUserReservationsStream(String userId) {
    return _firestore
        .collection('reservations')
        .where('userId', isEqualTo: userId)
        .orderBy('reservedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => Reservation.fromDoc(doc)).toList(),
        );
  }

  /// Checks if a user has an active reservation for a specific book.
  ///
  /// Parameters:
  /// - [userId]: The ID of the user
  /// - [bookId]: The ID of the book
  ///
  /// Returns true if user has an active reservation, false otherwise.
  Future<bool> hasActiveReservation(String userId, String bookId) async {
    try {
      if (userId.isEmpty || bookId.isEmpty) {
        return false;
      }

      final QuerySnapshot snapshot = await _firestore
          .collection('reservations')
          .where('userId', isEqualTo: userId)
          .where('bookId', isEqualTo: bookId)
          .where('status', whereIn: ['waiting', 'notified'])
          .limit(1)
          .get();

      return snapshot.docs.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Gets the count of users waiting for a specific book.
  ///
  /// Parameters:
  /// - [bookId]: The ID of the book
  ///
  /// Returns the number of waiting reservations.
  Future<int> getWaitingCount(String bookId) async {
    try {
      if (bookId.isEmpty) {
        return 0;
      }

      final QuerySnapshot snapshot = await _firestore
          .collection('reservations')
          .where('bookId', isEqualTo: bookId)
          .where('status', isEqualTo: 'waiting')
          .get();

      return snapshot.docs.length;
    } catch (e) {
      return 0;
    }
  }
}
