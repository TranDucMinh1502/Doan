import 'package:flutter/material.dart';
import '../../models/loan_model.dart';
import '../../models/book_model.dart';
import '../../services/loan_service.dart';
import '../../services/book_service.dart';
import '../../services/auth_service.dart';

/// Screen displaying the current user's active loans.
///
/// Shows borrowed and overdue books with options to return or renew.
class MyLoansScreen extends StatefulWidget {
  const MyLoansScreen({Key? key}) : super(key: key);

  @override
  State<MyLoansScreen> createState() => _MyLoansScreenState();
}

class _MyLoansScreenState extends State<MyLoansScreen> {
  final LoanService _loanService = LoanService();
  final BookService _bookService = BookService();
  final AuthService _authService = AuthService();

  List<LoanWithBook> _loansWithBooks = [];
  bool _isLoading = true;
  String? _errorMessage;
  String? _processingLoanId;

  @override
  void initState() {
    super.initState();
    _loadLoans();
  }

  Future<void> _loadLoans() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Get current user
      final currentUser = await _authService.getCurrentUserProfile();

      if (currentUser == null) {
        setState(() {
          _errorMessage = 'Please sign in to view your loans';
          _isLoading = false;
        });
        return;
      }

      // Get user's active loans
      final loans = await _loanService.getUserActiveLoans(currentUser.uid);

      // Fetch book details for each loan
      final loansWithBooks = <LoanWithBook>[];
      for (final loan in loans) {
        final book = await _bookService.getBookById(loan.bookId);
        if (book != null) {
          loansWithBooks.add(LoanWithBook(loan: loan, book: book));
        }
      }

      setState(() {
        _loansWithBooks = loansWithBooks;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _handleReturn(Loan loan) async {
    // Confirm return
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Return Book'),
        content: const Text('Are you sure you want to return this book?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Return'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _processingLoanId = loan.id);

    try {
      await _loanService.returnBook(loan.id);

      if (mounted) {
        _showMessage('Book returned successfully!');
        _loadLoans(); // Reload loans
      }
    } catch (e) {
      if (mounted) {
        _showMessage('Error: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _processingLoanId = null);
      }
    }
  }

  Future<void> _handleRenew(Loan loan) async {
    // Check renew limit
    if (loan.renewCount >= 2) {
      _showMessage('Đã đạt giới hạn gia hạn tối đa (2 lần)');
      return;
    }

    // Calculate new due date
    final currentDueDate = loan.dueDate.toDate();
    final newDueDate = currentDueDate.add(const Duration(days: 15));
    final remainingRenewals = 2 - loan.renewCount - 1;

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.update, color: Colors.blue[700]),
            const SizedBox(width: 8),
            const Text('Gia hạn sách'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Bạn muốn gia hạn thêm 15 ngày?',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 16,
                          color: Colors.blue[700],
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Thông tin gia hạn:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildInfoRow(
                      'Hạn trả hiện tại:',
                      _formatDate(currentDueDate),
                      Icons.event,
                    ),
                    const SizedBox(height: 8),
                    _buildInfoRow(
                      'Hạn trả mới:',
                      _formatDate(newDueDate),
                      Icons.event_available,
                      highlight: true,
                    ),
                    const SizedBox(height: 8),
                    _buildInfoRow(
                      'Số lần gia hạn đã dùng:',
                      '${loan.renewCount} / 2',
                      Icons.repeat,
                    ),
                    const SizedBox(height: 8),
                    _buildInfoRow(
                      'Còn lại sau khi gia hạn:',
                      '$remainingRenewals lần',
                      Icons.info_outline,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.warning_amber,
                      color: Colors.orange[700],
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        remainingRenewals == 0
                            ? 'Đây là lần gia hạn cuối cùng của bạn.'
                            : 'Bạn còn $remainingRenewals lần gia hạn sau này.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange[900],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.check),
            label: const Text('Xác nhận gia hạn'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _processingLoanId = loan.id);

    try {
      await _loanService.renewLoan(loan.id);

      if (mounted) {
        _showMessage('Gia hạn thành công! Hạn mới: ${_formatDate(newDueDate)}');
        _loadLoans(); // Reload loans
      }
    } catch (e) {
      if (mounted) {
        String errorMsg = e.toString();
        if (errorMsg.contains('Maximum renewal limit')) {
          _showMessage('Đã đạt giới hạn gia hạn tối đa');
        } else if (errorMsg.contains('permission') ||
            errorMsg.contains('PERMISSION_DENIED')) {
          _showMessage(
            'Lỗi quyền truy cập. Vui lòng kiểm tra Firestore rules.',
          );
        } else {
          _showMessage('Lỗi: $errorMsg');
        }
      }
    } finally {
      if (mounted) {
        setState(() => _processingLoanId = null);
      }
    }
  }

  Widget _buildInfoRow(
    String label,
    String value,
    IconData icon, {
    bool highlight = false,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 14,
          color: highlight ? Colors.green[700] : Colors.grey[600],
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey[700]),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: highlight ? FontWeight.bold : FontWeight.w600,
            color: highlight ? Colors.green[700] : Colors.black87,
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      'Th1',
      'Th2',
      'Th3',
      'Th4',
      'Th5',
      'Th6',
      'Th7',
      'Th8',
      'Th9',
      'Th10',
      'Th11',
      'Th12',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Loans'),
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadLoans,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? _buildErrorView()
          : _loansWithBooks.isEmpty
          ? _buildEmptyView()
          : _buildLoansList(),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            _errorMessage!,
            style: const TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _loadLoans,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.library_books_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No Active Loans',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'You don\'t have any borrowed books',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildLoansList() {
    return RefreshIndicator(
      onRefresh: _loadLoans,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _loansWithBooks.length,
        itemBuilder: (context, index) {
          final loanWithBook = _loansWithBooks[index];
          return _buildLoanCard(loanWithBook);
        },
      ),
    );
  }

  Widget _buildLoanCard(LoanWithBook loanWithBook) {
    final loan = loanWithBook.loan;
    final book = loanWithBook.book;
    final isOverdue = loan.isOverdue;
    final isProcessing = _processingLoanId == loan.id;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isOverdue
            ? const BorderSide(color: Colors.red, width: 2)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Book info header
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Book cover thumbnail
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: book.coverUrl.isNotEmpty
                      ? Image.network(
                          book.coverUrl,
                          width: 60,
                          height: 90,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return _buildPlaceholderCover();
                          },
                        )
                      : _buildPlaceholderCover(),
                ),
                const SizedBox(width: 12),

                // Book title and authors
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
                        style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isOverdue ? Colors.red[50] : Colors.blue[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isOverdue ? Colors.red : Colors.blue,
                      width: 1.5,
                    ),
                  ),
                  child: Text(
                    loan.status.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isOverdue ? Colors.red[700] : Colors.blue[700],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 12),

            // Loan details
            _buildDetailRow(
              Icons.calendar_today,
              'Issue Date',
              _formatDate(loan.issueDate.toDate()),
            ),
            const SizedBox(height: 8),
            _buildDetailRow(
              Icons.event,
              'Due Date',
              _formatDate(loan.dueDate.toDate()),
            ),

            // Days remaining/overdue
            const SizedBox(height: 8),
            _buildDaysIndicator(loan),

            // Renew count and remaining renewals
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.repeat, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Số lần gia hạn',
                    style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: loan.renewCount >= 2
                        ? Colors.red[50]
                        : loan.renewCount > 0
                        ? Colors.orange[50]
                        : Colors.green[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: loan.renewCount >= 2
                          ? Colors.red
                          : loan.renewCount > 0
                          ? Colors.orange
                          : Colors.green,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${loan.renewCount} / 2',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: loan.renewCount >= 2
                              ? Colors.red[700]
                              : loan.renewCount > 0
                              ? Colors.orange[700]
                              : Colors.green[700],
                        ),
                      ),
                      if (loan.renewCount < 2) ...[
                        const SizedBox(width: 4),
                        Text(
                          '(Còn ${2 - loan.renewCount})',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),

            // Fine (if overdue)
            if (loan.hasFine) ...[
              const SizedBox(height: 8),
              _buildDetailRow(
                Icons.payment,
                'Fine',
                '\$${loan.fine.toStringAsFixed(2)}',
                valueColor: Colors.red[700],
              ),
            ],

            const SizedBox(height: 16),

            // Action buttons
            Row(
              children: [
                // Return button
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: isProcessing ? null : () => _handleReturn(loan),
                    icon: isProcessing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.keyboard_return, size: 18),
                    label: const Text('Return'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),

                // Renew button (if eligible)
                if (loan.renewCount < 2) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: isProcessing ? null : () => _handleRenew(loan),
                      icon: const Icon(Icons.update, size: 18),
                      label: const Text('Renew'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholderCover() {
    return Container(
      width: 60,
      height: 90,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(Icons.book, size: 30, color: Colors.grey[600]),
    );
  }

  Widget _buildDetailRow(
    IconData icon,
    String label,
    String value, {
    Color? valueColor,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(fontSize: 14, color: Colors.grey[700]),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: valueColor ?? Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildDaysIndicator(Loan loan) {
    final daysUntilDue = loan.daysUntilDue;
    final isOverdue = daysUntilDue < 0;
    final absDay = daysUntilDue.abs();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isOverdue
            ? Colors.red[50]
            : daysUntilDue <= 3
            ? Colors.orange[50]
            : Colors.green[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            isOverdue
                ? Icons.warning
                : daysUntilDue <= 3
                ? Icons.schedule
                : Icons.check_circle,
            size: 16,
            color: isOverdue
                ? Colors.red[700]
                : daysUntilDue <= 3
                ? Colors.orange[700]
                : Colors.green[700],
          ),
          const SizedBox(width: 8),
          Text(
            isOverdue
                ? 'Overdue by $absDay day${absDay != 1 ? 's' : ''}'
                : 'Due in $daysUntilDue day${daysUntilDue != 1 ? 's' : ''}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isOverdue
                  ? Colors.red[700]
                  : daysUntilDue <= 3
                  ? Colors.orange[700]
                  : Colors.green[700],
            ),
          ),
        ],
      ),
    );
  }
}

/// Helper class to combine loan and book data
class LoanWithBook {
  final Loan loan;
  final Book book;

  LoanWithBook({required this.loan, required this.book});
}
