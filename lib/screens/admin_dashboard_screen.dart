import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  bool _loading = true;
  String _role = 'member';

  int _totalCopies = 0;
  int _currentlyLoaned = 0;
  String? _topStudentName;
  int _topStudentCount = 0;
  String? _topBookTitle;
  int _topBookCount = 0;

  @override
  void initState() {
    super.initState();
    _loadAndCompute();
  }

  // --- LOGIC TÍNH TOÁN DỮ LIỆU ---
  Future<void> _loadAndCompute() async {
    setState(() {
      _loading = true;
    });

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _role = 'member';
        _loading = false;
      });
      return;
    }

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final userData = userDoc.data();
      if (userData != null) {
        final dynamic roleField = userData['role'] ?? userData['roles'];
        if (roleField != null) {
          if (roleField is String) {
            _role = roleField.toLowerCase();
          } else if (roleField is List && roleField.isNotEmpty) {
            _role = roleField.first.toString().toLowerCase();
          } else {
            _role = roleField.toString().toLowerCase();
          }
        }
      }

      if (!(_role == 'admin' || _role == 'librarian')) {
        setState(() => _loading = false);
        return;
      }

      // 1. Lấy dữ liệu Sách
      final booksSnap = await FirebaseFirestore.instance.collection('books').get();
      int totalCopies = 0;
      final Map<String, String> bookTitles = {};
      for (final doc in booksSnap.docs) {
        final data = doc.data();
        final tc = (data['totalCopies'] ?? data['total'] ?? 0);
        if (tc is int) {
          totalCopies += tc;
        } else if (tc is String) {
          totalCopies += int.tryParse(tc) ?? 0;
        }
        bookTitles[doc.id] = (data['title'] ?? '') as String;
      }

      // 2. Lấy dữ liệu Mượn trả
      final loansSnap = await FirebaseFirestore.instance.collection('loans').get();
      int currentlyLoaned = 0;
      final Map<String, int> userCounts = {};
      final Map<String, int> bookCounts = {};

      for (final doc in loansSnap.docs) {
        final d = doc.data();
        final status = (d['status'] ?? '').toString();
        if (status == 'issued' || status == 'loaned') {
          currentlyLoaned += 1;
        }

        final uid = d['userId']?.toString() ?? '';
        if (uid.isNotEmpty) userCounts[uid] = (userCounts[uid] ?? 0) + 1;

        final bid = d['bookId']?.toString() ?? '';
        if (bid.isNotEmpty) bookCounts[bid] = (bookCounts[bid] ?? 0) + 1;
      }

      // 3. Tìm Top Student
      String? topUid;
      int topCount = 0;
      userCounts.forEach((k, v) {
        if (v > topCount) {
          topCount = v;
          topUid = k;
        }
      });

      String? topStudentName;
      if (topUid != null) {
        try {
          final udoc = await FirebaseFirestore.instance.collection('users').doc(topUid).get();
          final ud = udoc.data();
          if (ud != null) {
            topStudentName = (ud['fullName'] ?? ud['email'] ?? topUid).toString();
          } else {
            topStudentName = topUid;
          }
        } catch (_) {
          topStudentName = topUid;
        }
      }

      // 4. Tìm Top Book
      String? topBid;
      int topBCount = 0;
      bookCounts.forEach((k, v) {
        if (v > topBCount) {
          topBCount = v;
          topBid = k;
        }
      });

      String? topBookTitle;
      if (topBid != null) {
        topBookTitle = bookTitles[topBid] ?? topBid;
      }

      setState(() {
        _totalCopies = totalCopies;
        _currentlyLoaned = currentlyLoaned;
        _topStudentName = topStudentName;
        _topStudentCount = topCount;
        _topBookTitle = topBookTitle;
        _topBookCount = topBCount;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
      });
    }
  }

  // --- GIAO DIỆN CHÍNH ---
  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!(_role == 'admin' || _role == 'librarian')) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.security, size: 60, color: Colors.grey[400]),
              const SizedBox(height: 16),
              const Text('Bạn không có quyền truy cập', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ElevatedButton(onPressed: _loadAndCompute, child: const Text('Thử lại')),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA), // Màu nền hiện đại
      appBar: AppBar(
        title: const Text(
          'Dashboard Quản Lý',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black87),
            onPressed: _loadAndCompute,
          )
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tổng quan hệ thống',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.black87),
            ),
            const SizedBox(height: 16),
            
            // GridView thống kê (Đã sửa lỗi tràn)
            GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              shrinkWrap: true,
              // [FIX 1] Tỷ lệ 1.1 giúp thẻ cao hơn, không bị lỗi overflow pixel
              childAspectRatio: 1.1, 
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildModernStatCard(
                  'Tổng sách',
                  _totalCopies.toString(),
                  Icons.library_books,
                  [const Color(0xFF6C63FF), const Color(0xFF8B85FF)], // Purple Gradient
                ),
                _buildModernStatCard(
                  'Đang cho mượn',
                  _currentlyLoaned.toString(),
                  Icons.assignment_returned,
                  [const Color(0xFFFF9F43), const Color(0xFFFFC078)], // Orange Gradient
                ),
              ],
            ),

            const SizedBox(height: 30),
            
            const Text(
              'Bảng xếp hạng',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.black87),
            ),
            const SizedBox(height: 16),

            // Card Top Student
            _buildLeaderboardCard(
              title: 'Độc giả tích cực nhất',
              name: _topStudentName ?? 'Chưa có dữ liệu',
              count: _topStudentCount,
              icon: Icons.person_outline,
              badgeColor: Colors.blueAccent,
            ),
            
            const SizedBox(height: 16),

            // Card Top Book
            _buildLeaderboardCard(
              title: 'Cuốn sách Hot nhất',
              name: _topBookTitle ?? 'Chưa có dữ liệu',
              count: _topBookCount,
              icon: Icons.menu_book,
              badgeColor: Colors.redAccent,
            ),
            
            const SizedBox(height: 30),
            Center(
              child: Text(
                'Dữ liệu được cập nhật mới nhất',
                style: TextStyle(color: Colors.grey[400], fontSize: 12),
              ),
            )
          ],
        ),
      ),
    );
  }

  // --- WIDGET THẺ THỐNG KÊ (Đã sửa lỗi màu) ---
  Widget _buildModernStatCard(String label, String value, IconData icon, List<Color> gradientColors) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: gradientColors[0].withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14.0), 
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: Colors.white, size: 20),
                ),
                const Icon(Icons.trending_up, color: Colors.white54, size: 18),
              ],
            ),
            const Spacer(),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    value,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    // [ĐÃ SỬA LỖI Ở ĐÂY] Thay white90 bằng white70
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --- WIDGET BẢNG XẾP HẠNG ---
  Widget _buildLeaderboardCard({
    required String title,
    required String name,
    required int count,
    required IconData icon,
    required Color badgeColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: badgeColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: badgeColor, size: 28),
          ),
          const SizedBox(width: 16),
          
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: badgeColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Icon(Icons.emoji_events, color: Colors.white, size: 14),
                const SizedBox(width: 4),
                Text(
                  count.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}