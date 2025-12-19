// ignore_for_file: use_build_context_synchronously

import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/book.dart';
import 'book_detail_screen.dart';
import 'book_search_screen.dart';

class BookListScreen extends StatefulWidget {
  const BookListScreen({super.key});

  @override
  State<BookListScreen> createState() => _BookListScreenState();
}

class _BookListScreenState extends State<BookListScreen> {
  final _imagePicker = ImagePicker();
  String _userRole = 'member';

  @override
  void initState() {
    super.initState();
    _loadUserRole();
  }

  Future<void> _loadUserRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final data = doc.data();
      if (data != null && data['role'] != null) {
        setState(() => _userRole = data['role'].toString());
      }
    } catch (_) {}
  }

  Future<String?> _pickAndUploadCover() async {
    try {
      final XFile? file = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 80,
      );
      if (file == null) return null;
      final ref = FirebaseStorage.instance
          .ref()
          .child('book_covers')
          .child('${DateTime.now().millisecondsSinceEpoch}.jpg');
      await ref.putFile(File(file.path));
      return await ref.getDownloadURL();
    } catch (_) {
      return null;
    }
  }

  Future<void> _showBookForm({Book? book}) async {
    final titleCtrl = TextEditingController(text: book?.title ?? '');
    final authorsCtrl = TextEditingController(
      text: book != null ? book.authors.join(', ') : '',
    );
    final isbnCtrl = TextEditingController(text: book?.isbn ?? '');
    final totalCtrl = TextEditingController(
      text: book?.totalCopies.toString() ?? '0',
    );
    final availableCtrl = TextEditingController(
      text: book?.availableCopies.toString() ?? '',
    );
    final categoriesCtrl = TextEditingController(text: '');
    final descCtrl = TextEditingController(text: book?.description ?? '');
    final coverUrlCtrl = TextEditingController(text: book?.coverImageUrl ?? '');
    final publishedCtrl = TextEditingController(text: '');
    String? coverUrl = coverUrlCtrl.text.isNotEmpty ? coverUrlCtrl.text : null;
    DateTime? publishedDate;

    // try to populate extra fields when editing
    if (book != null) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('books')
            .doc(book.id)
            .get();
        final data = doc.data();
        if (data != null) {
          if (data['categories'] is List) {
            categoriesCtrl.text = (data['categories'] as List)
                .map((e) => e.toString())
                .join(', ');
          }
          if (data['availableCopies'] != null) {
            availableCtrl.text = data['availableCopies'].toString();
          }
          if (data['coverUrl'] != null && coverUrlCtrl.text.isEmpty) {
            coverUrlCtrl.text = data['coverUrl'];
          }
          if (data['publishedAt'] is Timestamp) {
            publishedDate = (data['publishedAt'] as Timestamp).toDate();
            publishedCtrl.text =
                '${publishedDate.year}-${publishedDate.month.toString().padLeft(2, '0')}-${publishedDate.day.toString().padLeft(2, '0')}';
          }
        }
      } catch (_) {}
    }

    // show modal and then use context safely after awaiting
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx2, setStateModal) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      book == null ? 'Thêm sách' : 'Chỉnh sửa sách',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: titleCtrl,
                      decoration: const InputDecoration(labelText: 'Tiêu đề'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: authorsCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Tác giả (phân cách bằng dấu ,)',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: isbnCtrl,
                      decoration: const InputDecoration(labelText: 'ISBN'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: totalCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Tổng số bản',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: availableCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Số bản khả dụng (để trống = tổng số)',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: categoriesCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Thể loại (phân cách bằng dấu ,)',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: descCtrl,
                      decoration: const InputDecoration(labelText: 'Mô tả'),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: publishedCtrl,
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: 'Ngày xuất bản',
                      ),
                      onTap: () async {
                        final now = DateTime.now();
                        final picked = await showDatePicker(
                          context: ctx2,
                          initialDate: publishedDate ?? now,
                          firstDate: DateTime(1900),
                          lastDate: now,
                        );
                        if (picked != null) {
                          publishedDate = picked;
                          publishedCtrl.text =
                              '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
                          setStateModal(() {});
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: () async {
                            final url = await _pickAndUploadCover();
                            if (url != null) {
                              coverUrl = url;
                              coverUrlCtrl.text = url;
                              setStateModal(() {});
                            }
                          },
                          icon: const Icon(Icons.photo),
                          label: const Text('Chọn ảnh bìa'),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: coverUrlCtrl,
                            decoration: const InputDecoration(
                              labelText: 'URL ảnh bìa (hoặc dùng nút chọn)',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Hủy'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () async {
                            final nav = Navigator.of(ctx);
                            final title = titleCtrl.text.trim();
                            if (title.isEmpty) return;
                            final authors = authorsCtrl.text
                                .split(',')
                                .map((s) => s.trim())
                                .where((s) => s.isNotEmpty)
                                .toList();
                            final isbn = isbnCtrl.text.trim();
                            final total =
                                int.tryParse(totalCtrl.text.trim()) ?? 0;
                            final available =
                                int.tryParse(availableCtrl.text.trim()) ??
                                total;
                            final desc = descCtrl.text.trim();

                            final Map<String, dynamic> data = {
                              'title': title,
                              'authors': authors,
                              'isbn': isbn,
                              'totalCopies': total,
                              'availableCopies': available,
                              'description': desc,
                              'coverImageUrl': coverUrl ?? coverUrlCtrl.text,
                            };

                            final categories = categoriesCtrl.text
                                .split(',')
                                .map((s) => s.trim())
                                .where((s) => s.isNotEmpty)
                                .toList();
                            if (categories.isNotEmpty) {
                              data['categories'] = categories;
                            }

                            final coverManual = coverUrlCtrl.text.trim();
                            if (coverManual.isNotEmpty) {
                              data['coverUrl'] = coverManual;
                            }

                            if (publishedDate != null) {
                              data['publishedAt'] = Timestamp.fromDate(
                                publishedDate!,
                              );
                            }

                            if (book == null) {
                              await FirebaseFirestore.instance
                                  .collection('books')
                                  .add(data);
                            } else {
                              await FirebaseFirestore.instance
                                  .collection('books')
                                  .doc(book.id)
                                  .update(data);
                            }

                            nav.pop(true);
                          },
                          child: const Text('Lưu'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (result == true) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lưu thông tin sách thành công')),
      );
    }
  }

  Future<void> _deleteBook(Book book) async {
    // will use context after awaiting; don't capture messenger before await
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Xóa sách'),
        content: const Text('Bạn có chắc muốn xóa sách này?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await FirebaseFirestore.instance.collection('books').doc(book.id).delete();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Đã xóa sách')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Books Catalog'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BookSearchScreen()),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('books').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final books = snapshot.data!.docs
              .map((doc) => Book.fromDoc(doc))
              .toList();

          if (books.isEmpty) {
            return const Center(child: Text('No books available'));
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 12),
            itemCount: books.length,
            itemBuilder: (context, index) {
              final book = books[index];
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Color.fromRGBO(0, 0, 0, 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => BookDetailScreen(book: book),
                      ),
                    );
                  },
                  child: Row(
                    children: [
                      // Leading avatar / cover
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: Colors.purple.shade50,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Icon(
                            Icons.book,
                            color: Colors.purple.shade400,
                            size: 26,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Title & meta
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              book.title,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Author: ${book.authors.isNotEmpty ? book.authors.join(", ") : "Unknown"}',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Available: ${book.availableCopies}/${book.totalCopies}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Actions
                      // show edit/delete only for librarians or admins
                      if (_userRole == 'librarian' || _userRole == 'admin')
                        PopupMenuButton<String>(
                          onSelected: (v) async {
                            if (v == 'edit') {
                              await _showBookForm(book: book);
                            } else if (v == 'delete') {
                              await _deleteBook(book);
                            }
                          },
                          itemBuilder: (c) => const [
                            PopupMenuItem(
                              value: 'edit',
                              child: Text('Chỉnh sửa'),
                            ),
                            PopupMenuItem(value: 'delete', child: Text('Xóa')),
                          ],
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: (_userRole == 'librarian' || _userRole == 'admin')
          ? FloatingActionButton(
              onPressed: () => _showBookForm(),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}
