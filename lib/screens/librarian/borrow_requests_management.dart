import 'package:flutter/material.dart';
import '../../models/borrow_request_model.dart';
import '../../models/book_model.dart';
import '../../models/book_item_model.dart';
import '../../models/user_model.dart';
import '../../services/borrow_request_service.dart';
import '../../services/book_service.dart';
import '../../services/book_item_service.dart';
import '../../services/user_service.dart';
import '../../services/auth_service.dart';

/// Screen for librarians to manage borrow requests.
///
/// Allows librarians to approve or reject member borrow requests.
class BorrowRequestsManagementScreen extends StatefulWidget {
  const BorrowRequestsManagementScreen({Key? key}) : super(key: key);

  @override
  State<BorrowRequestsManagementScreen> createState() =>
      _BorrowRequestsManagementScreenState();
}

class _BorrowRequestsManagementScreenState
    extends State<BorrowRequestsManagementScreen>
    with SingleTickerProviderStateMixin {
  final BorrowRequestService _requestService = BorrowRequestService();
  final BookService _bookService = BookService();
  final BookItemService _itemService = BookItemService();
  final UserService _userService = UserService();
  final AuthService _authService = AuthService();

  late TabController _tabController;
  String? _currentLibrarianId;
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
        _currentLibrarianId = user?.uid;
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
        appBar: AppBar(title: const Text('Quản lý yêu cầu mượn sách')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý yêu cầu mượn sách'),
        elevation: 2,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(110),
          child: Column(
            children: [
              // Search bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Tìm theo tên sách, tác giả, tên thành viên...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  onChanged: (value) =>
                      setState(() => _searchQuery = value.toLowerCase()),
                ),
              ),
              // Tabs
              TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: 'Chờ duyệt', icon: Icon(Icons.pending, size: 20)),
                  Tab(
                    text: 'Đã duyệt',
                    icon: Icon(Icons.check_circle, size: 20),
                  ),
                  Tab(text: 'Đã từ chối', icon: Icon(Icons.cancel, size: 20)),
                ],
              ),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildRequestList('pending'),
          _buildRequestList('approved'),
          _buildRequestList('rejected'),
        ],
      ),
    );
  }

  Widget _buildRequestList(String status) {
    return StreamBuilder<List<BorrowRequest>>(
      stream: _requestService.getAllBorrowRequestsStream(),
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
        var filteredRequests =
            allRequests.where((request) => request.status == status).toList()
              ..sort((a, b) => b.requestedAt.compareTo(a.requestedAt));

        // Apply search filter
        if (_searchQuery.isNotEmpty) {
          filteredRequests = filteredRequests.where((request) {
            // We'll load book and user data to search
            return true; // Placeholder, will be filtered in FutureBuilder
          }).toList();
        }

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
    return FutureBuilder<Map<String, dynamic>>(
      future: _loadRequestData(request),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        final data = snapshot.data!;
        final book = data['book'] as Book?;
        final member = data['member'] as AppUser?;

        // Apply search filter
        if (_searchQuery.isNotEmpty) {
          final bookTitle = book?.title.toLowerCase() ?? '';
          final bookAuthors = book?.authors.join(' ').toLowerCase() ?? '';
          final memberName = member?.fullName.toLowerCase() ?? '';

          if (!bookTitle.contains(_searchQuery) &&
              !bookAuthors.contains(_searchQuery) &&
              !memberName.contains(_searchQuery)) {
            return const SizedBox.shrink();
          }
        }

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: InkWell(
            onTap: () => _showRequestDetails(request, book, member),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Member info
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.blue,
                        child: Text(
                          member?.fullName[0].toUpperCase() ?? 'M',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              member?.fullName ?? 'Loading...',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              member?.cardNumber ?? '',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      _buildStatusBadge(request.status),
                    ],
                  ),
                  const Divider(height: 24),
                  // Book info
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              book?.title ?? 'Loading...',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
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
                              ),
                            ],
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(
                                  Icons.inventory,
                                  size: 16,
                                  color: Colors.grey[600],
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Còn: ${book?.availableCopies ?? 0} bản',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color:
                                        book != null && book.availableCopies > 0
                                        ? Colors.green
                                        : Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Request date
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Gửi: ${_formatDate(request.requestedAt.toDate())}',
                        style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                      ),
                      if (request.processedAt != null) ...[
                        const SizedBox(width: 16),
                        Icon(Icons.update, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 8),
                        Text(
                          'Xử lý: ${_formatDate(request.processedAt!.toDate())}',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ],
                  ),
                  // Member note
                  if (request.memberNote != null &&
                      request.memberNote!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
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
                  // Librarian note
                  if (request.librarianNote != null &&
                      request.librarianNote!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: request.status == 'rejected'
                            ? Colors.red[50]
                            : Colors.green[50],
                        borderRadius: BorderRadius.circular(8),
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
                              request.librarianNote!,
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
                  // Action buttons (only for pending requests)
                  if (request.isPending && book != null) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _approveRequest(request, book),
                            icon: const Icon(Icons.check, size: 18),
                            label: const Text('Duyệt'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _rejectRequest(request),
                            icon: const Icon(Icons.close, size: 18),
                            label: const Text('Từ chối'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                      ],
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

  Future<Map<String, dynamic>> _loadRequestData(BorrowRequest request) async {
    final book = await _bookService.getBookById(request.bookId);
    final member = await _userService.getUserById(request.userId);
    return {'book': book, 'member': member};
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

    switch (status) {
      case 'pending':
        bgColor = Colors.orange[100]!;
        textColor = Colors.orange[900]!;
        label = 'Chờ duyệt';
        break;
      case 'approved':
        bgColor = Colors.green[100]!;
        textColor = Colors.green[900]!;
        label = 'Đã duyệt';
        break;
      case 'rejected':
        bgColor = Colors.red[100]!;
        textColor = Colors.red[900]!;
        label = 'Từ chối';
        break;
      default:
        bgColor = Colors.grey[300]!;
        textColor = Colors.grey[800]!;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),
    );
  }

  IconData _getEmptyIcon(String status) {
    switch (status) {
      case 'pending':
        return Icons.inbox;
      case 'approved':
        return Icons.check_circle_outline;
      case 'rejected':
        return Icons.block;
      default:
        return Icons.inbox;
    }
  }

  String _getEmptyMessage(String status) {
    switch (status) {
      case 'pending':
        return 'Không có yêu cầu nào đang chờ duyệt';
      case 'approved':
        return 'Chưa có yêu cầu nào được duyệt';
      case 'rejected':
        return 'Chưa có yêu cầu nào bị từ chối';
      default:
        return 'Không có yêu cầu';
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  Future<void> _approveRequest(BorrowRequest request, Book book) async {
    if (book.availableCopies <= 0) {
      _showMessage('Không còn bản sách nào available', isSuccess: false);
      return;
    }

    // Get available book items
    final availableItems = await _itemService.getAvailableBookItems(book.id);

    if (availableItems.isEmpty) {
      _showMessage('Không tìm thấy bản sách available', isSuccess: false);
      return;
    }

    BookItem? selectedItem;

    // If member pre-selected an item, check if it's still available
    if (request.itemId != null && request.itemId!.isNotEmpty) {
      selectedItem = availableItems.firstWhere(
        (item) => item.id == request.itemId,
        orElse: () => availableItems.first,
      );

      // If member's choice is still available, use it automatically
      if (selectedItem.id == request.itemId) {
        // Show confirmation that we're using member's choice
        final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Sử dụng bản sách thành viên đã chọn?'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Thành viên đã chọn sẵn bản sách:'),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Barcode: ${selectedItem!.barcode}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text('Vị trí: ${selectedItem.location}'),
                      Text(
                        'Tình trạng: ${_getConditionLabel(selectedItem.condition)}',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Chọn "Chọn bản khác" nếu bạn muốn cấp bản sách khác.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Chọn bản khác'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Sử dụng bản này'),
              ),
            ],
          ),
        );

        if (confirm == null) return;

        if (!confirm) {
          // Librarian wants to choose a different item
          selectedItem = await _showSelectItemDialog(availableItems);
          if (selectedItem == null) return;
        }
      }
    } else {
      // No pre-selected item, show dialog to select
      selectedItem = await _showSelectItemDialog(availableItems);
      if (selectedItem == null) return;
    }

    // Show dialog to enter librarian note
    final note = await _showNoteDialog(
      title: 'Phê duyệt yêu cầu',
      hint: 'Ghi chú cho thành viên (tuỳ chọn)',
    );
    if (note == null) return; // User cancelled

    try {
      await _requestService.approveBorrowRequest(
        requestId: request.id,
        itemId: selectedItem.id,
        librarianId: _currentLibrarianId!,
        librarianNote: note.isEmpty ? null : note,
      );

      if (mounted) {
        _showMessage('Đã duyệt yêu cầu và cấp sách thành công');
        setState(() {}); // Refresh list
      }
    } catch (e) {
      if (mounted) {
        _showMessage('Lỗi: $e', isSuccess: false);
      }
    }
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
      case 'damaged':
        return 'Hư hỏng';
      default:
        return condition;
    }
  }

  Future<BookItem?> _showSelectItemDialog(List<BookItem> items) async {
    return showDialog<BookItem>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Chọn bản sách để cấp'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return ListTile(
                title: Text('Barcode: ${item.barcode}'),
                subtitle: Text(
                  'Vị trí: ${item.location}\nTình trạng: ${item.condition}',
                ),
                trailing: _buildConditionBadge(item.condition),
                onTap: () => Navigator.pop(context, item),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
        ],
      ),
    );
  }

  Widget _buildConditionBadge(String condition) {
    Color color;
    switch (condition) {
      case 'new':
        color = Colors.green;
        break;
      case 'good':
        color = Colors.blue;
        break;
      case 'fair':
        color = Colors.orange;
        break;
      case 'poor':
        color = Colors.red;
        break;
      default:
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        condition.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Future<void> _rejectRequest(BorrowRequest request) async {
    final reason = await _showNoteDialog(
      title: 'Từ chối yêu cầu',
      hint: 'Lý do từ chối (bắt buộc)',
      required: true,
    );

    if (reason == null) return; // User cancelled

    try {
      await _requestService.rejectBorrowRequest(
        requestId: request.id,
        librarianId: _currentLibrarianId!,
        reason: reason,
      );

      if (mounted) {
        _showMessage('Đã từ chối yêu cầu');
        setState(() {}); // Refresh list
      }
    } catch (e) {
      if (mounted) {
        _showMessage('Lỗi: $e', isSuccess: false);
      }
    }
  }

  Future<String?> _showNoteDialog({
    required String title,
    required String hint,
    bool required = false,
  }) async {
    final controller = TextEditingController();

    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hint,
            border: const OutlineInputBorder(),
          ),
          maxLines: 3,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () {
              if (required && controller.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Vui lòng nhập lý do')),
                );
                return;
              }
              Navigator.pop(context, controller.text.trim());
            },
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );
  }

  Future<void> _showRequestDetails(
    BorrowRequest request,
    Book? book,
    AppUser? member,
  ) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Chi tiết yêu cầu'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Thông tin thành viên',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              if (member != null) ...[
                Text('Họ tên: ${member.fullName}'),
                Text('Mã thẻ: ${member.cardNumber}'),
                Text('Email: ${member.email}'),
                Text('Đang mượn: ${member.borrowedCount} sách'),
              ],
              const Divider(height: 24),
              const Text(
                'Thông tin sách',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              if (book != null) ...[
                Text('Tên sách: ${book.title}'),
                Text('Tác giả: ${book.authors.join(", ")}'),
                Text('ISBN: ${book.isbn}'),
                Text('Còn lại: ${book.availableCopies} bản'),
              ],
              const Divider(height: 24),
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
                  'Ghi chú từ thành viên:',
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
                  'Ghi chú từ thư viện:',
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
      default:
        return status;
    }
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
      ),
    );
  }
}
