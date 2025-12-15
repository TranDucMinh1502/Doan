import 'package:flutter/material.dart';
import '../../models/book_model.dart';
import '../../models/book_item_model.dart';
import '../../models/user_model.dart';
import '../../services/book_service.dart';
import '../../services/book_item_service.dart';
import '../../services/auth_service.dart';
import '../../services/reservation_service.dart';
import '../../services/borrow_request_service.dart';
import '../librarian/manage_book_items.dart';

/// Screen displaying detailed information about a book.
///
/// Shows book metadata, available copies, and actions based on user role.
class BookDetailScreen extends StatefulWidget {
  final String bookId;

  const BookDetailScreen({Key? key, required this.bookId}) : super(key: key);

  @override
  State<BookDetailScreen> createState() => _BookDetailScreenState();
}

class _BookDetailScreenState extends State<BookDetailScreen> {
  final BookService _bookService = BookService();
  final BookItemService _bookItemService = BookItemService();
  final AuthService _authService = AuthService();
  final ReservationService _reservationService = ReservationService();
  final BorrowRequestService _borrowRequestService = BorrowRequestService();

  Book? _book;
  List<BookItem> _availableItems = [];
  AppUser? _currentUser;
  bool _isLoading = true;
  String? _errorMessage;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Load book, available items, and current user in parallel
      final results = await Future.wait([
        _bookService.getBookById(widget.bookId),
        _bookItemService.getAvailableBookItems(widget.bookId),
        _authService.getCurrentUserProfile(),
      ]);

      setState(() {
        _book = results[0] as Book?;
        _availableItems = results[1] as List<BookItem>;
        _currentUser = results[2] as AppUser?;
        _isLoading = false;
      });

      if (_book == null) {
        setState(() {
          _errorMessage = 'Book not found';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _handleBorrowRequest() async {
    if (_currentUser == null || _book == null) {
      return;
    }

    // Check if user can borrow more books
    if (!_currentUser!.canBorrowMore) {
      _showMessage('Bạn đã đạt giới hạn mượn sách', isSuccess: false);
      return;
    }

    // Load available items first
    if (_availableItems.isEmpty) {
      _showMessage('Không có bản sách nào available', isSuccess: false);
      return;
    }

    // Show dialog to select book item and enter note
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) =>
          _BorrowRequestDialog(book: _book!, availableItems: _availableItems),
    );

    if (result == null) return;

    final selectedItemId = result['itemId'] as String;
    final note = result['note'] as String?;

    setState(() => _isProcessing = true);

    try {
      await _borrowRequestService.createBorrowRequest(
        userId: _currentUser!.uid,
        bookId: _book!.id,
        itemId: selectedItemId,
        memberNote: note,
      );

      if (mounted) {
        _showMessage(
          'Yêu cầu mượn sách đã được gửi! Vui lòng chờ thư viện phê duyệt.',
          isSuccess: true,
        );
        _loadData();
      }
    } on Exception catch (e) {
      if (mounted) {
        String errorMsg = e.toString().replaceAll('Exception: ', '');
        if (errorMsg.contains('permission') ||
            errorMsg.contains('PERMISSION_DENIED')) {
          _showMessage(
            'Lỗi quyền truy cập. Vui lòng kiểm tra Firebase rules đã được deploy chưa.',
            isSuccess: false,
          );
        } else if (errorMsg.contains('already have a pending request')) {
          _showMessage(
            'Bạn đã có yêu cầu mượn sách này đang chờ duyệt',
            isSuccess: false,
          );
        } else if (errorMsg.contains('already have an active loan')) {
          _showMessage('Bạn đang mượn cuốn sách này', isSuccess: false);
        } else if (errorMsg.contains('borrowing limit')) {
          _showMessage('Bạn đã đạt giới hạn mượn sách', isSuccess: false);
        } else {
          _showMessage('Lỗi: $errorMsg', isSuccess: false);
        }
        // Print to console for debugging
        print('Borrow Request Error: $errorMsg');
      }
    } catch (e) {
      if (mounted) {
        _showMessage('Lỗi không xác định: ${e.toString()}', isSuccess: false);
        print('Unexpected Error: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _handleReserve() async {
    if (_currentUser == null || _book == null) {
      _showMessage('Vui lòng đợi, đang tải thông tin...', isSuccess: false);
      return;
    }

    // Show confirmation dialog
    final confirmed = await _showReserveConfirmDialog();
    if (confirmed != true) return;

    setState(() => _isProcessing = true);

    try {
      await _reservationService.reserveBook(_currentUser!.uid, _book!.id);

      if (mounted) {
        await _loadData(); // Reload to update UI
        _showMessage(
          'Đặt giữ sách thành công! Bạn sẽ được thông báo khi sách có sẵn.',
          isSuccess: true,
        );
      }
    } on Exception catch (e) {
      if (mounted) {
        String errorMsg = e.toString();
        if (errorMsg.contains('permission') ||
            errorMsg.contains('PERMISSION_DENIED')) {
          _showMessage(
            'Lỗi quyền truy cập. Vui lòng kiểm tra Firestore rules.',
            isSuccess: false,
          );
        } else if (errorMsg.contains('already have an active reservation')) {
          _showMessage(
            'Bạn đã đặt giữ sách này rồi. Kiểm tra tab Reservations.',
            isSuccess: false,
          );
        } else {
          _showMessage('Lỗi: $errorMsg', isSuccess: false);
        }
      }
    } catch (e) {
      if (mounted) {
        _showMessage('Lỗi không xác định: ${e.toString()}', isSuccess: false);
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<bool?> _showReserveConfirmDialog() async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.bookmark_add, color: Colors.orange),
            SizedBox(width: 8),
            Text('Đặt giữ sách'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Bạn muốn đặt giữ sách:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    if (_book?.coverUrl != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Image.network(
                          _book!.coverUrl,
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
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _book?.title ?? 'Unknown',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _book?.authors.join(', ') ?? '',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 20,
                          color: Colors.orange[700],
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Lưu ý:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.orange[900],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _book != null && _book!.availableCopies > 0
                          ? '• Đặt giữ để đảm bảo có sách khi cần\n'
                                '• Bạn có thể mượn ngay hoặc để sau\n'
                                '• Được ưu tiên khi có người trả sách\n'
                                '• Có 3 ngày để mượn khi được thông báo'
                          : '• Sách hiện không có sẵn\n'
                                '• Bạn sẽ vào hàng đợi\n'
                                '• Thông báo khi sách có sẵn\n'
                                '• Có 3 ngày để mượn khi được thông báo',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.orange[900],
                        height: 1.5,
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
            icon: const Icon(Icons.bookmark_add),
            label: const Text('Xác nhận đặt giữ'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
          ),
        ],
      ),
    );
  }

  void _showMessage(String message, {bool isSuccess = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isSuccess ? Icons.check_circle : Icons.error,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isSuccess ? Colors.green : Colors.red,
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Book Details'), elevation: 2),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? _buildErrorView()
          : _buildContent(),
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
            onPressed: _loadData,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_book == null) return const SizedBox.shrink();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Book cover and basic info
          _buildHeader(),

          const Divider(height: 1),

          // Book metadata
          _buildMetadata(),

          const Divider(height: 1),

          // Available copies section
          _buildAvailableCopies(),

          const Divider(height: 1),

          // Action buttons
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Book cover
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: _book!.coverUrl.isNotEmpty
                ? Image.network(
                    _book!.coverUrl,
                    width: 120,
                    height: 180,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return _buildPlaceholderCover();
                    },
                  )
                : _buildPlaceholderCover(),
          ),
          const SizedBox(width: 16),

          // Title and authors
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _book!.title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _book!.authors.join(', '),
                  style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                ),
                const SizedBox(height: 12),

                // Availability badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _book!.availableCopies > 0
                        ? Colors.green[50]
                        : Colors.red[50],
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _book!.availableCopies > 0
                          ? Colors.green
                          : Colors.red,
                    ),
                  ),
                  child: Text(
                    _book!.availableCopies > 0
                        ? '${_book!.availableCopies} available'
                        : 'Not available',
                    style: TextStyle(
                      color: _book!.availableCopies > 0
                          ? Colors.green[700]
                          : Colors.red[700],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderCover() {
    return Container(
      width: 120,
      height: 180,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(Icons.book, size: 60, color: Colors.grey[600]),
    );
  }

  Widget _buildMetadata() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Details',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          // ISBN
          if (_book!.isbn.isNotEmpty) ...[
            _buildMetadataRow('ISBN', _book!.isbn),
            const SizedBox(height: 8),
          ],

          // Categories
          if (_book!.categories.isNotEmpty) ...[
            _buildMetadataRow('Categories', _book!.categories.join(', ')),
            const SizedBox(height: 8),
          ],

          // Published date
          _buildMetadataRow(
            'Published',
            _formatDate(_book!.publishedAt.toDate()),
          ),
          const SizedBox(height: 8),

          // Total copies
          _buildMetadataRow('Total Copies', '${_book!.totalCopies}'),
        ],
      ),
    );
  }

  Widget _buildMetadataRow(String label, String value) {
    return Row(
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
        Expanded(child: Text(value, style: const TextStyle(fontSize: 15))),
      ],
    );
  }

  Widget _buildAvailableCopies() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Book Copies',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Text(
                '${_availableItems.length} available',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.green[700],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (_availableItems.isEmpty)
            Text(
              'No copies available for checkout',
              style: TextStyle(color: Colors.grey[600], fontSize: 15),
            )
          else
            ..._availableItems.map((item) => _buildBookItemTile(item)).toList(),
        ],
      ),
    );
  }

  Widget _buildBookItemTile(BookItem item) {
    final isAvailable = item.status.toLowerCase() == 'available';
    final isBorrowed = item.status.toLowerCase() == 'borrowed';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Book icon
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isAvailable ? Colors.blue[50] : Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.book,
                color: isAvailable ? Colors.blue : Colors.grey,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),

            // Book item info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Barcode: ',
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      ),
                      Text(
                        item.barcode,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${item.location} • ${item.condition}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 6),

                  // Status badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isAvailable
                          ? Colors.green[50]
                          : isBorrowed
                          ? Colors.orange[50]
                          : Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isAvailable
                            ? Colors.green
                            : isBorrowed
                            ? Colors.orange
                            : Colors.grey,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isAvailable
                              ? Icons.check_circle
                              : isBorrowed
                              ? Icons.schedule
                              : Icons.info,
                          size: 14,
                          color: isAvailable
                              ? Colors.green[700]
                              : isBorrowed
                              ? Colors.orange[700]
                              : Colors.grey[700],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isAvailable
                              ? 'Có sẵn'
                              : isBorrowed
                              ? 'Đã cho mượn'
                              : item.status,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isAvailable
                                ? Colors.green[700]
                                : isBorrowed
                                ? Colors.orange[700]
                                : Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    if (_currentUser == null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'Please sign in to borrow or reserve books',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey[600]),
        ),
      );
    }

    if (_currentUser!.isLibrarian) {
      return _buildLibrarianButtons();
    }

    if (_currentUser!.isMember) {
      return _buildMemberButtons();
    }

    return const SizedBox.shrink();
  }

  Widget _buildLibrarianButtons() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ElevatedButton.icon(
            onPressed: _isProcessing
                ? null
                : () {
                    _showMessage('Edit book feature coming soon');
                  },
            icon: const Icon(Icons.edit),
            label: const Text('Edit Book'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _isProcessing || _book == null
                ? null
                : () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ManageBookItemsScreen(book: _book!),
                      ),
                    ).then((_) => _loadData());
                  },
            icon: const Icon(Icons.inventory),
            label: const Text('Manage Copies'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberButtons() {
    if (_book == null) return const SizedBox.shrink();

    if (_book!.availableCopies > 0) {
      return _buildRequestBorrowSection();
    } else {
      return _buildReserveOnlySection();
    }
  }

  Widget _buildRequestBorrowSection() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Gửi yêu cầu mượn sách đến thư viện. Thư viện sẽ xem xét và phê duyệt yêu cầu của bạn.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue[900],
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _isProcessing ? null : _handleBorrowRequest,
            icon: _isProcessing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.send),
            label: Text(
              _isProcessing ? 'Đang xử lý...' : 'Gửi yêu cầu mượn sách',
            ),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              backgroundColor: Colors.blue,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _isProcessing ? null : _handleReserve,
            icon: const Icon(Icons.bookmark_add),
            label: const Text('Hoặc đặt giữ để mượn sau'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              foregroundColor: Colors.orange,
              side: const BorderSide(color: Colors.orange, width: 2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReserveOnlySection() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange[200]!),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, color: Colors.orange[700], size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Sách hiện đã hết. Bạn có thể đặt giữ để được ưu tiên mượn khi có người trả sách.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange[900],
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _isProcessing ? null : _handleReserve,
            icon: _isProcessing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.bookmark_add),
            label: Text(_isProcessing ? 'Đang xử lý...' : 'Đặt giữ sách'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              backgroundColor: Colors.orange,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

/// Dialog for selecting book item and entering note when borrowing
class _BorrowRequestDialog extends StatefulWidget {
  final Book book;
  final List<BookItem> availableItems;

  const _BorrowRequestDialog({
    required this.book,
    required this.availableItems,
  });

  @override
  State<_BorrowRequestDialog> createState() => _BorrowRequestDialogState();
}

class _BorrowRequestDialogState extends State<_BorrowRequestDialog> {
  String? _selectedItemId;
  final TextEditingController _noteController = TextEditingController();

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.send, color: Colors.blue),
          SizedBox(width: 8),
          Expanded(child: Text('Gửi yêu cầu mượn sách')),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bạn muốn mượn: "${widget.book.title}"',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'Chọn bản sách:',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
              ),
              constraints: const BoxConstraints(maxHeight: 300),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: widget.availableItems.length,
                separatorBuilder: (_, __) =>
                    Divider(height: 1, color: Colors.grey[200]),
                itemBuilder: (context, index) {
                  final item = widget.availableItems[index];
                  final isSelected = _selectedItemId == item.id;

                  return InkWell(
                    onTap: () => setState(() => _selectedItemId = item.id),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      color: isSelected ? Colors.blue[50] : null,
                      child: Row(
                        children: [
                          Radio<String>(
                            value: item.id,
                            groupValue: _selectedItemId,
                            onChanged: (value) =>
                                setState(() => _selectedItemId = value),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Barcode: ${item.barcode}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${item.location} • ${_getConditionLabel(item.condition)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[700],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green[100],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  size: 14,
                                  color: Colors.green[700],
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Có sẵn',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green[700],
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
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _noteController,
              decoration: const InputDecoration(
                labelText: 'Ghi chú (không bắt buộc)',
                hintText: 'Lý do mượn sách hoặc ghi chú đặc biệt...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              maxLength: 200,
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.blue[700]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Thư viện sẽ xem xét và phê duyệt yêu cầu của bạn',
                      style: TextStyle(fontSize: 12, color: Colors.blue[900]),
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
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        ElevatedButton(
          onPressed: _selectedItemId == null
              ? null
              : () {
                  Navigator.pop(context, {
                    'itemId': _selectedItemId,
                    'note': _noteController.text.trim().isEmpty
                        ? null
                        : _noteController.text.trim(),
                  });
                },
          child: const Text('Gửi yêu cầu'),
        ),
      ],
    );
  }

  String _getConditionLabel(String condition) {
    switch (condition) {
      case 'new':
        return 'Mới';
      case 'good':
        return 'Tốt';
      case 'fair':
        return 'Khá';
      case 'poor':
        return 'Cũ';
      default:
        return condition;
    }
  }
}
