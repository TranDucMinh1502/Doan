import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/book_item_model.dart';

/// Service class for handling book item operations with Firestore.
///
/// Manages individual physical copies of books in the library system.
class BookItemService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Gets all book items for a specific book.
  ///
  /// Parameters:
  /// - [bookId]: The ID of the book
  ///
  /// Returns a list of [BookItem] objects.
  Future<List<BookItem>> getBookItems(String bookId) async {
    try {
      if (bookId.isEmpty) {
        throw Exception('Book ID cannot be empty.');
      }

      final QuerySnapshot snapshot = await _firestore
          .collection('bookItems')
          .where('bookId', isEqualTo: bookId)
          .orderBy('barcode')
          .get();

      return snapshot.docs.map((doc) => BookItem.fromDoc(doc)).toList();
    } on FirebaseException catch (e) {
      throw Exception('Database error while fetching book items: ${e.message}');
    } catch (e) {
      throw Exception('An unexpected error occurred: $e');
    }
  }

  /// Gets available book items for a specific book.
  ///
  /// Parameters:
  /// - [bookId]: The ID of the book
  ///
  /// Returns a list of available [BookItem] objects.
  Future<List<BookItem>> getAvailableBookItems(String bookId) async {
    try {
      if (bookId.isEmpty) {
        throw Exception('Book ID cannot be empty.');
      }

      final QuerySnapshot snapshot = await _firestore
          .collection('bookItems')
          .where('bookId', isEqualTo: bookId)
          .where('status', isEqualTo: 'available')
          .get();

      // Sort by barcode in memory instead of using orderBy
      final items = snapshot.docs.map((doc) => BookItem.fromDoc(doc)).toList();
      items.sort((a, b) => a.barcode.compareTo(b.barcode));

      return items;
    } on FirebaseException catch (e) {
      throw Exception(
        'Database error while fetching available book items: ${e.message}',
      );
    } catch (e) {
      throw Exception('An unexpected error occurred: $e');
    }
  }

  /// Gets a specific book item by ID.
  ///
  /// Parameters:
  /// - [itemId]: The ID of the book item
  ///
  /// Returns the [BookItem] if found, null otherwise.
  Future<BookItem?> getBookItemById(String itemId) async {
    try {
      if (itemId.isEmpty) {
        throw Exception('Item ID cannot be empty.');
      }

      final DocumentSnapshot doc = await _firestore
          .collection('bookItems')
          .doc(itemId)
          .get();

      if (!doc.exists) {
        return null;
      }

      return BookItem.fromDoc(doc);
    } on FirebaseException catch (e) {
      throw Exception('Database error while fetching book item: ${e.message}');
    } catch (e) {
      throw Exception('An unexpected error occurred: $e');
    }
  }

  /// Updates a book item's status.
  ///
  /// Parameters:
  /// - [itemId]: The ID of the book item
  /// - [status]: The new status
  Future<void> updateBookItemStatus(String itemId, String status) async {
    try {
      if (itemId.isEmpty) {
        throw Exception('Item ID cannot be empty.');
      }

      await _firestore.collection('bookItems').doc(itemId).update({
        'status': status,
      });
    } on FirebaseException catch (e) {
      throw Exception('Database error while updating book item: ${e.message}');
    } catch (e) {
      throw Exception('An unexpected error occurred: $e');
    }
  }
}
