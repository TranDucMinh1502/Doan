import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  final String id;
  final String fullName;
  final String email;
  final String phone;
  final String address;
  final String photoUrl;
  final String role; // 'member' | 'librarian'
  final int borrowedCount;
  final int maxBorrow;
  final List<String> fcmTokens;

  AppUser({
    required this.id,
    required this.fullName,
    required this.email,
    this.phone = '',
    this.address = '',
    this.photoUrl = '',
    this.role = 'member',
    this.borrowedCount = 0,
    this.maxBorrow = 3,
    this.fcmTokens = const [],
  });

  factory AppUser.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return AppUser(
      id: doc.id,
      fullName: d['fullName'] ?? '',
      email: d['email'] ?? '',
      phone: d['phone'] ?? '',
      address: d['address'] ?? '',
      photoUrl: d['photoUrl'] ?? '',
      role: d['role'] ?? 'member',
      borrowedCount: d['borrowedCount'] ?? 0,
      maxBorrow: d['maxBorrow'] ?? 3,
      fcmTokens: List<String>.from(d['fcmTokens'] ?? []),
    );
  }

  Map<String, dynamic> toMap() => {
    'phone': phone,
    'address': address,
    'photoUrl': photoUrl,
    'fullName': fullName,
    'email': email,
    'role': role,
    'borrowedCount': borrowedCount,
    'maxBorrow': maxBorrow,
    'fcmTokens': fcmTokens,
  };
}
