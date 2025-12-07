import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../models/reservation_model.dart';
import '../../models/book_model.dart';
import '../../models/user_model.dart';
import '../../services/reservation_service.dart';

/// Screen for librarians to manage book reservations.
///
/// Features:
/// - View all reservations (pending, fulfilled, cancelled)
/// - Fulfill reservations when books become available
/// - Cancel reservations
/// - View reservation queue for popular books
class ReservationsScreen extends StatefulWidget {
  const ReservationsScreen({super.key});

  @override
  State<ReservationsScreen> createState() => _ReservationsScreenState();
}

class _ReservationsScreenState extends State<ReservationsScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ReservationService _reservationService = ReservationService();

  late TabController _tabController;
  final _searchController = TextEditingController();

  List<Reservation> _allReservations = [];
  List<Reservation> _filteredReservations = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);
    _loadReservations();
    _searchController.addListener(_filterReservations);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    _filterReservations();
  }

  Future<void> _loadReservations() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final snapshot = await _firestore.collection('reservations').get();

      final reservations = snapshot.docs
          .map((doc) => Reservation.fromDoc(doc))
          .toList();

      // Sort by reservation date (newest first)
      reservations.sort((a, b) => b.reservedAt.compareTo(a.reservedAt));

      setState(() {
        _allReservations = reservations;
        _filterReservations();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  void _filterReservations() {
    final query = _searchController.text.toLowerCase();

    List<Reservation> filteredByTab;
    switch (_tabController.index) {
      case 0: // Pending
        filteredByTab = _allReservations
            .where((r) => r.status == 'pending')
            .toList();
        break;
      case 1: // Fulfilled
        filteredByTab = _allReservations
            .where((r) => r.status == 'fulfilled')
            .toList();
        break;
      case 2: // Cancelled
        filteredByTab = _allReservations
            .where((r) => r.status == 'cancelled')
            .toList();
        break;
      default:
        filteredByTab = _allReservations;
    }

    if (query.isEmpty) {
      setState(() {
        _filteredReservations = filteredByTab;
      });
      return;
    }

    setState(() {
      _filteredReservations = filteredByTab.where((reservation) {
        return reservation.bookId.toLowerCase().contains(query) ||
            reservation.userId.toLowerCase().contains(query);
      }).toList();
    });
  }

  Future<void> _fulfillReservation(Reservation reservation) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Fulfill Reservation'),
        content: const Text(
          'Mark this reservation as fulfilled? The member can now borrow the book.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Fulfill'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _reservationService.fulfillReservation(reservation.id);
      await _loadReservations();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reservation fulfilled successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error fulfilling reservation: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _cancelReservation(Reservation reservation) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Reservation'),
        content: const Text('Cancel this reservation?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Cancel Reservation'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _reservationService.cancelReservation(reservation.id);
      await _loadReservations();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reservation cancelled'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error cancelling reservation: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _showReservationDetails(Reservation reservation) async {
    // Fetch book and user details
    final bookDoc = await _firestore
        .collection('books')
        .doc(reservation.bookId)
        .get();
    final userDoc = await _firestore
        .collection('users')
        .doc(reservation.userId)
        .get();

    if (!mounted) return;

    final book = bookDoc.exists ? Book.fromDoc(bookDoc) : null;
    final user = userDoc.exists ? AppUser.fromDoc(userDoc) : null;

    // Get queue position
    final queueSnapshot = await _firestore
        .collection('reservations')
        .where('bookId', isEqualTo: reservation.bookId)
        .where('status', isEqualTo: 'pending')
        .get();

    final queue = queueSnapshot.docs
        .map((doc) => Reservation.fromDoc(doc))
        .toList();
    queue.sort((a, b) => a.reservedAt.compareTo(b.reservedAt));

    final queuePosition = queue.indexWhere((r) => r.id == reservation.id) + 1;

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reservation Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (book != null) ...[
                _buildDetailRow('Book', book.title),
                _buildDetailRow('ISBN', book.isbn),
                _buildDetailRow('Author', book.authors.join(', ')),
              ] else
                _buildDetailRow('Book ID', reservation.bookId),
              const Divider(height: 24),
              if (user != null) ...[
                _buildDetailRow('Member', user.fullName),
                _buildDetailRow('Email', user.email),
                _buildDetailRow('Card #', user.cardNumber),
              ] else
                _buildDetailRow('User ID', reservation.userId),
              const Divider(height: 24),
              _buildDetailRow(
                'Reserved On',
                _formatDate(reservation.reservedAt.toDate()),
              ),
              _buildDetailRow('Status', _getStatusText(reservation.status)),
              if (reservation.status == 'pending' && queuePosition > 0)
                _buildDetailRow('Queue Position', '#$queuePosition'),
            ],
          ),
        ),
        actions: [
          if (reservation.status != 'pending')
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _removeReservation(reservation);
              },
              child: const Text('Remove', style: TextStyle(color: Colors.red)),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          if (reservation.status == 'pending') ...[
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _cancelReservation(reservation);
              },
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.orange),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _fulfillReservation(reservation);
              },
              child: const Text('Fulfill'),
            ),
          ],
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
            width: 110,
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
      case 'pending':
        return 'Pending';
      case 'fulfilled':
        return 'Fulfilled';
      case 'cancelled':
        return 'Cancelled';
      case 'expired':
        return 'Expired';
      default:
        return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'fulfilled':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      case 'expired':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'pending':
        return Icons.hourglass_empty;
      case 'fulfilled':
        return Icons.check_circle;
      case 'cancelled':
        return Icons.cancel;
      case 'expired':
        return Icons.event_busy;
      default:
        return Icons.bookmark;
    }
  }

  Future<void> _showCreateReservationDialog() async {
    final memberController = TextEditingController();
    final bookIdController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Reservation'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: memberController,
                decoration: const InputDecoration(
                  labelText: 'Member Card Number',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: bookIdController,
                decoration: const InputDecoration(
                  labelText: 'Book ID',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.book),
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
                child: const Text(
                  'Reserve a book for a member when it\'s currently unavailable. '
                  'The member will be notified when the book becomes available.',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
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
            child: const Text('Create Reservation'),
          ),
        ],
      ),
    );

    if (result == true) {
      await _createReservation(memberController.text, bookIdController.text);
    }
  }

  Future<void> _createReservation(String cardNumber, String bookId) async {
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

      // Create reservation
      await _reservationService.reserveBook(userId, bookId);

      await _loadReservations();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reservation created successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _removeReservation(Reservation reservation) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Reservation'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Permanently delete this reservation?'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning, color: Colors.red[700], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This action cannot be undone',
                      style: TextStyle(
                        color: Colors.red[700],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _firestore.collection('reservations').doc(reservation.id).delete();
      await _loadReservations();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reservation removed'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reservations'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: _showCreateReservationDialog,
            tooltip: 'Create Reservation',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadReservations,
            tooltip: 'Refresh',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Pending', icon: Icon(Icons.hourglass_empty, size: 20)),
            Tab(text: 'Fulfilled', icon: Icon(Icons.check_circle, size: 20)),
            Tab(text: 'Cancelled', icon: Icon(Icons.cancel, size: 20)),
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
                : _filteredReservations.isEmpty
                ? _buildEmptyView()
                : _buildReservationsList(),
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
            'Error loading reservations',
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
            onPressed: _loadReservations,
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
        message = 'No pending reservations';
        break;
      case 1:
        message = 'No fulfilled reservations';
        break;
      case 2:
        message = 'No cancelled reservations';
        break;
      default:
        message = 'No reservations found';
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bookmark_border, size: 80, color: Colors.grey[400]),
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

  Widget _buildReservationsList() {
    return RefreshIndicator(
      onRefresh: _loadReservations,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _filteredReservations.length,
        itemBuilder: (context, index) {
          final reservation = _filteredReservations[index];
          return FutureBuilder<DocumentSnapshot>(
            future: _firestore
                .collection('books')
                .doc(reservation.bookId)
                .get(),
            builder: (context, bookSnapshot) {
              final bookData =
                  bookSnapshot.data?.data() as Map<String, dynamic>?;
              final bookTitle = bookData?['title'] ?? 'Unknown Book';

              return FutureBuilder<DocumentSnapshot>(
                future: _firestore
                    .collection('users')
                    .doc(reservation.userId)
                    .get(),
                builder: (context, userSnapshot) {
                  final userData =
                      userSnapshot.data?.data() as Map<String, dynamic>?;
                  final userName = userData?['fullName'] ?? 'Unknown User';

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: _getStatusColor(
                          reservation.status,
                        ).withOpacity(0.2),
                        child: Icon(
                          _getStatusIcon(reservation.status),
                          color: _getStatusColor(reservation.status),
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
                                _formatDate(reservation.reservedAt.toDate()),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: _getStatusColor(
                                    reservation.status,
                                  ).withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  _getStatusText(reservation.status),
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: _getStatusColor(reservation.status),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      trailing: reservation.status == 'pending'
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.cancel),
                                  color: Colors.red,
                                  onPressed: () =>
                                      _cancelReservation(reservation),
                                  tooltip: 'Cancel',
                                ),
                                IconButton(
                                  icon: const Icon(Icons.check_circle),
                                  color: Colors.green,
                                  onPressed: () =>
                                      _fulfillReservation(reservation),
                                  tooltip: 'Fulfill',
                                ),
                              ],
                            )
                          : Icon(
                              _getStatusIcon(reservation.status),
                              color: Colors.grey[400],
                            ),
                      onTap: () => _showReservationDetails(reservation),
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
