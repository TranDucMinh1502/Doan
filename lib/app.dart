import 'package:flutter/material.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/member/catalog_screen.dart';
import 'screens/member/book_detail.dart';
import 'screens/member/my_loans.dart';
import 'screens/librarian/dashboard.dart';
import 'screens/librarian/manage_books.dart';
import 'screens/librarian/manage_members.dart';
import 'screens/librarian/loans_returns.dart';
import 'screens/librarian/reservations.dart';

/// AppRouter handles all route generation for the app
class AppRouter {
  // Route names
  static const String login = '/login';
  static const String register = '/register';
  static const String catalog = '/catalog';
  static const String bookDetail = '/book-detail';
  static const String myLoans = '/my-loans';
  static const String librarianDashboard = '/librarian-dashboard';
  static const String manageBooks = '/manage-books';
  static const String manageMembers = '/manage-members';
  static const String loansReturns = '/loans-returns';
  static const String reservations = '/reservations';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case login:
        return MaterialPageRoute(builder: (_) => const LoginScreen());

      case register:
        return MaterialPageRoute(builder: (_) => const RegisterScreen());

      case catalog:
        return MaterialPageRoute(builder: (_) => const CatalogScreen());

      case bookDetail:
        final bookId = settings.arguments as String?;
        if (bookId == null) {
          return _errorRoute('Book ID is required');
        }
        return MaterialPageRoute(
          builder: (_) => BookDetailScreen(bookId: bookId),
        );

      case myLoans:
        return MaterialPageRoute(builder: (_) => const MyLoansScreen());

      case librarianDashboard:
        return MaterialPageRoute(builder: (_) => const LibrarianDashboard());

      case manageBooks:
        return MaterialPageRoute(builder: (_) => const ManageBooksScreen());

      case manageMembers:
        return MaterialPageRoute(builder: (_) => const ManageMembersScreen());

      case loansReturns:
        return MaterialPageRoute(builder: (_) => const LoansReturnsScreen());

      case reservations:
        return MaterialPageRoute(builder: (_) => const ReservationsScreen());

      default:
        return _errorRoute('Route not found: ${settings.name}');
    }
  }

  static Route<dynamic> _errorRoute(String message) {
    return MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                message,
                style: const TextStyle(fontSize: 18),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Go Back'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
