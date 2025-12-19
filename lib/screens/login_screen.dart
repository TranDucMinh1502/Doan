import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/notification_service.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  bool _isLoading = false;
  bool _isSignUp = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Vui lòng nhập email';
    }
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) {
      return 'Vui lòng nhập email hợp lệ';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Vui lòng nhập mật khẩu';
    }
    if (value.length < 6) {
      return 'Mật khẩu phải ít nhất 6 ký tự';
    }
    return null;
  }

  String? _validateName(String? value) {
    if (_isSignUp && (value == null || value.isEmpty)) {
      return 'Vui lòng nhập họ và tên';
    }
    return null;
  }

  String? _validatePhone(String? value) {
    if (_isSignUp && (value == null || value.isEmpty)) {
      return 'Vui lòng nhập số điện thoại';
    }
    if (_isSignUp && value!.isNotEmpty) {
      final phoneRegex = RegExp(r'^[0-9]{10,11}$');
      if (!phoneRegex.hasMatch(value)) {
        return 'Số điện thoại không hợp lệ';
      }
    }
    return null;
  }

  String? _validateAddress(String? value) {
    if (_isSignUp && (value == null || value.isEmpty)) {
      return 'Vui lòng nhập địa chỉ';
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (_isSignUp && (value == null || value.isEmpty)) {
      return 'Vui lòng xác nhận mật khẩu';
    }
    if (_isSignUp && value != _passwordController.text) {
      return 'Mật khẩu không khớp';
    }
    return null;
  }

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vui lòng nhập email để đặt lại mật khẩu'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Đã gửi email đặt lại mật khẩu. Vui lòng kiểm tra hộp thư.',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        String message = 'Không gửi được email đặt lại';
        switch (e.code) {
          case 'user-not-found':
            message = 'Không tìm thấy tài khoản với email này';
            break;
          case 'invalid-email':
            message = 'Email không hợp lệ';
            break;
          default:
            message = 'Lỗi: ${e.message}';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);
    try {
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      // Ensure user document exists
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(credential.user!.uid)
          .get();

      if (!userDoc.exists) {
        await _createUserProfile(credential.user!);
      }

      // Update FCM token
      await NotificationService().initialize();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đăng nhập thành công!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        String message = 'Đăng nhập thất bại';
        switch (e.code) {
          case 'user-not-found':
            message = 'Không tìm thấy tài khoản với email này';
            break;
          case 'wrong-password':
            message = 'Mật khẩu sai';
            break;
          case 'invalid-email':
            message = 'Email không hợp lệ';
            break;
          case 'user-disabled':
            message = 'Tài khoản này đã bị vô hiệu hóa';
            break;
          case 'too-many-requests':
            message = 'Quá nhiều lần thử. Vui lòng thử lại sau';
            break;
          default:
            message = 'Đăng nhập thất bại: ${e.message}';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã xảy ra lỗi: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);
    try {
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );

      await _createUserProfile(
        credential.user!,
        fullName: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        address: _addressController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tạo tài khoản thành công!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        String message = 'Tạo tài khoản thất bại';
        switch (e.code) {
          case 'weak-password':
            message = 'Mật khẩu quá yếu';
            break;
          case 'email-already-in-use':
            message = 'Đã có tài khoản sử dụng email này';
            break;
          case 'invalid-email':
            message = 'Email không hợp lệ';
            break;
          case 'operation-not-allowed':
            message = 'Tài khoản email/mật khẩu chưa được bật';
            break;
          default:
            message = 'Tạo tài khoản thất bại: ${e.message}';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã xảy ra lỗi: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _createUserProfile(
    User user, {
    String? fullName,
    String? phone,
    String? address,
  }) async {
    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'fullName': fullName ?? user.email?.split('@')[0] ?? 'User',
      'email': user.email ?? '',
      'phone': phone ?? '',
      'address': address ?? '',
      'role': 'member',
      'borrowedCount': 0,
      'maxBorrow': 3,
      'fcmTokens': [],
      'cardNumber': 'LIB-${user.uid.substring(0, 8).toUpperCase()}',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SafeArea(
        child: Column(
          children: [
            // Top gradient header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 40),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF6C5CE7), Color(0xFF7C4DFF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(32),
                  bottomRight: Radius.circular(32),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.local_library,
                    size: 64,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _isSignUp ? 'Tạo tài khoản' : 'Đăng nhập',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            // Form section
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(20),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Color.fromRGBO(0, 0, 0, 0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_isSignUp)
                          TextFormField(
                            controller: _nameController,
                            validator: _validateName,
                            decoration: InputDecoration(
                              hintText: 'Họ và tên',
                              filled: true,
                              fillColor: Colors.grey.shade100,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              prefixIcon: const Icon(Icons.person),
                            ),
                            textInputAction: TextInputAction.next,
                          ),
                        if (_isSignUp) const SizedBox(height: 12),

                        TextFormField(
                          controller: _emailController,
                          validator: _validateEmail,
                          decoration: InputDecoration(
                            hintText: 'Email',
                            filled: true,
                            fillColor: Colors.grey.shade100,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            prefixIcon: const Icon(Icons.email),
                          ),
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 12),

                        if (_isSignUp)
                          TextFormField(
                            controller: _phoneController,
                            validator: _validatePhone,
                            decoration: InputDecoration(
                              hintText: 'Số điện thoại',
                              filled: true,
                              fillColor: Colors.grey.shade100,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              prefixIcon: const Icon(Icons.phone),
                            ),
                            keyboardType: TextInputType.phone,
                            textInputAction: TextInputAction.next,
                          ),
                        if (_isSignUp) const SizedBox(height: 12),

                        if (_isSignUp)
                          TextFormField(
                            controller: _addressController,
                            validator: _validateAddress,
                            decoration: InputDecoration(
                              hintText: 'Địa chỉ',
                              filled: true,
                              fillColor: Colors.grey.shade100,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              prefixIcon: const Icon(Icons.location_on),
                            ),
                            textInputAction: TextInputAction.next,
                          ),
                        if (_isSignUp) const SizedBox(height: 12),

                        TextFormField(
                          controller: _passwordController,
                          validator: _validatePassword,
                          decoration: InputDecoration(
                            hintText: 'Mật khẩu',
                            filled: true,
                            fillColor: Colors.grey.shade100,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            prefixIcon: const Icon(Icons.lock),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                              onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword,
                              ),
                            ),
                          ),
                          obscureText: _obscurePassword,
                          textInputAction: _isSignUp
                              ? TextInputAction.next
                              : TextInputAction.done,
                          onFieldSubmitted: (_) => _isSignUp ? null : _signIn(),
                        ),
                        const SizedBox(height: 12),

                        if (_isSignUp)
                          TextFormField(
                            controller: _confirmPasswordController,
                            validator: _validateConfirmPassword,
                            decoration: InputDecoration(
                              hintText: 'Xác nhận mật khẩu',
                              filled: true,
                              fillColor: Colors.grey.shade100,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscureConfirmPassword
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                ),
                                onPressed: () => setState(
                                  () => _obscureConfirmPassword =
                                      !_obscureConfirmPassword,
                                ),
                              ),
                            ),
                            obscureText: _obscureConfirmPassword,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _signUp(),
                          ),
                        if (_isSignUp) const SizedBox(height: 12),

                        if (!_isSignUp)
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: _isLoading ? null : _resetPassword,
                              child: Text(
                                'Quên mật khẩu?',
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                            ),
                          ),

                        const SizedBox(height: 6),
                        // Gradient button
                        SizedBox(
                          width: double.infinity,
                          child: GestureDetector(
                            onTap: _isLoading
                                ? null
                                : (_isSignUp ? _signUp : _signIn),
                            child: Container(
                              height: 50,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF6C5CE7),
                                    Color(0xFF7C4DFF),
                                  ],
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                ),
                              ),
                              child: Center(
                                child: _isLoading
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : Text(
                                        _isSignUp ? 'Đăng ký' : 'Đăng nhập',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),
                        // Google sign-in button
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _isLoading
                                ? null
                                : () async {
                                    setState(() => _isLoading = true);
                                    try {
                                      final res = await AuthService()
                                          .signInWithGoogle(
                                            forceAccountSelection: true,
                                          );
                                      if (!mounted) return;
                                      if (res != null) {
                                        await NotificationService()
                                            .initialize();
                                        if (!mounted) return;
                                        // ignore: use_build_context_synchronously
                                        final messenger = ScaffoldMessenger.of(
                                          context,
                                        );
                                        // ignore: use_build_context_synchronously
                                        final navigator = Navigator.of(context);
                                        messenger.showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Đăng nhập bằng Google thành công',
                                            ),
                                            backgroundColor: Colors.green,
                                          ),
                                        );
                                        navigator.pop();
                                      }
                                    } catch (e) {
                                      if (mounted) {
                                        // ignore: use_build_context_synchronously
                                        final messenger = ScaffoldMessenger.of(
                                          context,
                                        );
                                        messenger.showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Lỗi đăng nhập Google: $e',
                                            ),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    } finally {
                                      if (mounted)
                                        setState(() => _isLoading = false);
                                    }
                                  },
                            icon: Image.asset(
                              'assets/google_logo.png',
                              height: 20,
                              errorBuilder: (c, e, s) =>
                                  const Icon(Icons.login),
                            ),
                            label: const Text('Đăng nhập với Google'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              side: BorderSide(color: Colors.grey.shade300),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: _isLoading
                              ? null
                              : () {
                                  setState(() {
                                    _isSignUp = !_isSignUp;
                                    _formKey.currentState?.reset();
                                  });
                                },
                          child: RichText(
                            text: TextSpan(
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                fontSize: 14,
                              ),
                              children: [
                                TextSpan(
                                  text: _isSignUp
                                      ? 'Đã có tài khoản? '
                                      : 'Chưa có tài khoản? ',
                                ),
                                TextSpan(
                                  text: _isSignUp ? 'Đăng nhập' : 'Đăng ký',
                                  style: const TextStyle(
                                    color: Color(0xFF6C5CE7),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }
}
