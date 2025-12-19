import 'package:cloud_firestore/cloud_firestore.dart';

class Loan {
  final String id;
  final String userId;
  final String bookId;
  final String itemId;
  final Timestamp issueDate;
  final Timestamp dueDate;
  final Timestamp? returnDate;
  final String status; // 'issued', 'returned', 'overdue'
  final num fine;

  Loan({
    required this.id,
    required this.userId,
    required this.bookId,
    required this.itemId,
    required this.issueDate,
    required this.dueDate,
    this.returnDate,
    this.status = 'issued',
    this.fine = 0,
  });

  factory Loan.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return Loan(
      id: doc.id,
      userId: d['userId'] ?? '',
      bookId: d['bookId'] ?? '',
      itemId: d['itemId'] ?? '',
      issueDate: d['issueDate'] ?? Timestamp.now(),
      dueDate: d['dueDate'] ?? Timestamp.now(),
      returnDate: d['returnDate'],
      status: d['status'] ?? 'issued',
      fine: d['fine'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
    'userId': userId,
    'bookId': bookId,
    'itemId': itemId,
    'issueDate': issueDate,
    'dueDate': dueDate,
    'returnDate': returnDate,
    'status': status,
    'fine': fine,
  };
}
