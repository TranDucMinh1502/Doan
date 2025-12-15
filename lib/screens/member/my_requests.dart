import 'package:flutter/material.dart';
import '../../models/borrow_request_model.dart';
import '../../models/book_model.dart';
import '../../services/borrow_request_service.dart';
import '../../services/book_service.dart';
import '../../services/auth_service.dart';

/// Screen showing member's borrow requests with status tracking.
///
/// Displays all borrow requests made by the current member, organized by status.
class MyRequestsScreen extends StatefulWidget {
  const MyRequestsScreen({Key? key}) : super(key: key);

  @override
  State<MyRequestsScreen> createState() => _MyRequestsScreenState();
}

class _MyRequestsScreenState extends State<MyRequestsScreen>
    with SingleTickerProviderStateMixin {
  final BorrowRequestService _requestService = BorrowRequestService();
  final BookService _bookService = BookService();
  final AuthService _authService = AuthService();

  late TabController _tabController;
  String? _currentUserId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadCurrentUser();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentUser() async {
    setState(() => _isLoading = true);
    try {
      final user = await _authService.getCurrentUserProfile();
      setState(() {
        _currentUserId = user?.uid;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Yêu cầu mượn sách của tôi')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_currentUserId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Yêu cầu mượn sách của tôi')),
        body: const Center(child: Text('Vui lòng đăng nhập để xem yêu cầu')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Yêu cầu mượn sách của tôi'),
        elevation: 2,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Chờ duyệt', icon: Icon(Icons.hourglass_empty, size: 20)),
            Tab(text: 'Đã duyệt', icon: Icon(Icons.check_circle, size: 20)),
            Tab(text: 'Từ chối', icon: Icon(Icons.cancel, size: 20)),
            Tab(text: 'Đã hủy', icon: Icon(Icons.remove_circle, size: 20)),
          ],
          isScrollable: true,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildRequestList('pending'),
          _buildRequestList('approved'),
          _buildRequestList('rejected'),
          _buildRequestList('cancelled'),
        ],
      ),
    );
  }

  Widget _buildRequestList(String status) {
    return StreamBuilder<List<BorrowRequest>>(
      stream: _requestService.getUserBorrowRequestsStream(_currentUserId!),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text('Lỗi: ${snapshot.error}'),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => setState(() {}),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Thử lại'),
                ),
              ],
            ),
          );
        }

        final allRequests = snapshot.data ?? [];
        final filteredRequests =
            allRequests.where((request) => request.status == status).toList()
              ..sort((a, b) => b.requestedAt.compareTo(a.requestedAt));

        if (filteredRequests.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(_getEmptyIcon(status), size: 80, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  _getEmptyMessage(status),
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async => setState(() {}),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: filteredRequests.length,
            itemBuilder: (context, index) {
              return _buildRequestCard(filteredRequests[index]);
            },
          ),
        );
      },
    );
  }

  Widget _buildRequestCard(BorrowRequest request) {
    return FutureBuilder<Book?>(
      future: _bookService.getBookById(request.bookId),
      builder: (context, snapshot) {
        final book = snapshot.data;

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: InkWell(
            onTap: () => _showRequestDetails(request, book),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Book cover
                      if (book?.coverUrl != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            book!.coverUrl,
                            width: 60,
                            height: 90,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                _buildPlaceholderCover(),
                          ),
                        )
                      else
                        _buildPlaceholderCover(),
                      const SizedBox(width: 16),
                      // Book info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              book?.title ?? 'Đang tải...',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (book?.authors.isNotEmpty == true) ...[
                              const SizedBox(height: 4),
                              Text(
                                book!.authors.join(', '),
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                            const SizedBox(height: 8),
                            _buildStatusBadge(request.status),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  // Request info
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Ngày gửi: ${_formatDate(request.requestedAt.toDate())}',
                        style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                      ),
                    ],
                  ),
                  if (request.processedAt != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.update, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 8),
                        Text(
                          '${_getProcessedLabel(request.status)}: ${_formatDate(request.processedAt!.toDate())}',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ],
                  // Member note
                  if (request.memberNote != null &&
                      request.memberNote!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.note, size: 16, color: Colors.blue[700]),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              request.memberNote!,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.blue[900],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  // Librarian note (for rejected)
                  if (request.librarianNote != null &&
                      request.librarianNote!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: request.status == 'rejected'
                            ? Colors.red[50]
                            : Colors.green[50],
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.message,
                            size: 16,
                            color: request.status == 'rejected'
                                ? Colors.red[700]
                                : Colors.green[700],
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Thư viện: ${request.librarianNote!}',
                              style: TextStyle(
                                fontSize: 13,
                                color: request.status == 'rejected'
                                    ? Colors.red[900]
                                    : Colors.green[900],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  // Action buttons
                  if (request.isPending) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _cancelRequest(request),
                        icon: const Icon(Icons.cancel_outlined, size: 18),
                        label: const Text('Hủy yêu cầu'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
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

  Widget _buildPlaceholderCover() {
    return Container(
      width: 60,
      height: 90,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(Icons.book, size: 40, color: Colors.grey[600]),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bgColor;
    Color textColor;
    String label;
    IconData icon;

    switch (status) {
      case 'pending':
        bgColor = Colors.orange[100]!;
        textColor = Colors.orange[900]!;
        label = 'Chờ duyệt';
        icon = Icons.hourglass_empty;
        break;
      case 'approved':
        bgColor = Colors.green[100]!;
        textColor = Colors.green[900]!;
        label = 'Đã duyệt';
        icon = Icons.check_circle;
        break;
      case 'rejected':
        bgColor = Colors.red[100]!;
        textColor = Colors.red[900]!;
        label = 'Từ chối';
        icon = Icons.cancel;
        break;
      case 'cancelled':
        bgColor = Colors.grey[300]!;
        textColor = Colors.grey[800]!;
        label = 'Đã hủy';
        icon = Icons.remove_circle;
        break;
      default:
        bgColor = Colors.grey[300]!;
        textColor = Colors.grey[800]!;
        label = status;
        icon = Icons.help;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: textColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getEmptyIcon(String status) {
    switch (status) {
      case 'pending':
        return Icons.schedule;
      case 'approved':
        return Icons.check_circle_outline;
      case 'rejected':
        return Icons.block;
      case 'cancelled':
        return Icons.do_not_disturb_on;
      default:
        return Icons.inbox;
    }
  }

  String _getEmptyMessage(String status) {
    switch (status) {
      case 'pending':
        return 'Chưa có yêu cầu nào đang chờ duyệt';
      case 'approved':
        return 'Chưa có yêu cầu nào được duyệt';
      case 'rejected':
        return 'Chưa có yêu cầu nào bị từ chối';
      case 'cancelled':
        return 'Chưa có yêu cầu nào bị hủy';
      default:
        return 'Không có yêu cầu';
    }
  }

  String _getProcessedLabel(String status) {
    switch (status) {
      case 'approved':
        return 'Duyệt lúc';
      case 'rejected':
        return 'Từ chối lúc';
      case 'cancelled':
        return 'Hủy lúc';
      default:
        return 'Xử lý lúc';
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  Future<void> _cancelRequest(BorrowRequest request) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 8),
            Text('Xác nhận hủy'),
          ],
        ),
        content: const Text(
          'Bạn có chắc muốn hủy yêu cầu mượn sách này không?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Không'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Hủy yêu cầu'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _requestService.cancelBorrowRequest(request.id, _currentUserId!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text('Đã hủy yêu cầu thành công'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text('Lỗi: $e')),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _showRequestDetails(BorrowRequest request, Book? book) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Chi tiết yêu cầu'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (book != null) ...[
                const Text(
                  'Thông tin sách',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text('Tên sách: ${book.title}'),
                Text('Tác giả: ${book.authors.join(", ")}'),
                Text('ISBN: ${book.isbn}'),
                const Divider(height: 24),
              ],
              const Text(
                'Thông tin yêu cầu',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text('Trạng thái: ${_getStatusLabel(request.status)}'),
              Text('Ngày gửi: ${_formatDate(request.requestedAt.toDate())}'),
              if (request.processedAt != null)
                Text(
                  'Ngày xử lý: ${_formatDate(request.processedAt!.toDate())}',
                ),
              if (request.memberNote != null &&
                  request.memberNote!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Ghi chú của bạn:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[700],
                  ),
                ),
                Text(request.memberNote!),
              ],
              if (request.librarianNote != null &&
                  request.librarianNote!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Phản hồi từ thư viện:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: request.status == 'rejected'
                        ? Colors.red[700]
                        : Colors.green[700],
                  ),
                ),
                Text(request.librarianNote!),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'pending':
        return 'Chờ duyệt';
      case 'approved':
        return 'Đã duyệt';
      case 'rejected':
        return 'Từ chối';
      case 'cancelled':
        return 'Đã hủy';
      default:
        return status;
    }
  }
}
