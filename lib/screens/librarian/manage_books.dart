import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import '../../services/book_service.dart';
import '../../models/book_model.dart';

class ManageBooksScreen extends StatefulWidget {
  const ManageBooksScreen({super.key});

  @override
  State<ManageBooksScreen> createState() => _ManageBooksScreenState();
}

class _ManageBooksScreenState extends State<ManageBooksScreen> {
  final _bookService = BookService();
  final _searchController = TextEditingController();
  final _imagePicker = ImagePicker();
  List<Book> _books = [];
  List<Book> _filteredBooks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBooks();
    _searchController.addListener(_filterBooks);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadBooks() async {
    setState(() => _isLoading = true);
    try {
      final books = await _bookService.fetchAllBooks();
      setState(() {
        _books = books;
        _filteredBooks = books;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading books: $e')));
      }
    }
  }

  void _filterBooks() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredBooks = _books.where((book) {
        return book.title.toLowerCase().contains(query) ||
            book.isbn.toLowerCase().contains(query) ||
            book.authors.any((author) => author.toLowerCase().contains(query));
      }).toList();
    });
  }

  Future<String?> _uploadImage(XFile imageFile) async {
    try {
      final storageRef = FirebaseStorage.instance.ref();
      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${imageFile.name}';
      final imageRef = storageRef.child('book_covers/$fileName');

      await imageRef.putFile(File(imageFile.path));
      final downloadUrl = await imageRef.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      debugPrint('Error uploading image: $e');
      return null;
    }
  }

  Future<void> _showImageSourceDialog(Function(String?) onImageSelected) async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose Image Source'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(context, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Gallery'),
              onTap: () => Navigator.pop(context, 'gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.link),
              title: const Text('Enter URL'),
              onTap: () => Navigator.pop(context, 'url'),
            ),
          ],
        ),
      ),
    );

    if (result == null) return;

    if (result == 'url') {
      await _handleUrlInput(onImageSelected);
    } else {
      await _handleImagePickerUpload(result, onImageSelected);
    }
  }

  Future<void> _handleUrlInput(Function(String?) onImageSelected) async {
    final urlController = TextEditingController();
    final url = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter Image URL'),
        content: TextField(
          controller: urlController,
          decoration: const InputDecoration(
            labelText: 'Image URL',
            hintText: 'https://example.com/image.jpg',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final text = urlController.text.trim();
              Navigator.pop(context, text.isEmpty ? null : text);
            },
            child: const Text('Use URL'),
          ),
        ],
      ),
    );

    if (url != null) {
      onImageSelected(url);
    }
  }

  Future<void> _handleImagePickerUpload(
    String source,
    Function(String?) onImageSelected,
  ) async {
    try {
      final image = await _imagePicker.pickImage(
        source: source == 'camera' ? ImageSource.camera : ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image == null) return;

      if (!mounted) return;

      // Show uploading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Uploading image...'),
                ],
              ),
            ),
          ),
        ),
      );

      final url = await _uploadImage(image);

      if (mounted) {
        Navigator.pop(context); // Close uploading dialog

        if (url != null) {
          onImageSelected(url);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Image uploaded successfully'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to upload image'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close uploading dialog if open
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _showAddBookDialog() async {
    final formKey = GlobalKey<FormState>();
    final titleController = TextEditingController();
    final isbnController = TextEditingController();
    final authorsController = TextEditingController();
    final categoriesController = TextEditingController();
    final publishedYearController = TextEditingController();
    final copiesController = TextEditingController(text: '1');
    String? coverUrl;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add New Book'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Image Preview
                  if (coverUrl != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        coverUrl!,
                        height: 150,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          height: 150,
                          color: Colors.grey[300],
                          child: const Icon(Icons.broken_image, size: 50),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  // Add Image Button
                  OutlinedButton.icon(
                    onPressed: () => _showImageSourceDialog((url) {
                      setState(() => coverUrl = url);
                    }),
                    icon: const Icon(Icons.add_photo_alternate),
                    label: Text(
                      coverUrl == null ? 'Add Cover Image' : 'Change Image',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: titleController,
                    decoration: const InputDecoration(labelText: 'Title *'),
                    validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                  ),
                  TextFormField(
                    controller: isbnController,
                    decoration: const InputDecoration(labelText: 'ISBN *'),
                    validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                  ),
                  TextFormField(
                    controller: authorsController,
                    decoration: const InputDecoration(
                      labelText: 'Authors (comma-separated) *',
                    ),
                    validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                  ),
                  TextFormField(
                    controller: categoriesController,
                    decoration: const InputDecoration(
                      labelText: 'Categories (comma-separated)',
                    ),
                  ),
                  TextFormField(
                    controller: publishedYearController,
                    decoration: const InputDecoration(
                      labelText: 'Published Year',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  TextFormField(
                    controller: copiesController,
                    decoration: const InputDecoration(
                      labelText: 'Number of Copies',
                    ),
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (v?.isEmpty ?? true) return 'Required';
                      if (int.tryParse(v!) == null || int.parse(v) < 1) {
                        return 'Must be at least 1';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(context);
                  await _addBook(
                    titleController.text,
                    isbnController.text,
                    authorsController.text
                        .split(',')
                        .map((e) => e.trim())
                        .toList(),
                    categoriesController.text.isEmpty
                        ? []
                        : categoriesController.text
                              .split(',')
                              .map((e) => e.trim())
                              .toList(),
                    publishedYearController.text.isEmpty
                        ? null
                        : int.tryParse(publishedYearController.text),
                    int.parse(copiesController.text),
                    coverUrl,
                  );
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addBook(
    String title,
    String isbn,
    List<String> authors,
    List<String> categories,
    int? publishedYear,
    int numberOfCopies,
    String? coverUrl,
  ) async {
    // Show loading indicator
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              SizedBox(width: 16),
              Text('Adding book...'),
            ],
          ),
          duration: Duration(seconds: 30),
        ),
      );
    }

    try {
      final book = Book(
        id: '',
        title: title,
        isbn: isbn,
        authors: authors,
        categories: categories,
        publishedAt: publishedYear != null
            ? Timestamp.fromDate(DateTime(publishedYear))
            : Timestamp.now(),
        coverUrl: coverUrl ?? '',
        totalCopies: numberOfCopies,
        availableCopies: numberOfCopies,
      );

      debugPrint('Adding book: ${book.title} with $numberOfCopies copies');
      debugPrint('Cover URL: ${book.coverUrl}');
      await _bookService.addBook(book, numberOfCopies);
      debugPrint('Book added successfully, reloading list...');

      await _loadBooks();

      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Book added successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error adding book: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
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

  Future<void> _showEditBookDialog(Book book) async {
    final formKey = GlobalKey<FormState>();
    final titleController = TextEditingController(text: book.title);
    final isbnController = TextEditingController(text: book.isbn);
    final authorsController = TextEditingController(
      text: book.authors.join(', '),
    );
    final categoriesController = TextEditingController(
      text: book.categories.join(', '),
    );
    final publishedYear = book.publishedAt.toDate().year;
    final publishedYearController = TextEditingController(
      text: publishedYear.toString(),
    );
    String? coverUrl = book.coverUrl.isEmpty ? null : book.coverUrl;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Edit Book'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Image Preview
                  if (coverUrl != null && coverUrl!.isNotEmpty) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        coverUrl!,
                        height: 150,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          height: 150,
                          color: Colors.grey[300],
                          child: const Icon(Icons.broken_image, size: 50),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  // Add/Change Image Button
                  OutlinedButton.icon(
                    onPressed: () => _showImageSourceDialog((url) {
                      setState(() => coverUrl = url);
                    }),
                    icon: const Icon(Icons.add_photo_alternate),
                    label: Text(
                      (coverUrl?.isEmpty ?? true)
                          ? 'Add Cover Image'
                          : 'Change Image',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: titleController,
                    decoration: const InputDecoration(labelText: 'Title *'),
                    validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                  ),
                  TextFormField(
                    controller: isbnController,
                    decoration: const InputDecoration(labelText: 'ISBN *'),
                    validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                  ),
                  TextFormField(
                    controller: authorsController,
                    decoration: const InputDecoration(
                      labelText: 'Authors (comma-separated) *',
                    ),
                    validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                  ),
                  TextFormField(
                    controller: categoriesController,
                    decoration: const InputDecoration(
                      labelText: 'Categories (comma-separated) *',
                    ),
                    validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                  ),
                  TextFormField(
                    controller: publishedYearController,
                    decoration: const InputDecoration(
                      labelText: 'Published Year',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Total Copies: ${book.totalCopies}\nAvailable: ${book.availableCopies}',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(context);
                  await _updateBook(
                    book,
                    titleController.text.trim(),
                    isbnController.text.trim(),
                    authorsController.text,
                    categoriesController.text,
                    publishedYearController.text,
                    coverUrl,
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateBook(
    Book book,
    String title,
    String isbn,
    String authorsText,
    String categoriesText,
    String yearText,
    String? newCoverUrl,
  ) async {
    try {
      final authors = authorsText.split(',').map((e) => e.trim()).toList();
      final categories = categoriesText
          .split(',')
          .map((e) => e.trim())
          .toList();
      int? publishedYear = int.tryParse(yearText);

      final updatedBook = Book(
        id: book.id,
        title: title,
        isbn: isbn,
        authors: authors,
        categories: categories,
        publishedAt: publishedYear != null
            ? Timestamp.fromDate(DateTime(publishedYear))
            : book.publishedAt,
        coverUrl: newCoverUrl ?? book.coverUrl,
        totalCopies: book.totalCopies,
        availableCopies: book.availableCopies,
      );

      await _bookService.updateBook(updatedBook);
      await _loadBooks();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Book updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating book: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildPlaceholderCover() {
    return Container(
      width: 80,
      height: 120,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(Icons.book, size: 40, color: Colors.grey[600]),
    );
  }

  Future<void> _deleteBook(Book book) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Book'),
        content: Text('Are you sure you want to delete "${book.title}"?'),
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

    if (confirm != true) return;

    try {
      await _bookService.deleteBook(book.id);
      await _loadBooks();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Book deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error deleting book: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Books'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadBooks),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by title, author, or ISBN',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredBooks.isEmpty
                ? const Center(child: Text('No books found'))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    itemCount: _filteredBooks.length,
                    itemBuilder: (context, index) {
                      final book = _filteredBooks[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Book cover image
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: book.coverUrl.isNotEmpty
                                    ? Image.network(
                                        book.coverUrl,
                                        key: ValueKey(book.coverUrl),
                                        width: 80,
                                        height: 120,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) {
                                          debugPrint(
                                            'Error loading image for ${book.title}: $error',
                                          );
                                          return _buildPlaceholderCover();
                                        },
                                        loadingBuilder: (context, child, loadingProgress) {
                                          if (loadingProgress == null) {
                                            return child;
                                          }
                                          return Center(
                                            child: SizedBox(
                                              width: 80,
                                              height: 120,
                                              child: Center(
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
                                              ),
                                            ),
                                          );
                                        },
                                      )
                                    : _buildPlaceholderCover(),
                              ),
                              const SizedBox(width: 12),

                              // Book information
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Title
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

                                    // ISBN
                                    Text(
                                      'ISBN: ${book.isbn}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    const SizedBox(height: 4),

                                    // Authors
                                    Text(
                                      'Authors: ${book.authors.join(', ')}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[700],
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 8),

                                    // Available copies
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.book_outlined,
                                          size: 16,
                                          color: Colors.grey[600],
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Available: ${book.availableCopies}/${book.totalCopies}',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey[700],
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),

                                    // Action buttons
                                    Row(
                                      children: [
                                        Expanded(
                                          child: OutlinedButton.icon(
                                            onPressed: () =>
                                                _showEditBookDialog(book),
                                            icon: const Icon(
                                              Icons.edit,
                                              size: 16,
                                            ),
                                            label: const Text('Edit'),
                                            style: OutlinedButton.styleFrom(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 6,
                                                    horizontal: 12,
                                                  ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: OutlinedButton.icon(
                                            onPressed: () => _deleteBook(book),
                                            icon: const Icon(
                                              Icons.delete,
                                              size: 16,
                                            ),
                                            label: const Text('Delete'),
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: Colors.red,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 6,
                                                    horizontal: 12,
                                                  ),
                                            ),
                                          ),
                                        ),
                                      ],
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
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddBookDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}
