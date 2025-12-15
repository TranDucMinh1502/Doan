import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../models/loan_model.dart';
import '../../models/book_model.dart';
import '../../models/user_model.dart';

/// Screen for managing fines and overdue books.
///
/// Features:
/// - View all loans with fines
/// - View overdue loans
/// - Collect fines (mark as paid)
/// - View fine history
class FinesManagementScreen extends StatefulWidget {
  const FinesManagementScreen({super.key});

  @override
  State<FinesManagementScreen> createState() => _FinesManagementScreenState();
}

class _FinesManagementScreenState extends State<FinesManagementScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late TabController _tabController;
  final _searchController = TextEditingController();

  List<Loan> _allLoans = [];
  List<Loan> _filteredLoans = [];
  bool _isLoading = true;
  String? _errorMessage;
  double _totalFines = 0;
  double _collectedFines = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_filterLoans);
    _loadLoans();
    _searchController.addListener(_filterLoans);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadLoans() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Load all loans with fines (overdue status)
      final snapshot = await _firestore
          .collection('loans')
          .where('status', isEqualTo: 'overdue')
          .orderBy('dueDate', descending: false)
          .get();

      final loans = snapshot.docs.map((doc) => Loan.fromDoc(doc)).toList();

      // Calculate statistics
      double total = 0;
      double collected = 0;

      for (var loan in loans) {
        total += loan.fine;
        if (loan.finePaid == true) {
          collected += loan.fine;
        }
      }

      setState(() {
        _allLoans = loans;
        _totalFines = total;
        _collectedFines = collected;
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
    final currentTab = _tabController.index;

    setState(() {
      _filteredLoans = _allLoans.where((loan) {
        // Filter by tab
        final matchesTab = currentTab == 0
            ? (loan.finePaid != true) // Unpaid
            : (loan.finePaid == true); // Paid

        // Filter by search
        if (query.isEmpty) return matchesTab;

        return matchesTab &&
            (loan.userId.toLowerCase().contains(query) ||
                loan.bookId.toLowerCase().contains(query));
      }).toList();
    });
  }

  Future<void> _markFinePaid(Loan loan) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Collect Fine'),
        content: Text(
          'Confirm fine payment of \$${loan.fine.toStringAsFixed(2)}?\n\n'
          'This will mark the fine as paid.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Collect'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _firestore.collection('loans').doc(loan.id).update({
        'finePaid': true,
        'finePaidAt': Timestamp.now(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Fine marked as paid successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        _loadLoans();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
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

    final daysOverdue = DateTime.now().difference(loan.dueDate.toDate()).inDays;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Fine Details'),
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
              _buildDetailRow('Due Date', _formatDate(loan.dueDate.toDate())),
              if (loan.returnDate != null)
                _buildDetailRow(
                  'Return Date',
                  _formatDate(loan.returnDate!.toDate()),
                ),
              _buildDetailRow('Days Overdue', '$daysOverdue days'),
              _buildDetailRow(
                'Fine Amount',
                '\$${loan.fine.toStringAsFixed(2)}',
                valueStyle: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.red,
                ),
              ),
              if (loan.finePaid == true) ...[
                const Divider(height: 24),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Fine Paid',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                            if (loan.finePaidAt != null)
                              Text(
                                'On ${_formatDate(loan.finePaidAt!.toDate())}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.green[700],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          if (loan.finePaid != true)
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _markFinePaid(loan);
              },
              icon: const Icon(Icons.payment),
              label: const Text('Collect Fine'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {TextStyle? valueStyle}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: valueStyle ?? const TextStyle(fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fines Management'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Unpaid'),
            Tab(text: 'Paid'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Statistics Cards
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[50],
            child: Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Total Fines',
                    '\$${_totalFines.toStringAsFixed(2)}',
                    Icons.attach_money,
                    Colors.red,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    'Collected',
                    '\$${_collectedFines.toStringAsFixed(2)}',
                    Icons.check_circle,
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    'Outstanding',
                    '\$${(_totalFines - _collectedFines).toStringAsFixed(2)}',
                    Icons.warning,
                    Colors.orange,
                  ),
                ),
              ],
            ),
          ),

          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by user ID or book ID...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
          ),

          // Loans List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error, size: 60, color: Colors.red),
                        const SizedBox(height: 16),
                        Text(_errorMessage!),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadLoans,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                : _filteredLoans.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _tabController.index == 0
                              ? Icons.check_circle_outline
                              : Icons.payment,
                          size: 80,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _tabController.index == 0
                              ? 'No unpaid fines'
                              : 'No paid fines yet',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadLoans,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _filteredLoans.length,
                      itemBuilder: (context, index) {
                        final loan = _filteredLoans[index];
                        return _buildLoanCard(loan);
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildLoanCard(Loan loan) {
    final daysOverdue = DateTime.now().difference(loan.dueDate.toDate()).inDays;
    final isPaid = loan.finePaid == true;

    return FutureBuilder<Map<String, dynamic>>(
      future: _fetchLoanDetails(loan),
      builder: (context, snapshot) {
        final book = snapshot.data?['book'] as Book?;
        final user = snapshot.data?['user'] as AppUser?;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            onTap: () => _showLoanDetails(loan),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Book thumbnail
                      if (book?.coverUrl != null && book!.coverUrl.isNotEmpty)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            book.coverUrl,
                            width: 50,
                            height: 70,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                const Icon(Icons.book, size: 50),
                          ),
                        )
                      else
                        const Icon(Icons.book, size: 50),
                      const SizedBox(width: 12),

                      // Loan info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              book?.title ?? 'Loading...',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              user?.fullName ?? 'Loading...',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$daysOverdue days overdue',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.red,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Fine amount
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '\$${loan.fine.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isPaid ? Colors.green : Colors.red,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: isPaid ? Colors.green[50] : Colors.red[50],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isPaid ? Colors.green : Colors.red,
                              ),
                            ),
                            child: Text(
                              isPaid ? 'Paid' : 'Unpaid',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isPaid ? Colors.green : Colors.red,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (!isPaid) ...[
                    const Divider(height: 16),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton.icon(
                        onPressed: () => _markFinePaid(loan),
                        icon: const Icon(Icons.payment, size: 16),
                        label: const Text('Collect Fine'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<Map<String, dynamic>> _fetchLoanDetails(Loan loan) async {
    try {
      final results = await Future.wait([
        _firestore.collection('books').doc(loan.bookId).get(),
        _firestore.collection('users').doc(loan.userId).get(),
      ]);

      return {
        'book': results[0].exists ? Book.fromDoc(results[0]) : null,
        'user': results[1].exists ? AppUser.fromDoc(results[1]) : null,
      };
    } catch (e) {
      return {};
    }
  }

  String _formatDate(DateTime date) {
    return DateFormat('MMM dd, yyyy').format(date);
  }
}
