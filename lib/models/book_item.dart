import 'package:cloud_firestore/cloud_firestore.dart';

class BookItem {
  final String id;
  final String bookId;
  final String barcode;
  final String status; // 'available', 'loaned', 'reserved', 'lost'
  final String? rackId;

  BookItem({
    required this.id,
    required this.bookId,
    required this.barcode,
    this.status = 'available',
    this.rackId,
  });

  factory BookItem.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return BookItem(
      id: doc.id,
      bookId: d['bookId'] ?? '',
      barcode: d['barcode'] ?? '',
      status: d['status'] ?? 'available',
      rackId: d['rackId'],
    );
  }

  Map<String, dynamic> toMap() => {
    'bookId': bookId,
    'barcode': barcode,
    'status': status,
    'rackId': rackId,
  };
}
