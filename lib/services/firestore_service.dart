import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<Map<String, dynamic>> checkoutBook({
    required String userId,
    required String bookId,
    int loanDays = 15,
  }) async {
    // First, check if user already has active loan for this book
    final existingLoan = await _db
        .collection('loans')
        .where('userId', isEqualTo: userId)
        .where('bookId', isEqualTo: bookId)
        .where('status', isEqualTo: 'issued')
        .limit(1)
        .get();

    if (existingLoan.docs.isNotEmpty) {
      throw Exception('Bạn đã mượn sách này rồi');
    }

    return _db.runTransaction((tx) async {
      final userRef = _db.collection('users').doc(userId);
      final bookRef = _db.collection('books').doc(bookId);

      final userSnap = await tx.get(userRef);
      final bookSnap = await tx.get(bookRef);
      if (!userSnap.exists) throw Exception('Không tìm thấy người dùng');
      if (!bookSnap.exists) throw Exception('Không tìm thấy sách');

      final user = userSnap.data() as Map<String, dynamic>;
      final book = bookSnap.data() as Map<String, dynamic>;

      final borrowedCount = (user['borrowedCount'] ?? 0) as int;
      final maxBorrow = (user['maxBorrow'] ?? 5) as int;
      final availableCopies = (book['availableCopies'] ?? 0) as int;

      // Check borrow limit
      if (borrowedCount >= maxBorrow) {
        throw Exception('Bạn đã đạt giới hạn mượn sách ($maxBorrow cuốn)');
      }

      // Check availability
      if (availableCopies <= 0) {
        throw Exception('Sách đã hết. Vui lòng đặt trước (Reserve)');
      }

      // Try to find an available BookItem
      final itemsQuery = await _db
          .collection('bookItems')
          .where('bookId', isEqualTo: bookId)
          .where('status', isEqualTo: 'available')
          .limit(1)
          .get();

      String itemId;

      // If no bookItems exist, create one automatically
      if (itemsQuery.docs.isEmpty) {
        final newItemRef = _db.collection('bookItems').doc();
        itemId = newItemRef.id;
        tx.set(newItemRef, {
          'bookId': bookId,
          'status': 'loaned',
          'barcode': 'AUTO-${DateTime.now().millisecondsSinceEpoch}',
          'createdAt': Timestamp.now(),
        });
      } else {
        final itemDoc = itemsQuery.docs.first;
        itemId = itemDoc.id;
        tx.update(itemDoc.reference, {'status': 'loaned'});
      }

      // Create loan
      final loanRef = _db.collection('loans').doc();
      final now = Timestamp.now();
      final due = Timestamp.fromDate(
        DateTime.now().add(Duration(days: loanDays)),
      );

      tx.set(loanRef, {
        'userId': userId,
        'bookId': bookId,
        'itemId': itemId,
        'issueDate': now,
        'dueDate': due,
        'status': 'issued',
        'fine': 0,
        'renewCount': 0,
      });

      // Update book and user
      tx.update(bookRef, {'availableCopies': availableCopies - 1});
      tx.update(userRef, {'borrowedCount': borrowedCount + 1});

      final dueDate = due.toDate();
      return {
        'loanId': loanRef.id,
        'itemId': itemId,
        'dueDate': '${dueDate.day}/${dueDate.month}/${dueDate.year}',
      };
    });
  }

  Future<void> returnBook({required String loanId, num finePerDay = 1}) async {
    final loanRef = _db.collection('loans').doc(loanId);

    return _db.runTransaction((tx) async {
      final loanSnap = await tx.get(loanRef);
      if (!loanSnap.exists) throw Exception('Loan not found');
      final loan = loanSnap.data() as Map<String, dynamic>;

      if (loan['status'] == 'returned') throw Exception('Already returned');

      final itemId = loan['itemId'] as String;
      final itemRef = _db.collection('bookItems').doc(itemId);
      final bookRef = _db.collection('books').doc(loan['bookId'] as String);
      final userRef = _db.collection('users').doc(loan['userId'] as String);

      final bookSnap = await tx.get(bookRef);
      final userSnap = await tx.get(userRef);

      final book = bookSnap.data() ?? {};
      final user = userSnap.data() ?? {};

      final availableCopies = (book['availableCopies'] ?? 0) as int;
      final borrowedCount = (user['borrowedCount'] ?? 1) as int;

      // compute fine if overdue
      final due = loan['dueDate'] as Timestamp;
      final now = Timestamp.now();
      num fine = 0;
      if (now.seconds > due.seconds) {
        final overdueDays = ((now.seconds - due.seconds) / 86400).ceil();
        fine = overdueDays * finePerDay;
      }

      tx.update(loanRef, {
        'status': 'returned',
        'returnDate': Timestamp.now(),
        'fine': fine,
      });

      tx.update(itemRef, {'status': 'available'});
      tx.update(bookRef, {'availableCopies': availableCopies + 1});
      tx.update(userRef, {'borrowedCount': (borrowedCount - 1).clamp(0, 9999)});
    });
  }

  // Create a reservation with validation
  Future<String> reserveBook({
    required String userId,
    required String bookId,
  }) async {
    // Check if user already has an active reservation for this book
    final existingReservation = await _db
        .collection('reservations')
        .where('userId', isEqualTo: userId)
        .where('bookId', isEqualTo: bookId)
        .where('status', isEqualTo: 'waiting')
        .limit(1)
        .get();

    if (existingReservation.docs.isNotEmpty) {
      throw Exception('Bạn đã đặt trước sách này rồi');
    }

    // Check if user already borrowed this book
    final existingLoan = await _db
        .collection('loans')
        .where('userId', isEqualTo: userId)
        .where('bookId', isEqualTo: bookId)
        .where('status', isEqualTo: 'issued')
        .limit(1)
        .get();

    if (existingLoan.docs.isNotEmpty) {
      throw Exception('Bạn đang mượn sách này rồi');
    }

    // Check if book is actually available (maybe user should just checkout instead)
    final bookSnap = await _db.collection('books').doc(bookId).get();
    if (!bookSnap.exists) throw Exception('Không tìm thấy sách');

    final book = bookSnap.data() as Map<String, dynamic>;
    final availableCopies = (book['availableCopies'] ?? 0) as int;

    if (availableCopies > 0) {
      throw Exception('Sách còn sẵn. Bạn có thể mượn ngay!');
    }

    // Create reservation
    final ref = _db.collection('reservations').doc();
    await ref.set({
      'userId': userId,
      'bookId': bookId,
      'itemId': null,
      'reservedAt': Timestamp.now(),
      'status': 'waiting',
      'notified': false,
    });
    return ref.id;
  }

  // Cancel a reservation
  Future<void> cancelReservation({required String reservationId}) async {
    final ref = _db.collection('reservations').doc(reservationId);
    await ref.update({'status': 'cancelled', 'cancelledAt': Timestamp.now()});
  }

  // Get user's active reservations
  Stream<List<Map<String, dynamic>>> getUserReservations(String userId) {
    return _db
        .collection('reservations')
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: 'waiting')
        .orderBy('reservedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return data;
          }).toList(),
        );
  }

  // Renew a loan (extend due date)
  Future<Map<String, dynamic>> renewLoan({
    required String loanId,
    int additionalDays = 7,
  }) async {
    return _db.runTransaction((tx) async {
      final loanRef = _db.collection('loans').doc(loanId);
      final loanSnap = await tx.get(loanRef);

      if (!loanSnap.exists) throw Exception('Không tìm thấy phiếu mượn');

      final loan = loanSnap.data() as Map<String, dynamic>;
      if (loan['status'] != 'issued') {
        throw Exception('Chỉ có thể gia hạn sách đang mượn');
      }

      final renewCount = (loan['renewCount'] ?? 0) as int;
      if (renewCount >= 3) {
        throw Exception('Đã đạt giới hạn gia hạn (tối đa 3 lần)');
      }

      final currentDue = (loan['dueDate'] as Timestamp).toDate();
      final newDue = currentDue.add(Duration(days: additionalDays));

      tx.update(loanRef, {
        'dueDate': Timestamp.fromDate(newDue),
        'renewCount': renewCount + 1,
        'lastRenewedAt': Timestamp.now(),
      });

      return {
        'newDueDate': '${newDue.day}/${newDue.month}/${newDue.year}',
        'renewCount': renewCount + 1,
      };
    });
  }

  /// Recalculate and fix `borrowedCount` for a user by counting active issued loans.
  /// Returns the recalculated count.
  Future<int> recalculateBorrowedCount(String userId) async {
    final loansSnap = await _db
        .collection('loans')
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: 'issued')
        .get();

    final count = loansSnap.docs.length;
    final userRef = _db.collection('users').doc(userId);
    await userRef.update({'borrowedCount': count});
    return count;
  }
}
