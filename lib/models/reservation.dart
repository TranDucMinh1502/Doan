import 'package:cloud_firestore/cloud_firestore.dart';

class Reservation {
  final String id;
  final String userId;
  final String bookId;
  final String? itemId;
  final Timestamp reservedAt;
  final String status; // 'waiting', 'ready', 'cancelled', 'collected'

  Reservation({
    required this.id,
    required this.userId,
    required this.bookId,
    this.itemId,
    required this.reservedAt,
    this.status = 'waiting',
  });

  factory Reservation.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return Reservation(
      id: doc.id,
      userId: d['userId'] ?? '',
      bookId: d['bookId'] ?? '',
      itemId: d['itemId'],
      reservedAt: d['reservedAt'] ?? Timestamp.now(),
      status: d['status'] ?? 'waiting',
    );
  }

  Map<String, dynamic> toMap() => {
    'userId': userId,
    'bookId': bookId,
    'itemId': itemId,
    'reservedAt': reservedAt,
    'status': status,
  };
}
