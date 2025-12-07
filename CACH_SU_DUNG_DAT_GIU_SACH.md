# 📚 Hướng Dẫn Sử Dụng Chức Năng Đặt Giữ Sách

## ✅ Chức Năng Đã Hoàn Thiện

### 1. 🔖 Đặt Giữ Sách (Reserve Book)

#### Khi nào có thể đặt giữ?

- ✅ Khi sách **không có sẵn** (availableCopies = 0)
- ✅ Tất cả các bản sao đã được mượn
- ✅ Member muốn được thông báo khi sách có sẵn trở lại

#### Cách đặt giữ sách:

1. **Vào Book Details Screen**

   - Từ Catalog, click vào bất kỳ cuốn sách nào
   - Xem thông tin chi tiết về sách

2. **Kiểm tra trạng thái**

   - Nếu `Available Copies: 0` → Hiển thị nút **"Đặt giữ"** màu cam
   - Nếu có sách available → Hiển thị nút **"Mượn"** màu xanh

3. **Click nút "Đặt giữ"**

   - Hiện dialog xác nhận với thông tin:
     - Tên sách và hình ảnh
     - Lưu ý về quy trình đặt giữ
   - Click **"Xác nhận đặt giữ"**

4. **Kết quả**
   - ✅ Thông báo: "Đặt giữ sách thành công!"
   - ✅ Reservation được tạo với status "waiting"
   - ✅ Vào hàng đợi chờ sách có sẵn

#### Thông tin hiển thị trong dialog:

```
📖 [Hình ảnh sách]

Tiêu đề sách
Tác giả: XXX
Xuất bản: YYYY

⚠️ Lưu ý:
• Sách hiện không có sẵn
• Bạn sẽ vào hàng đợi
• Thông báo khi sách có sẵn
• Có 3 ngày để mượn khi được thông báo
```

---

### 2. 📋 Xem Danh Sách Đặt Giữ

#### Vào màn hình Reservations:

- Từ Bottom Navigation Bar → Click **"Reservations"** (icon bookmark)
- Hiển thị tất cả reservations của user

#### Các trạng thái reservation:

**🟡 Waiting** (Đang chờ)

- Sách vẫn chưa có sẵn
- Đang trong hàng đợi
- Có thể **Cancel** bất kỳ lúc nào

**🟢 Notified** (Đã thông báo)

- Sách đã có sẵn!
- Có 3 ngày để mượn
- Có nút **"Borrow Now"** để mượn ngay
- Có thể **Cancel** nếu không muốn mượn nữa

**🔴 Canceled** (Đã hủy)

- User đã hủy reservation
- Không thể thao tác gì thêm

**🔵 Fulfilled** (Đã hoàn thành)

- User đã mượn sách thành công
- Reservation chuyển thành Loan

---

### 3. ❌ Hủy Đặt Giữ

#### Cách hủy:

1. **Vào màn hình Reservations**
2. **Tìm reservation muốn hủy**
   - Chỉ có thể hủy status: `waiting` hoặc `notified`
3. **Click nút "Cancel"**
   - Dialog xác nhận: "Are you sure you want to cancel this reservation?"
   - Click **"Yes, Cancel"**
4. **Kết quả**
   - ✅ Status chuyển thành "canceled"
   - ✅ Thông báo: "Reservation canceled successfully"

---

### 4. 📚 Mượn Sách Từ Reservation

#### Khi được thông báo (status = notified):

1. **Vào màn hình Reservations**
2. **Tìm reservation có status "Notified"**
   - Badge màu xanh: "Ready to borrow"
   - Hiển thị countdown: "X days left"
3. **Click nút "Borrow Now"**
   - Dialog xác nhận
   - Click **"Confirm"**
4. **Kết quả**
   - ✅ Tạo Loan mới
   - ✅ Reservation status → "fulfilled"
   - ✅ Book item status → "borrowed"
   - ✅ Thông báo: "Book borrowed successfully!"

---

## 🎯 Quy Trình Hoàn Chỉnh

### Scenario 1: Đặt giữ sách đang hết

```
Member → Book Details (availableCopies = 0)
       ↓
   Click "Đặt giữ"
       ↓
   Xác nhận dialog
       ↓
   ✅ Reservation created (status: waiting)
       ↓
   Vào hàng đợi
```

### Scenario 2: Được thông báo và mượn

```
Librarian trả sách (Return Book)
       ↓
   System tự động notify reservation đầu tiên
       ↓
   Reservation status: waiting → notified
       ↓
   Member nhận thông báo
       ↓
   Member vào Reservations → Click "Borrow Now"
       ↓
   ✅ Loan created
   ✅ Reservation status: notified → fulfilled
```

### Scenario 3: Hủy đặt giữ

```
Member → Reservations
       ↓
   Tìm reservation (waiting/notified)
       ↓
   Click "Cancel"
       ↓
   Xác nhận
       ↓
   ✅ Reservation status: canceled
   ✅ Rời khỏi hàng đợi
```

---

## 🔧 Code Structure

### Files liên quan:

```
lib/
├── models/
│   └── reservation_model.dart          # Reservation data model
├── services/
│   └── reservation_service.dart        # Business logic
├── screens/
│   └── member/
│       ├── book_detail.dart            # Nút "Đặt giữ"
│       └── my_reservations.dart        # Danh sách reservations
└── main.dart                           # Navigation setup
```

### Key Methods:

#### ReservationService:

- `reserveBook(userId, bookId)` - Tạo reservation mới
- `getUserReservations(userId)` - Lấy danh sách reservations
- `cancelReservation(reservationId)` - Hủy reservation
- `notifyNextReservation(bookId, itemId)` - Thông báo người tiếp theo
- `borrowReservedBook(reservationId, userId)` - Mượn từ reservation

#### UI Components:

- `_handleReserve()` - Handle nút "Đặt giữ"
- `_showReserveConfirmDialog()` - Dialog xác nhận
- `_handleCancel(reservation)` - Hủy reservation
- `_handleBorrowNow(reservation)` - Mượn từ reservation

---

## 🎨 UI Elements

### Book Detail Screen:

**Khi sách không có sẵn:**

```dart
ElevatedButton.icon(
  onPressed: _handleReserve,
  icon: Icon(Icons.bookmark_add),
  label: Text('Đặt giữ'),
  style: ElevatedButton.styleFrom(
    backgroundColor: Colors.orange,  // Màu cam
  ),
)
```

**Khi sách có sẵn:**

```dart
ElevatedButton.icon(
  onPressed: _handleBorrow,
  icon: Icon(Icons.check),
  label: Text('Mượn'),
  style: ElevatedButton.styleFrom(
    backgroundColor: Colors.green,  // Màu xanh
  ),
)
```

### Reservations Screen:

**Status badges:**

- 🟡 Waiting: `Colors.orange` / `Icons.hourglass_empty`
- 🟢 Notified: `Colors.green` / `Icons.notifications_active`
- 🔴 Canceled: `Colors.red` / `Icons.cancel`
- 🔵 Fulfilled: `Colors.blue` / `Icons.check_circle`

---

## ✅ Testing Checklist

### Test Case 1: Đặt giữ sách thành công

- [ ] Login as Member
- [ ] Tìm sách có `availableCopies = 0`
- [ ] Click "Đặt giữ"
- [ ] Xác nhận dialog
- [ ] Kiểm tra thông báo thành công
- [ ] Vào Reservations → Thấy reservation mới (status: waiting)

### Test Case 2: Không thể đặt giữ trùng

- [ ] Đặt giữ sách A
- [ ] Thử đặt giữ sách A lần nữa
- [ ] Expect: Error "You already have an active reservation for this book."

### Test Case 3: Hủy reservation

- [ ] Vào Reservations
- [ ] Click "Cancel" trên reservation
- [ ] Xác nhận
- [ ] Kiểm tra status → "canceled"

### Test Case 4: Mượn từ reservation

- [ ] Librarian trả sách → notify reservation
- [ ] Member vào Reservations
- [ ] Thấy status "Notified" + "Borrow Now" button
- [ ] Click "Borrow Now"
- [ ] Kiểm tra Loan được tạo
- [ ] Kiểm tra Reservation status → "fulfilled"

---

## 🚀 Features Đã Implement

✅ **Reserve Book** - Đặt giữ sách không có sẵn
✅ **View Reservations** - Xem danh sách đặt giữ
✅ **Cancel Reservation** - Hủy đặt giữ
✅ **Borrow from Reservation** - Mượn khi được thông báo
✅ **Auto Notification** - Tự động thông báo khi sách có sẵn
✅ **Queue System** - Hệ thống hàng đợi FIFO
✅ **Validation** - Không đặt giữ trùng
✅ **3-day Window** - Có 3 ngày để mượn khi được thông báo
✅ **Status Management** - Quản lý các trạng thái reservation
✅ **UI Integration** - Tích hợp vào Bottom Navigation

---

## 📱 Navigation Flow

```
Member Home (Bottom Navigation)
│
├── 📚 Catalog
│   └── Book Details
│       └── Nút "Đặt giữ" (nếu không có sẵn)
│
├── 📖 My Loans
│   └── Danh sách sách đang mượn
│
├── 🔖 Reservations  ← CHỨC NĂNG ĐẶT GIỮ
│   └── My Reservations Screen
│       ├── Waiting reservations (Cancel)
│       ├── Notified reservations (Borrow Now / Cancel)
│       ├── Canceled reservations (View only)
│       └── Fulfilled reservations (View only)
│
└── 👤 Profile
    └── Thông tin cá nhân
```

---

## 🎯 Kết Luận

Chức năng **Đặt giữ sách** đã được implement đầy đủ và hoàn chỉnh:

1. ✅ Member có thể đặt giữ sách không có sẵn
2. ✅ Xem danh sách reservations với các trạng thái khác nhau
3. ✅ Hủy reservation bất kỳ lúc nào
4. ✅ Mượn sách khi được thông báo (trong 3 ngày)
5. ✅ Hệ thống queue tự động quản lý thứ tự
6. ✅ UI đầy đủ với dialog xác nhận và thông báo
7. ✅ Validation để tránh đặt giữ trùng
8. ✅ Tích hợp vào navigation của app

**Tất cả đã sẵn sàng để sử dụng! 🎉**
