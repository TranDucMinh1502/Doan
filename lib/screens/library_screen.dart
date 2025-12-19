import 'package:flutter/material.dart';
import 'my_loans_screen.dart';
import 'my_reservations_screen.dart';

class LibraryScreen extends StatelessWidget {
  final String userId;

  const LibraryScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.grey.shade100,
        appBar: AppBar(
          title: const Text('Thư viện của tôi'),
          centerTitle: true,
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          elevation: 0,
          bottom: TabBar(
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
            tabs: const [
              Tab(icon: Icon(Icons.library_books), text: 'Đang mượn'),
              Tab(icon: Icon(Icons.bookmark), text: 'Đã đặt trước'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            MyLoansScreen(userId: userId),
            MyReservationsScreen(userId: userId),
          ],
        ),
      ),
    );
  }
}
