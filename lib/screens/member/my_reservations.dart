import 'package:flutter/material.dart';
import '../../models/reservation_model.dart';
import '../../models/book_model.dart';
import '../../services/reservation_service.dart';
import '../../services/book_service.dart';
import '../../services/auth_service.dart';

/// Screen displaying the current user's book reservations.
///
/// Shows waiting, notified, and canceled reservations with cancel option.
class MyReservationsScreen extends StatefulWidget {
  const MyReservationsScreen({Key? key}) : super(key: key);

  @override
  State<MyReservationsScreen> createState() => _MyReservationsScreenState();
}

class _MyReservationsScreenState extends State<MyReservationsScreen> {
  final ReservationService _reservationService = ReservationService();
  final BookService _bookService = BookService();
  final AuthService _authService = AuthService();

  List<ReservationWithBook> _reservationsWithBooks = [];
  bool _isLoading = true;
  String? _errorMessage;
  String? _processingReservationId;

  @override
  void initState() {
    super.initState();
    _loadReservations();
  }

  Future<void> _loadReservations() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Get current user
      final currentUser = await _authService.getCurrentUserProfile();

      if (currentUser == null) {
        setState(() {
          _errorMessage = 'Please sign in to view your reservations';
          _isLoading = false;
        });
        return;
      }

      // Get user's reservations
      final reservations = await _reservationService.getUserReservations(
        currentUser.uid,
      );

      // Fetch book details for each reservation
      final reservationsWithBooks = <ReservationWithBook>[];
      for (final reservation in reservations) {
        final book = await _bookService.getBookById(reservation.bookId);
        if (book != null) {
          reservationsWithBooks.add(
            ReservationWithBook(reservation: reservation, book: book),
          );
        }
      }

      setState(() {
        _reservationsWithBooks = reservationsWithBooks;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _handleCancel(Reservation reservation) async {
    // Confirm cancel
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Reservation'),
        content: const Text(
          'Are you sure you want to cancel this reservation?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _processingReservationId = reservation.id);

    try {
      await _reservationService.cancelReservation(reservation.id);

      if (mounted) {
        _showMessage('Reservation canceled successfully!');
        _loadReservations(); // Reload reservations
      }
    } catch (e) {
      if (mounted) {
        _showMessage('Error: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _processingReservationId = null);
      }
    }
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
        title: const Text('My Reservations'),
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadReservations,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? _buildErrorView()
          : _reservationsWithBooks.isEmpty
          ? _buildEmptyView()
          : _buildReservationsList(),
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
            onPressed: _loadReservations,
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
          Icon(Icons.bookmark_border, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No Reservations',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'You don\'t have any book reservations',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildReservationsList() {
    return RefreshIndicator(
      onRefresh: _loadReservations,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _reservationsWithBooks.length,
        itemBuilder: (context, index) {
          final reservationWithBook = _reservationsWithBooks[index];
          return _buildReservationCard(reservationWithBook);
        },
      ),
    );
  }

  Widget _buildReservationCard(ReservationWithBook reservationWithBook) {
    final reservation = reservationWithBook.reservation;
    final book = reservationWithBook.book;
    final isProcessing = _processingReservationId == reservation.id;
    final canCancel =
        reservation.status == 'waiting' || reservation.status == 'notified';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                _buildStatusBadge(reservation.status),
              ],
            ),

            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 12),

            // Reservation details
            _buildDetailRow(
              Icons.calendar_today,
              'Reserved on',
              _formatDate(reservation.reservedAt.toDate()),
            ),

            const SizedBox(height: 8),
            _buildDetailRow(
              Icons.info_outline,
              'Status',
              _getStatusText(reservation.status),
            ),

            // Cancel button (if eligible)
            if (canCancel) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: isProcessing
                      ? null
                      : () => _handleCancel(reservation),
                  icon: isProcessing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.cancel_outlined, size: 18),
                  label: const Text('Cancel Reservation'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
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

  Widget _buildStatusBadge(String status) {
    Color backgroundColor;
    Color borderColor;
    Color textColor;

    switch (status) {
      case 'waiting':
        backgroundColor = Colors.orange[50]!;
        borderColor = Colors.orange;
        textColor = Colors.orange[700]!;
        break;
      case 'notified':
        backgroundColor = Colors.blue[50]!;
        borderColor = Colors.blue;
        textColor = Colors.blue[700]!;
        break;
      case 'fulfilled':
        backgroundColor = Colors.green[50]!;
        borderColor = Colors.green;
        textColor = Colors.green[700]!;
        break;
      case 'canceled':
        backgroundColor = Colors.grey[200]!;
        borderColor = Colors.grey;
        textColor = Colors.grey[700]!;
        break;
      default:
        backgroundColor = Colors.grey[200]!;
        borderColor = Colors.grey;
        textColor = Colors.grey[700]!;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
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
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'waiting':
        return 'Waiting in queue';
      case 'notified':
        return 'Book is available!';
      case 'fulfilled':
        return 'Completed';
      case 'canceled':
        return 'Canceled';
      default:
        return status;
    }
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}

/// Helper class to combine reservation and book data
class ReservationWithBook {
  final Reservation reservation;
  final Book book;

  ReservationWithBook({required this.reservation, required this.book});
}
