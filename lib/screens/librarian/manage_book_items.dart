import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/book_item_model.dart';
import '../../models/book_model.dart';

/// Screen for managing book items (physical copies) of a specific book.
///
/// Features:
/// - View all book items for a book
/// - Add new book items with barcode
/// - Edit book item details (location, condition, status)
/// - Delete book items (if not in use)
class ManageBookItemsScreen extends StatefulWidget {
  final Book book;

  const ManageBookItemsScreen({super.key, required this.book});

  @override
  State<ManageBookItemsScreen> createState() => _ManageBookItemsScreenState();
}

class _ManageBookItemsScreenState extends State<ManageBookItemsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<BookItem> _bookItems = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadBookItems();
  }

  Future<void> _loadBookItems() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final snapshot = await _firestore
          .collection('bookItems')
          .where('bookId', isEqualTo: widget.book.id)
          .get();

      final items = snapshot.docs.map((doc) => BookItem.fromDoc(doc)).toList();

      // Sort by barcode
      items.sort((a, b) => a.barcode.compareTo(b.barcode));

      setState(() {
        _bookItems = items;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _showAddItemDialog() async {
    final formKey = GlobalKey<FormState>();
    final barcodeController = TextEditingController();
    final locationController = TextEditingController(text: 'General Section');
    String condition = 'good';
    bool isProcessing = false;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Book Copy'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Book: ${widget.book.title}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: barcodeController,
                    decoration: const InputDecoration(
                      labelText: 'Barcode *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.qr_code),
                      helperText: 'Unique identifier (e.g., BOOK-AJTQYGXJ-001)',
                    ),
                    validator: (v) {
                      if (v?.isEmpty ?? true) return 'Required';
                      if (_bookItems.any((item) => item.barcode == v)) {
                        return 'Barcode already exists';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: locationController,
                    decoration: const InputDecoration(
                      labelText: 'Location *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.location_on),
                      helperText:
                          'Shelf location (e.g., A-12, General Section)',
                    ),
                    validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: condition,
                    decoration: const InputDecoration(
                      labelText: 'Condition',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.star),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'new', child: Text('New')),
                      DropdownMenuItem(value: 'good', child: Text('Good')),
                      DropdownMenuItem(value: 'fair', child: Text('Fair')),
                      DropdownMenuItem(value: 'poor', child: Text('Poor')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => condition = value);
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isProcessing ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isProcessing
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;

                      setDialogState(() => isProcessing = true);

                      try {
                        // Create new book item
                        final itemRef = _firestore
                            .collection('bookItems')
                            .doc();
                        final bookItem = BookItem(
                          id: itemRef.id,
                          bookId: widget.book.id,
                          barcode: barcodeController.text.trim(),
                          location: locationController.text.trim(),
                          condition: condition,
                          status: 'available',
                          createdAt: Timestamp.now(),
                        );

                        await itemRef.set(bookItem.toJson());

                        // Update book's totalCopies and availableCopies
                        await _firestore
                            .collection('books')
                            .doc(widget.book.id)
                            .update({
                              'totalCopies': FieldValue.increment(1),
                              'availableCopies': FieldValue.increment(1),
                            });

                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Book copy added successfully!'),
                              backgroundColor: Colors.green,
                            ),
                          );
                          _loadBookItems();
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      } finally {
                        if (context.mounted) {
                          setDialogState(() => isProcessing = false);
                        }
                      }
                    },
              child: isProcessing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Add Copy'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditItemDialog(BookItem item) async {
    final formKey = GlobalKey<FormState>();
    final locationController = TextEditingController(text: item.location);
    String condition = item.condition;
    String status = item.status;
    bool isProcessing = false;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Book Copy'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Barcode: ${item.barcode}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: locationController,
                    decoration: const InputDecoration(
                      labelText: 'Location *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.location_on),
                    ),
                    validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: condition,
                    decoration: const InputDecoration(
                      labelText: 'Condition',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.star),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'new', child: Text('New')),
                      DropdownMenuItem(value: 'good', child: Text('Good')),
                      DropdownMenuItem(value: 'fair', child: Text('Fair')),
                      DropdownMenuItem(value: 'poor', child: Text('Poor')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => condition = value);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: status,
                    decoration: const InputDecoration(
                      labelText: 'Status',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.info),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'available',
                        child: Text('Available'),
                      ),
                      DropdownMenuItem(
                        value: 'borrowed',
                        child: Text('Borrowed'),
                      ),
                      DropdownMenuItem(value: 'lost', child: Text('Lost')),
                      DropdownMenuItem(
                        value: 'damaged',
                        child: Text('Damaged'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => status = value);
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isProcessing ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isProcessing
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;

                      setDialogState(() => isProcessing = true);

                      try {
                        final oldStatus = item.status;
                        final newStatus = status;

                        // Update book item
                        await _firestore
                            .collection('bookItems')
                            .doc(item.id)
                            .update({
                              'location': locationController.text.trim(),
                              'condition': condition,
                              'status': status,
                            });

                        // Update book's availableCopies if status changed
                        if (oldStatus != newStatus) {
                          if (oldStatus == 'available' &&
                              newStatus != 'available') {
                            // Became unavailable
                            await _firestore
                                .collection('books')
                                .doc(widget.book.id)
                                .update({
                                  'availableCopies': FieldValue.increment(-1),
                                });
                          } else if (oldStatus != 'available' &&
                              newStatus == 'available') {
                            // Became available
                            await _firestore
                                .collection('books')
                                .doc(widget.book.id)
                                .update({
                                  'availableCopies': FieldValue.increment(1),
                                });
                          }
                        }

                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Book copy updated successfully!'),
                              backgroundColor: Colors.green,
                            ),
                          );
                          _loadBookItems();
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      } finally {
                        if (context.mounted) {
                          setDialogState(() => isProcessing = false);
                        }
                      }
                    },
              child: isProcessing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteBookItem(BookItem item) async {
    // Check if item is borrowed
    if (item.status == 'borrowed') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot delete borrowed book item'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Book Copy'),
        content: Text(
          'Are you sure you want to delete this book copy?\n\n'
          'Barcode: ${item.barcode}\n'
          'Location: ${item.location}\n'
          'Status: ${item.status}',
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
      // Delete book item
      await _firestore.collection('bookItems').doc(item.id).delete();

      // Update book's totalCopies and availableCopies
      final updates = <String, dynamic>{
        'totalCopies': FieldValue.increment(-1),
      };

      if (item.status == 'available') {
        updates['availableCopies'] = FieldValue.increment(-1);
      }

      await _firestore.collection('books').doc(widget.book.id).update(updates);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Book copy deleted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        _loadBookItems();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Book Copies'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: _showAddItemDialog,
            tooltip: 'Add Book Copy',
          ),
        ],
      ),
      body: Column(
        children: [
          // Book Info Header
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.blue[50],
            child: Row(
              children: [
                if (widget.book.coverUrl.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      widget.book.coverUrl,
                      width: 60,
                      height: 80,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.book, size: 60),
                    ),
                  )
                else
                  const Icon(Icons.book, size: 60),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.book.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.book.authors.join(', '),
                        style: TextStyle(color: Colors.grey[700], fontSize: 13),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Total Copies: ${widget.book.totalCopies} | '
                        'Available: ${widget.book.availableCopies}',
                        style: TextStyle(
                          color: Colors.blue[700],
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Book Items List
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
                          onPressed: _loadBookItems,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                : _bookItems.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.inventory_2_outlined,
                          size: 80,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No book copies yet',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tap + to add a copy',
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadBookItems,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _bookItems.length,
                      itemBuilder: (context, index) {
                        final item = _bookItems[index];
                        return _buildBookItemCard(item);
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookItemCard(BookItem item) {
    final isAvailable = item.status == 'available';
    final isBorrowed = item.status == 'borrowed';
    final isDamaged = item.status == 'damaged';
    final isLost = item.status == 'lost';

    Color statusColor;
    IconData statusIcon;

    if (isAvailable) {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
    } else if (isBorrowed) {
      statusColor = Colors.orange;
      statusIcon = Icons.schedule;
    } else if (isDamaged) {
      statusColor = Colors.red;
      statusIcon = Icons.warning;
    } else if (isLost) {
      statusColor = Colors.grey;
      statusIcon = Icons.search_off;
    } else {
      statusColor = Colors.grey;
      statusIcon = Icons.info;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.book, color: statusColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Barcode: ',
                            style: TextStyle(fontSize: 13, color: Colors.grey),
                          ),
                          Expanded(
                            child: Text(
                              item.barcode,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            size: 14,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            item.location,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Icon(Icons.star, size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            item.condition,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 14, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        item.status,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _showEditItemDialog(item),
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('Edit'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: isBorrowed ? null : () => _deleteBookItem(item),
                  icon: const Icon(Icons.delete, size: 16),
                  label: const Text('Delete'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
