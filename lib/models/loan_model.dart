import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a book loan transaction in the library system.
///
/// This model maps to the 'loans' collection in Firestore and tracks
/// the borrowing of book items by users, including due dates, return status,
/// fines, and renewal information.
class Loan {
  /// Unique identifier for the loan transaction
  final String id;

  /// Reference to the user who borrowed the book
  final String userId;

  /// Reference to the specific book item being borrowed
  final String itemId;

  /// Reference to the book (parent of the item)
  final String bookId;

  /// Date and time when the book was issued/borrowed
  final Timestamp issueDate;

  /// Date and time when the book is due to be returned
  final Timestamp dueDate;

  /// Date and time when the book was actually returned
  ///
  /// This is null if the book has not been returned yet.
  final Timestamp? returnDate;

  /// Current status of the loan
  ///
  /// Possible values:
  /// - "borrowed": Book is currently on loan
  /// - "returned": Book has been returned
  /// - "overdue": Book is past due date and not returned
  final String status;

  /// Fine amount accumulated for this loan (e.g., overdue fees)
  final double fine;

  /// Number of times this loan has been renewed
  final int renewCount;

  /// Whether the fine has been paid
  final bool finePaid;

  /// Date and time when the fine was paid
  final Timestamp? finePaidAt;

  /// Creates a new [Loan] instance.
  ///
  /// All parameters except [returnDate], [finePaidAt] are required.
  /// [returnDate] and [finePaidAt] are nullable.
  Loan({
    required this.id,
    required this.userId,
    required this.itemId,
    required this.bookId,
    required this.issueDate,
    required this.dueDate,
    this.returnDate,
    required this.status,
    required this.fine,
    required this.renewCount,
    this.finePaid = false,
    this.finePaidAt,
  });

  /// Creates a [Loan] instance from a Firestore document.
  ///
  /// Maps the Firestore document fields to the Loan model properties.
  /// The document ID is used as the loan's ID.
  ///
  /// Example:
  /// ```dart
  /// DocumentSnapshot doc = await FirebaseFirestore.instance
  ///     .collection('loans')
  ///     .doc('loanId')
  ///     .get();
  /// Loan loan = Loan.fromDoc(doc);
  /// ```
  factory Loan.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return Loan(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      itemId: data['itemId'] as String? ?? '',
      bookId: data['bookId'] as String? ?? '',
      issueDate: data['issueDate'] as Timestamp? ?? Timestamp.now(),
      dueDate: data['dueDate'] as Timestamp? ?? Timestamp.now(),
      returnDate: data['returnDate'] as Timestamp?,
      status: data['status'] as String? ?? 'borrowed',
      fine: (data['fine'] as num?)?.toDouble() ?? 0.0,
      renewCount: data['renewCount'] as int? ?? 0,
      finePaid: data['finePaid'] as bool? ?? false,
      finePaidAt: data['finePaidAt'] as Timestamp?,
    );
  }

  /// Converts the [Loan] instance to a JSON map.
  ///
  /// This is useful for sending data to Firestore or serializing
  /// the loan data for other purposes.
  ///
  /// Returns a map with all loan properties except the ID,
  /// as Firestore document IDs are stored separately.
  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'itemId': itemId,
      'bookId': bookId,
      'issueDate': issueDate,
      'dueDate': dueDate,
      'returnDate': returnDate,
      'status': status,
      'fine': fine,
      'renewCount': renewCount,
      'finePaid': finePaid,
      'finePaidAt': finePaidAt,
    };
  }

  /// Creates a copy of this [Loan] with the given fields replaced.
  ///
  /// Useful for updating specific fields while keeping others unchanged.
  Loan copyWith({
    String? id,
    String? userId,
    String? itemId,
    String? bookId,
    Timestamp? issueDate,
    Timestamp? dueDate,
    Timestamp? returnDate,
    String? status,
    double? fine,
    int? renewCount,
    bool? finePaid,
    Timestamp? finePaidAt,
  }) {
    return Loan(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      itemId: itemId ?? this.itemId,
      bookId: bookId ?? this.bookId,
      issueDate: issueDate ?? this.issueDate,
      dueDate: dueDate ?? this.dueDate,
      returnDate: returnDate ?? this.returnDate,
      status: status ?? this.status,
      fine: fine ?? this.fine,
      renewCount: renewCount ?? this.renewCount,
      finePaid: finePaid ?? this.finePaid,
      finePaidAt: finePaidAt ?? this.finePaidAt,
    );
  }

  /// Checks if the loan is currently active (borrowed and not returned).
  bool get isActive => status == 'borrowed';

  /// Checks if the book has been returned.
  bool get isReturned => status == 'returned';

  /// Checks if the loan is overdue.
  bool get isOverdue => status == 'overdue';

  /// Checks if there is an outstanding fine.
  bool get hasFine => fine > 0;

  /// Calculates the number of days until the due date.
  ///
  /// Returns negative number if overdue.
  int get daysUntilDue {
    final now = DateTime.now();
    final due = dueDate.toDate();
    return due.difference(now).inDays;
  }

  /// Calculates the number of days the loan has been active.
  int get daysOnLoan {
    final issue = issueDate.toDate();
    final reference = returnDate?.toDate() ?? DateTime.now();
    return reference.difference(issue).inDays;
  }

  @override
  String toString() {
    return 'Loan(id: $id, userId: $userId, itemId: $itemId, bookId: $bookId, '
        'status: $status, issueDate: ${issueDate.toDate()}, '
        'dueDate: ${dueDate.toDate()}, fine: $fine)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is Loan && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
