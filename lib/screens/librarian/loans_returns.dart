import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../models/loan_model.dart';
import '../../models/book_model.dart';
import '../../models/user_model.dart';
import '../../services/loan_service.dart';

/// Screen for librarians to manage book loans and returns.
///
/// Features:
/// - View all active loans
/// - Process book returns
/// - Issue new loans
/// - View overdue loans
class LoansReturnsScreen extends StatefulWidget {
  const LoansReturnsScreen({super.key});

  @override
  State<LoansReturnsScreen> createState() => _LoansReturnsScreenState();
}

class _LoansReturnsScreenState extends State<LoansReturnsScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final LoanService _loanService = LoanService();

  late TabController _tabController;
  final _searchController = TextEditingController();

  List<Loan> _allLoans = [];
  List<Loan> _filteredLoans = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);
    _loadLoans();
    _searchController.addListener(_filterLoans);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    _filterLoans();
  }

  Future<void> _loadLoans() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final snapshot = await _firestore
          .collection('loans')
          .orderBy('issueDate', descending: true)
          .get();

      final loans = snapshot.docs.map((doc) => Loan.fromDoc(doc)).toList();

      setState(() {
        _allLoans = loans;
        _filterLoans();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  void _filterLoans() {
    final query = _searchController.text.toLowerCase();

    List<Loan> filteredByTab;
    switch (_tabController.index) {
      case 0: // Active
        filteredByTab = _allLoans
            .where(
              (loan) => loan.status == 'borrowed' || loan.status == 'overdue',
            )
            .toList();
        break;
      case 1: // Overdue
        filteredByTab = _allLoans
            .where((loan) => loan.status == 'overdue')
            .toList();
        break;
      case 2: // Returned
        filteredByTab = _allLoans
            .where((loan) => loan.status == 'returned')
            .toList();
        break;
      default:
        filteredByTab = _allLoans;
    }

    if (query.isEmpty) {
      setState(() {
        _filteredLoans = filteredByTab;
      });
      return;
    }

    setState(() {
      _filteredLoans = filteredByTab.where((loan) {
        return loan.bookId.toLowerCase().contains(query) ||
            loan.userId.toLowerCase().contains(query);
      }).toList();
    });
  }

  Future<void> _processReturn(Loan loan) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Return'),
        content: const Text('Process this book return?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _loanService.returnBook(loan.id);
      await _loadLoans();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Book returned successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error processing return: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _showLoanDetails(Loan loan) async {
    // Fetch book and user details
    final bookDoc = await _firestore.collection('books').doc(loan.bookId).get();
    final userDoc = await _firestore.collection('users').doc(loan.userId).get();

    if (!mounted) return;

    final book = bookDoc.exists ? Book.fromDoc(bookDoc) : null;
    final user = userDoc.exists ? AppUser.fromDoc(userDoc) : null;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Loan Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (book != null) ...[
                _buildDetailRow('Book', book.title),
                _buildDetailRow('ISBN', book.isbn),
              ] else
                _buildDetailRow('Book ID', loan.bookId),
              const Divider(height: 24),
              if (user != null) ...[
                _buildDetailRow('Member', user.fullName),
                _buildDetailRow('Email', user.email),
                _buildDetailRow('Card #', user.cardNumber),
              ] else
                _buildDetailRow('User ID', loan.userId),
              const Divider(height: 24),
              _buildDetailRow(
                'Issue Date',
                _formatDate(loan.issueDate.toDate()),
              ),
              _buildDetailRow('Due Date', _formatDate(loan.dueDate.toDate())),
              if (loan.returnDate != null)
                _buildDetailRow(
                  'Return Date',
                  _formatDate(loan.returnDate!.toDate()),
                ),
              _buildDetailRow('Status', _getStatusText(loan.status)),
              if (loan.status == 'overdue')
                _buildDetailRow(
                  'Days Overdue',
                  _calculateOverdueDays(loan).toString(),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          if (loan.status == 'borrowed' && loan.renewCount < 2)
            OutlinedButton(
              onPressed: () {
                Navigator.pop(context);
                _renewLoan(loan);
              },
              child: const Text('Renew'),
            ),
          if (loan.status == 'borrowed' || loan.status == 'overdue')
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _processReturn(loan);
              },
              child: const Text('Process Return'),
            ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 16))),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return DateFormat('dd/MM/yyyy').format(date);
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'borrowed':
        return 'Active';
      case 'overdue':
        return 'Overdue';
      case 'returned':
        return 'Returned';
      default:
        return status;
    }
  }

  int _calculateOverdueDays(Loan loan) {
    final now = DateTime.now();
    final dueDate = loan.dueDate.toDate();
    return now.difference(dueDate).inDays;
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'borrowed':
        return Colors.blue;
      case 'overdue':
        return Colors.red;
      case 'returned':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Future<void> _renewLoan(Loan loan) async {
    if (loan.renewCount >= 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Maximum renewal limit (2) reached'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Renew Loan'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Extend the loan period by 15 days?'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Current due date: ${_formatDate(loan.dueDate.toDate())}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'New due date: ${_formatDate(loan.dueDate.toDate().add(const Duration(days: 15)))}',
                    style: TextStyle(color: Colors.blue[700]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Renewals: ${loan.renewCount} / 2',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Renew'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _loanService.renewLoan(loan.id);
      await _loadLoans();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Loan renewed successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error renewing loan: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showIssueBookDialog() async {
    final memberController = TextEditingController();
    final bookIdController = TextEditingController();
    final itemIdController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Issue Book'),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: memberController,
                  decoration: const InputDecoration(
                    labelText: 'Member Card Number',
                    hintText: 'e.g., LIB-XXXXXXXX',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                  validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: bookIdController,
                  decoration: InputDecoration(
                    labelText: 'Book ID',
                    hintText: 'e.g., 4JF5YK4V',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.book),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.search),
                      tooltip: 'Browse available books',
                      onPressed: () async {
                        final bookId = await _showBookSelector(context);
                        if (bookId != null) {
                          bookIdController.text = bookId;
                        }
                      },
                    ),
                  ),
                  validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: itemIdController,
                  decoration: InputDecoration(
                    labelText: 'Book Item Barcode',
                    hintText: 'e.g., BOOK-4JF5YK4V-010',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.qr_code),
                    helperText: 'Scan or enter the book item barcode',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.list),
                      tooltip: 'Browse available items',
                      onPressed: () async {
                        final bookId = bookIdController.text.trim();
                        if (bookId.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please enter Book ID first'),
                            ),
                          );
                          return;
                        }
                        final barcode = await _showItemSelector(
                          context,
                          bookId,
                        );
                        if (barcode != null) {
                          itemIdController.text = barcode;
                        }
                      },
                    ),
                  ),
                  validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Note:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '• System will verify member can borrow\n'
                        '• Book item must be available\n'
                        '• Due date: 15 days from issue\n'
                        '• Barcode format: BOOK-{bookId}-{itemNumber}',
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context, true);
              }
            },
            child: const Text('Issue Book'),
          ),
        ],
      ),
    );

    if (result == true) {
      await _issueBook(
        memberController.text,
        bookIdController.text,
        itemIdController.text,
      );
    }
  }

  /// Show dialog to select a book and see available items
  Future<String?> _showBookSelector(BuildContext context) async {
    final booksSnapshot = await _firestore
        .collection('books')
        .where('availableCopies', isGreaterThan: 0)
        .get();

    if (booksSnapshot.docs.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No books with available copies')),
        );
      }
      return null;
    }

    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Book'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: booksSnapshot.docs.length,
            itemBuilder: (context, index) {
              final bookDoc = booksSnapshot.docs[index];
              final bookData = bookDoc.data();
              final bookId = bookDoc.id;

              return Card(
                child: ListTile(
                  leading: bookData['coverUrl'] != null
                      ? Image.network(
                          bookData['coverUrl'],
                          width: 40,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(Icons.book),
                        )
                      : const Icon(Icons.book),
                  title: Text(bookData['title'] ?? 'Unknown'),
                  subtitle: Text(
                    'ID: $bookId\n'
                    'Available: ${bookData['availableCopies']}/${bookData['totalCopies']}',
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => Navigator.pop(context, bookId),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  /// Show dialog to select a book item (by barcode)
  Future<String?> _showItemSelector(BuildContext context, String bookId) async {
    final itemsSnapshot = await _firestore
        .collection('bookItems')
        .where('bookId', isEqualTo: bookId)
        .where('status', isEqualTo: 'available')
        .get();

    if (itemsSnapshot.docs.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No available items for this book')),
        );
      }
      return null;
    }

    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Available Item'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: itemsSnapshot.docs.length,
            itemBuilder: (context, index) {
              final itemDoc = itemsSnapshot.docs[index];
              final itemData = itemDoc.data();
              final barcode = itemData['barcode'] ?? 'Unknown';
              final location = itemData['location'] ?? 'Unknown';
              final condition = itemData['condition'] ?? 'Unknown';

              return Card(
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.check_circle, color: Colors.green),
                  ),
                  title: Text(
                    barcode,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text('Location: $location\nCondition: $condition'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => Navigator.pop(context, barcode),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _issueBook(
    String cardNumber,
    String bookId,
    String barcode,
  ) async {
    try {
      // Find user by card number
      final userSnapshot = await _firestore
          .collection('users')
          .where('cardNumber', isEqualTo: cardNumber)
          .limit(1)
          .get();

      if (userSnapshot.docs.isEmpty) {
        throw Exception('Member not found with card number: $cardNumber');
      }

      final userId = userSnapshot.docs.first.id;

      // Find book item by barcode
      final itemSnapshot = await _firestore
          .collection('bookItems')
          .where('barcode', isEqualTo: barcode)
          .limit(1)
          .get();

      if (itemSnapshot.docs.isEmpty) {
        throw Exception('Book item not found with barcode: $barcode');
      }

      final itemId = itemSnapshot.docs.first.id;
      final itemData = itemSnapshot.docs.first.data();

      // Verify book item belongs to the specified book
      if (itemData['bookId'] != bookId) {
        throw Exception(
          'Book item (barcode: $barcode) does not belong to the specified book (ID: $bookId)',
        );
      }

      // Check status
      if (itemData['status'] != 'available') {
        throw Exception(
          'Book item is not available. Current status: ${itemData['status']}',
        );
      }

      // Issue the book
      await _loanService.issueBook(
        userId: userId,
        itemId: itemId,
        bookId: bookId,
      );

      await _loadLoans();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Book issued successfully'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error issuing book: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Loans & Returns'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: _showIssueBookDialog,
            tooltip: 'Issue Book',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadLoans,
            tooltip: 'Refresh',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Active', icon: Icon(Icons.assignment, size: 20)),
            Tab(text: 'Overdue', icon: Icon(Icons.warning, size: 20)),
            Tab(text: 'Returned', icon: Icon(Icons.check_circle, size: 20)),
          ],
        ),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by book ID or user ID',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),

          // Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                ? _buildErrorView()
                : _filteredLoans.isEmpty
                ? _buildEmptyView()
                : _buildLoansList(),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          const Text(
            'Error loading loans',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage!,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[600]),
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
    String message;
    switch (_tabController.index) {
      case 0:
        message = 'No active loans';
        break;
      case 1:
        message = 'No overdue loans';
        break;
      case 2:
        message = 'No returned loans';
        break;
      default:
        message = 'No loans found';
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.assignment_outlined, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoansList() {
    return RefreshIndicator(
      onRefresh: _loadLoans,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _filteredLoans.length,
        itemBuilder: (context, index) {
          final loan = _filteredLoans[index];
          return FutureBuilder<DocumentSnapshot>(
            future: _firestore.collection('books').doc(loan.bookId).get(),
            builder: (context, bookSnapshot) {
              final bookData =
                  bookSnapshot.data?.data() as Map<String, dynamic>?;
              final bookTitle = bookData?['title'] ?? 'Unknown Book';

              return FutureBuilder<DocumentSnapshot>(
                future: _firestore.collection('users').doc(loan.userId).get(),
                builder: (context, userSnapshot) {
                  final userData =
                      userSnapshot.data?.data() as Map<String, dynamic>?;
                  final userName = userData?['fullName'] ?? 'Unknown User';

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: _getStatusColor(
                          loan.status,
                        ).withOpacity(0.2),
                        child: Icon(
                          loan.status == 'returned'
                              ? Icons.check_circle
                              : loan.status == 'overdue'
                              ? Icons.warning
                              : Icons.book,
                          color: _getStatusColor(loan.status),
                        ),
                      ),
                      title: Text(
                        bookTitle,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(userName),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.calendar_today,
                                size: 12,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Due: ${_formatDate(loan.dueDate.toDate())}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: loan.status == 'overdue'
                                      ? Colors.red
                                      : Colors.grey[600],
                                ),
                              ),
                              if (loan.status == 'overdue') ...[
                                const SizedBox(width: 8),
                                Text(
                                  '(${_calculateOverdueDays(loan)} days)',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                      trailing: loan.status != 'returned'
                          ? IconButton(
                              icon: const Icon(Icons.assignment_return),
                              color: Colors.green,
                              onPressed: () => _processReturn(loan),
                              tooltip: 'Process Return',
                            )
                          : Icon(Icons.check, color: Colors.grey[400]),
                      onTap: () => _showLoanDetails(loan),
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
