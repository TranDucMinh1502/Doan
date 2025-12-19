import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/book.dart';

class LoanHistoryScreen extends StatelessWidget {
  final String userId;

  const LoanHistoryScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('Lịch sử mượn sách'),
        centerTitle: true,
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('loans')
            .where('userId', isEqualTo: userId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 60, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Lỗi: ${snapshot.error}'),
                ],
              ),
            );
          }

          final loans = snapshot.data!.docs;

          // Sort by issue date (newest first)
          loans.sort((a, b) {
            final aDate =
                (a.data() as Map<String, dynamic>)['issueDate'] as Timestamp;
            final bDate =
                (b.data() as Map<String, dynamic>)['issueDate'] as Timestamp;
            return bDate.compareTo(aDate);
          });

          if (loans.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 100, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    'Chưa có lịch sử mượn sách',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Lịch sử của bạn sẽ hiển thị ở đây',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: loans.length,
            itemBuilder: (context, index) {
              final loanDoc = loans[index];
              final loan = loanDoc.data() as Map<String, dynamic>;
              final bookId = loan['bookId'] as String;
              final issueDate = (loan['issueDate'] as Timestamp).toDate();
              final dueDate = (loan['dueDate'] as Timestamp).toDate();
              final status = loan['status'] as String;
              final returnDate = loan['returnDate'] != null
                  ? (loan['returnDate'] as Timestamp).toDate()
                  : null;
              final fine = (loan['fine'] ?? 0) as num;

              // Determine status info
              String statusText;
              Color statusColor;
              IconData statusIcon;

              if (status == 'returned') {
                final isLate =
                    returnDate != null && returnDate.isAfter(dueDate);
                statusText = isLate ? 'Trả muộn' : 'Đã trả';
                statusColor = isLate ? Colors.orange : Colors.green;
                statusIcon = isLate ? Icons.schedule : Icons.check_circle;
              } else if (status == 'issued') {
                final isOverdue = DateTime.now().isAfter(dueDate);
                statusText = isOverdue ? 'Quá hạn' : 'Đang mượn';
                statusColor = isOverdue ? Colors.red : Colors.blue;
                statusIcon = isOverdue ? Icons.warning : Icons.book;
              } else {
                statusText = 'Khác';
                statusColor = Colors.grey;
                statusIcon = Icons.help_outline;
              }

              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('books')
                    .doc(bookId)
                    .get(),
                builder: (context, bookSnapshot) {
                  if (!bookSnapshot.hasData) {
                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: Container(
                        height: 120,
                        padding: const EdgeInsets.all(16),
                        child: const Center(child: CircularProgressIndicator()),
                      ),
                    );
                  }

                  if (!bookSnapshot.data!.exists) {
                    return const SizedBox.shrink();
                  }

                  final book = Book.fromDoc(bookSnapshot.data!);

                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Book cover
                          Container(
                            width: 70,
                            height: 100,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child:
                                  book.coverImageUrl != null &&
                                      book.coverImageUrl!.isNotEmpty
                                  ? Image.network(
                                      book.coverImageUrl!,
                                      fit: BoxFit.cover,
                                      loadingBuilder:
                                          (context, child, loadingProgress) {
                                            if (loadingProgress == null) {
                                              return child;
                                            }
                                            return Center(
                                              child: CircularProgressIndicator(
                                                value:
                                                    loadingProgress
                                                            .expectedTotalBytes !=
                                                        null
                                                    ? loadingProgress
                                                              .cumulativeBytesLoaded /
                                                          loadingProgress
                                                              .expectedTotalBytes!
                                                    : null,
                                              ),
                                            );
                                          },
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                            return Icon(
                                              Icons.book,
                                              size: 40,
                                              color: Colors.grey.shade600,
                                            );
                                          },
                                    )
                                  : Icon(
                                      Icons.book,
                                      size: 40,
                                      color: Colors.grey.shade600,
                                    ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Book info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  book.title,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  book.authors.join(', '),
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade700,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 8),
                                // Status badge
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Color.fromRGBO(
                                      (statusColor.toARGB32() >> 16) & 0xFF,
                                      (statusColor.toARGB32() >> 8) & 0xFF,
                                      statusColor.toARGB32() & 0xFF,
                                      0.1,
                                    ),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: Color.fromRGBO(
                                        (statusColor.toARGB32() >> 16) & 0xFF,
                                        (statusColor.toARGB32() >> 8) & 0xFF,
                                        statusColor.toARGB32() & 0xFF,
                                        0.3,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        statusIcon,
                                        size: 14,
                                        color: statusColor,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        statusText,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: statusColor,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                // Dates
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Ngày mượn: ${issueDate.day}/${issueDate.month}/${issueDate.year}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Hạn trả: ${dueDate.day}/${dueDate.month}/${dueDate.year}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                    if (returnDate != null) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        'Đã trả: ${returnDate.day}/${returnDate.month}/${returnDate.year}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                    if (fine > 0) ...[
                                      const SizedBox(height: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.red.shade50,
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                          border: Border.all(
                                            color: Colors.red.shade200,
                                          ),
                                        ),
                                        child: Text(
                                          'Phí phạt: ${fine.toStringAsFixed(0)}đ',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.red.shade900,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
