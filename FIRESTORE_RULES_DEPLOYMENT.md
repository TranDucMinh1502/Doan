# Firestore Security Rules Deployment

## 📋 Hướng dẫn cập nhật Firestore Rules

### Bước 1: Truy cập Firebase Console

1. Mở [Firebase Console](https://console.firebase.google.com/)
2. Chọn project của bạn

### Bước 2: Mở Firestore Rules

1. Trong menu bên trái, chọn **Firestore Database**
2. Click vào tab **Rules** ở phía trên

### Bước 3: Copy Rules

1. Mở file `firestore.rules` trong project này
2. Copy toàn bộ nội dung
3. Paste vào Firebase Console (thay thế rules cũ)

### Bước 4: Publish

1. Click nút **Publish** màu xanh
2. Đợi vài giây để rules được cập nhật

## ✅ Rules đã bao gồm:

### Member Permissions:

- ✓ Tạo và đọc profile của chính mình
- ✓ Cập nhật thông tin cá nhân
- ✓ Tạo loans (checkout books)
- ✓ Gia hạn loans của mình
- ✓ Tạo và hủy reservations
- ✓ Đọc tất cả books và book items

### Librarian Permissions:

- ✓ Toàn quyền quản lý books, book items
- ✓ Quản lý tất cả loans và reservations
- ✓ Xem và cập nhật thông tin users
- ✓ Quản lý fines

## 🔒 Security Features:

- User chỉ có thể đọc/ghi dữ liệu của chính mình
- Librarian có quyền quản trị đầy đủ
- Validate role trước khi cho phép thao tác
- Bảo vệ khỏi truy cập trái phép

## ⚠️ Lưu ý:

- Rules phải được deploy để app hoạt động đúng
- Không deploy rules sẽ dẫn đến lỗi permission denied
- Kiểm tra lại role của users trong Firestore (phải là 'member' hoặc 'librarian')
