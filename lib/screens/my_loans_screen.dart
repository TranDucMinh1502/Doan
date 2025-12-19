import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/loan.dart';
import '../services/firestore_service.dart';

class MyLoansScreen extends StatelessWidget {
  final String userId;

  const MyLoansScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    final service = FirestoreService();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('loans')
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'issued')
          .snapshots(),
      builder: (context, snapshot) {
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
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final loans = snapshot.data!.docs
            .map((doc) => Loan.fromDoc(doc))
            .toList();

        // Sort by due date in code instead of query
        loans.sort((a, b) => a.dueDate.compareTo(b.dueDate));

        if (loans.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.library_books_outlined,
                  size: 100,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  'Chưa có sách đang mượn',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Hãy khám phá và mượn sách bạn thích',
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
            final loan = loans[index];
            final dueDate = loan.dueDate.toDate();
            final isOverdue = DateTime.now().isAfter(dueDate);
            final daysRemaining = dueDate.difference(DateTime.now()).inDays;

            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('books')
                  .doc(loan.bookId)
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

                final bookData =
                    bookSnapshot.data!.data() as Map<String, dynamic>;
                final title = bookData['title'] ?? 'Unknown';
                final authors =
                    (bookData['authors'] as List<dynamic>?)?.join(', ') ?? '';
                final coverUrl =
                    bookData['coverUrl'] ?? bookData['coverImageUrl'];

                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: isOverdue
                        ? BorderSide(color: Colors.red.shade300, width: 2)
                        : BorderSide.none,
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
                            child: coverUrl != null && coverUrl.isNotEmpty
                                ? Image.network(
                                    coverUrl,
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
                                    errorBuilder: (context, error, stackTrace) {
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
                                title,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (authors.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  authors,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade700,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                              const SizedBox(height: 8),
                              // Due date badge
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: isOverdue
                                      ? Colors.red.shade50
                                      : Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: isOverdue
                                        ? Colors.red.shade300
                                        : Colors.blue.shade200,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      isOverdue
                                          ? Icons.warning
                                          : Icons.schedule,
                                      size: 14,
                                      color: isOverdue
                                          ? Colors.red.shade700
                                          : Colors.blue.shade700,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      isOverdue
                                          ? 'Quá hạn ${daysRemaining.abs()} ngày'
                                          : 'Còn $daysRemaining ngày',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isOverdue
                                            ? Colors.red.shade900
                                            : Colors.blue.shade900,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Hạn trả: ${dueDate.day}/${dueDate.month}/${dueDate.year}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              // Return button
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Text('Trả sách'),
                                        content: Text(
                                          'Bạn có chắc muốn trả sách "$title"?',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context, false),
                                            child: const Text('Hủy'),
                                          ),
                                          ElevatedButton(
                                            onPressed: () =>
                                                Navigator.pop(context, true),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.green,
                                              foregroundColor: Colors.white,
                                            ),
                                            child: const Text('Trả sách'),
                                          ),
                                        ],
                                      ),
                                    );

                                    if (confirm == true && context.mounted) {
                                      try {
                                        // Show loading
                                        showDialog(
                                          context: context,
                                          barrierDismissible: false,
                                          builder: (context) => const Center(
                                            child: Card(
                                              child: Padding(
                                                padding: EdgeInsets.all(20),
                                                child: Column(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    CircularProgressIndicator(),
                                                    SizedBox(height: 16),
                                                    Text('Đang xử lý...'),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        );

                                        await service.returnBook(
                                          loanId: loan.id,
                                        );

                                        if (context.mounted) {
                                          Navigator.pop(
                                            context,
                                          ); // Close loading
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Row(
                                                children: [
                                                  Icon(
                                                    Icons.check_circle,
                                                    color: Colors.white,
                                                  ),
                                                  SizedBox(width: 12),
                                                  Text(
                                                    '✓ Trả sách thành công!',
                                                  ),
                                                ],
                                              ),
                                              backgroundColor: Colors.green,
                                              behavior:
                                                  SnackBarBehavior.floating,
                                            ),
                                          );
                                        }
                                      } catch (e) {
                                        if (context.mounted) {
                                          Navigator.pop(
                                            context,
                                          ); // Close loading
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Row(
                                                children: [
                                                  const Icon(
                                                    Icons.error_outline,
                                                    color: Colors.white,
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Expanded(
                                                    child: Text('Lỗi: $e'),
                                                  ),
                                                ],
                                              ),
                                              backgroundColor: Colors.red,
                                              behavior:
                                                  SnackBarBehavior.floating,
                                            ),
                                          );
                                        }
                                      }
                                    }
                                  },
                                  icon: const Icon(
                                    Icons.assignment_return,
                                    size: 18,
                                  ),
                                  label: const Text('Trả sách'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 8,
                                    ),
                                  ),
                                ),
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
    );
  }
}
