import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a borrow request from a member.
///
/// Members submit requests to borrow books, which librarians can approve or reject.
class BorrowRequest {
  /// Unique identifier for the request
  final String id;

  /// Reference to the user who made the request
  final String userId;

  /// Reference to the book being requested
  final String bookId;

  /// Reference to the specific book item (if assigned by librarian)
  final String? itemId;

  /// Date and time when the request was created
  final Timestamp requestedAt;

  /// Current status of the request
  ///
  /// Possible values:
  /// - "pending": Waiting for librarian approval
  /// - "approved": Approved by librarian, book issued
  /// - "rejected": Rejected by librarian
  /// - "cancelled": Cancelled by member
  final String status;

  /// Note from member explaining why they need the book
  final String? memberNote;

  /// Response note from librarian (approval/rejection reason)
  final String? librarianNote;

  /// ID of the librarian who processed the request
  final String? processedBy;

  /// Date and time when the request was processed
  final Timestamp? processedAt;

  /// Creates a new [BorrowRequest] instance.
  BorrowRequest({
    required this.id,
    required this.userId,
    required this.bookId,
    this.itemId,
    required this.requestedAt,
    required this.status,
    this.memberNote,
    this.librarianNote,
    this.processedBy,
    this.processedAt,
  });

  /// Creates a [BorrowRequest] instance from a Firestore document.
  factory BorrowRequest.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return BorrowRequest(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      bookId: data['bookId'] as String? ?? '',
      itemId: data['itemId'] as String?,
      requestedAt: data['requestedAt'] as Timestamp? ?? Timestamp.now(),
      status: data['status'] as String? ?? 'pending',
      memberNote: data['memberNote'] as String?,
      librarianNote: data['librarianNote'] as String?,
      processedBy: data['processedBy'] as String?,
      processedAt: data['processedAt'] as Timestamp?,
    );
  }

  /// Converts the [BorrowRequest] instance to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'bookId': bookId,
      'itemId': itemId,
      'requestedAt': requestedAt,
      'status': status,
      'memberNote': memberNote,
      'librarianNote': librarianNote,
      'processedBy': processedBy,
      'processedAt': processedAt,
    };
  }

  /// Creates a copy of this [BorrowRequest] with the given fields replaced.
  BorrowRequest copyWith({
    String? id,
    String? userId,
    String? bookId,
    String? itemId,
    Timestamp? requestedAt,
    String? status,
    String? memberNote,
    String? librarianNote,
    String? processedBy,
    Timestamp? processedAt,
  }) {
    return BorrowRequest(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      bookId: bookId ?? this.bookId,
      itemId: itemId ?? this.itemId,
      requestedAt: requestedAt ?? this.requestedAt,
      status: status ?? this.status,
      memberNote: memberNote ?? this.memberNote,
      librarianNote: librarianNote ?? this.librarianNote,
      processedBy: processedBy ?? this.processedBy,
      processedAt: processedAt ?? this.processedAt,
    );
  }

  /// Checks if the request is pending.
  bool get isPending => status == 'pending';

  /// Checks if the request is approved.
  bool get isApproved => status == 'approved';

  /// Checks if the request is rejected.
  bool get isRejected => status == 'rejected';

  /// Checks if the request is cancelled.
  bool get isCancelled => status == 'cancelled';

  @override
  String toString() {
    return 'BorrowRequest(id: $id, userId: $userId, bookId: $bookId, '
        'status: $status, requestedAt: ${requestedAt.toDate()})';
  }
}
