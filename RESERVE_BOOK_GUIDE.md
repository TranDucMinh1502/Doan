# 📚 Hướng dẫn Đặt giữ sách (Reserve Book)

## 🎯 Tổng quan

Chức năng **Reserve Book** (Đặt giữ sách) cho phép member đặt giữ sách khi không có bản sao nào available. Hệ thống sẽ thông báo khi sách có sẵn.

---

## 🔍 Khi nào có nút Reserve?

Nút **"Reserve"** (màu cam) chỉ hiện khi:

- ✅ User đã đăng nhập
- ✅ User có role = "member"
- ✅ Sách **KHÔNG có** bản sao available (`availableCopies = 0`)
- ✅ Tất cả book items đều đã được mượn

Nếu có ít nhất 1 bản sao available → hiện nút **"Borrow"** màu xanh thay vì Reserve.

---

## 📝 Workflow đặt giữ sách

### **Bước 1: Tìm sách không có sẵn**

```
Member Home → Catalog → Chọn sách → Book Details
→ Thấy "Available Copies: 0 / X"
→ Nút "Reserve" màu cam xuất hiện
```

### **Bước 2: Click nút Reserve**

Member click vào nút **"Reserve"**

### **Bước 3: Dialog xác nhận**

Hệ thống hiển thị dialog với:

```
┌───────────────────────────────────┐
│  🔖 Đặt giữ sách                  │
├───────────────────────────────────┤
│                                   │
│  Bạn muốn đặt giữ sách:          │
│                                   │
│  ┌─────────────────────────────┐ │
│  │ [Cover] Tên sách            │ │
│  │         Tác giả             │ │
│  └─────────────────────────────┘ │
│                                   │
│  ⚠️ Lưu ý:                        │
│  • Sách hiện không có sẵn         │
│  • Bạn sẽ vào hàng đợi            │
│  • Thông báo khi sách có sẵn      │
│  • Có 3 ngày để mượn khi được     │
│    thông báo                      │
│                                   │
│      [Hủy]  [Xác nhận đặt giữ]   │
└───────────────────────────────────┘
```

### **Bước 4: Xác nhận**

Member click **"Xác nhận đặt giữ"**

### **Bước 5: Hệ thống xử lý**

**Validation:**

```dart
1. Check user tồn tại
2. Check book tồn tại
3. Check user chưa có reservation active cho sách này
   - Query reservations where:
     * userId = currentUser.uid
     * bookId = selectedBook.id
     * status IN ['waiting', 'notified']
```

**Tạo Reservation:**

```dart
Reservation {
  id: auto-generated
  userId: member.uid
  bookId: book.id
  itemId: null (chưa có item cụ thể)
  reservedAt: DateTime.now()
  status: "waiting" (đang chờ)
}
```

### **Bước 6: Thông báo kết quả**

**Thành công:** ✅

```
Snackbar màu xanh:
"Đặt giữ sách thành công! Bạn sẽ được thông báo khi sách có sẵn."
```

**Thất bại:** ❌

_Trường hợp 1: Đã đặt giữ rồi_

```
Snackbar màu đỏ:
"Bạn đã đặt giữ sách này rồi. Kiểm tra tab Reservations."
```

_Trường hợp 2: Lỗi permission_

```
Snackbar màu đỏ:
"Lỗi quyền truy cập. Vui lòng kiểm tra Firestore rules."
```

_Trường hợp 3: Lỗi khác_

```
Snackbar màu đỏ:
"Lỗi: [chi tiết lỗi]"
```

---

## 🔄 Lifecycle của Reservation

```
1. WAITING (Đang chờ)
   └─ Member vừa đặt giữ
   └─ Đang trong hàng đợi
   └─ Có thể Cancel

2. NOTIFIED (Đã thông báo)
   └─ Sách có sẵn, hệ thống đã thông báo
   └─ Member có 3 ngày để mượn
   └─ Vẫn có thể Cancel

3. FULFILLED (Đã hoàn thành)
   └─ Member đã mượn sách
   └─ itemId được gán
   └─ Không thể Cancel

4. CANCELLED (Đã hủy)
   └─ Member hoặc Librarian đã hủy
   └─ Không thể phục hồi
```

---

## 👀 Xem danh sách Reservations

**Vị trí:** Member Home → Tab "Reservations" (tab thứ 3)

**Hiển thị:**

```
┌──────────────────────────────────┐
│  📚 My Reservations              │
├──────────────────────────────────┤
│                                  │
│  🟡 WAITING                      │
│  ┌────────────────────────────┐ │
│  │ [Cover] Tên sách           │ │
│  │ Reserved: 2024-12-07       │ │
│  │ [Cancel Reservation]       │ │
│  └────────────────────────────┘ │
│                                  │
│  🟢 NOTIFIED                     │
│  ┌────────────────────────────┐ │
│  │ [Cover] Tên sách           │ │
│  │ Notified: 2024-12-06       │ │
│  │ Valid until: 2024-12-09    │ │
│  │ [Borrow Now] [Cancel]      │ │
│  └────────────────────────────┘ │
│                                  │
└──────────────────────────────────┘
```

---

## 🔔 Notification Flow

### Khi nào được thông báo?

**Trigger:** Khi sách được trả (book item status → "available")

**Hệ thống tự động:**

```dart
1. Tìm reservation sớm nhất có:
   - bookId = returned book
   - status = "waiting"
   - ORDER BY reservedAt ASC
   - LIMIT 1

2. Update reservation:
   - status: "waiting" → "notified"
   - notifiedAt: DateTime.now()
   - itemId: available item.id

3. Gửi notification cho member:
   - In-app notification
   - Email (optional)
   - Push notification (optional)

4. Set expiry: notifiedAt + 3 days
```

### Member nhận thông báo:

**Option 1: Borrow ngay**

- Vào Reservations → Click "Borrow Now"
- Tự động checkout book item đã được reserve

**Option 2: Cancel**

- Nếu không muốn mượn nữa
- Click "Cancel Reservation"
- Sách sẽ chuyển cho member tiếp theo trong queue

**Option 3: Không làm gì**

- Sau 3 ngày tự động expire
- Status: "notified" → "cancelled"
- Sách chuyển cho member tiếp theo

---

## ⚙️ Code Implementation

### File: `book_detail.dart`

**1. Hiển thị nút Reserve:**

```dart
// Chỉ hiện khi không có available items
if (_availableItems.isEmpty)
  ElevatedButton.icon(
    onPressed: _isProcessing ? null : _handleReserve,
    icon: const Icon(Icons.bookmark_add),
    label: Text('Reserve'),
    style: ElevatedButton.styleFrom(
      backgroundColor: Colors.orange,
    ),
  )
```

**2. Handle Reserve:**

```dart
Future<void> _handleReserve() async {
  // Validation
  if (_currentUser == null || _book == null) return;

  // Show confirmation dialog
  final confirmed = await _showReserveConfirmDialog();
  if (confirmed != true) return;

  // Call service
  await _reservationService.reserveBook(
    _currentUser!.uid,
    _book!.id,
  );

  // Show success message
  _showMessage('Đặt giữ sách thành công!', isSuccess: true);
}
```

**3. Confirmation Dialog:**

```dart
Future<bool?> _showReserveConfirmDialog() async {
  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Row(
        children: [
          Icon(Icons.bookmark_add, color: Colors.orange),
          SizedBox(width: 8),
          Text('Đặt giữ sách'),
        ],
      ),
      content: [
        // Book info with cover
        // Warning box với info
      ],
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text('Hủy'),
        ),
        ElevatedButton.icon(
          onPressed: () => Navigator.pop(context, true),
          icon: Icon(Icons.bookmark_add),
          label: Text('Xác nhận đặt giữ'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
          ),
        ),
      ],
    ),
  );
}
```

### File: `reservation_service.dart`

**Reserve Book:**

```dart
Future<void> reserveBook(String userId, String bookId) async {
  // Validate parameters
  if (userId.isEmpty || bookId.isEmpty) {
    throw Exception('User ID and Book ID cannot be empty.');
  }

  // Check duplicate reservation
  final existingReservations = await _firestore
      .collection('reservations')
      .where('userId', isEqualTo: userId)
      .where('bookId', isEqualTo: bookId)
      .where('status', whereIn: ['waiting', 'notified'])
      .get();

  if (existingReservations.docs.isNotEmpty) {
    throw Exception(
      'You already have an active reservation for this book.',
    );
  }

  // Verify book and user exist
  final bookDoc = await _firestore.collection('books').doc(bookId).get();
  if (!bookDoc.exists) {
    throw Exception('Book not found.');
  }

  final userDoc = await _firestore.collection('users').doc(userId).get();
  if (!userDoc.exists) {
    throw Exception('User not found.');
  }

  // Create reservation
  final reservationRef = _firestore.collection('reservations').doc();
  final Reservation reservation = Reservation(
    id: reservationRef.id,
    userId: userId,
    bookId: bookId,
    itemId: null,
    reservedAt: Timestamp.now(),
    status: 'waiting',
  );

  await reservationRef.set(reservation.toJson());
}
```

---

## 🎨 UI/UX Features

### ✨ Cải tiến mới:

1. **Dialog xác nhận đẹp mắt:**

   - Hiển thị cover sách
   - Info box màu cam với warning
   - Rõ ràng về quy trình

2. **Snackbar với icon:**

   - ✅ Màu xanh + check icon khi thành công
   - ❌ Màu đỏ + error icon khi thất bại
   - Dễ phân biệt

3. **Loading state:**

   - Disable button khi đang xử lý
   - CircularProgressIndicator
   - Prevent double-tap

4. **Error handling tốt:**

   - Thông báo lỗi cụ thể (duplicate, permission, v.v.)
   - Gợi ý hướng giải quyết
   - Tiếng Việt dễ hiểu

5. **Auto-reload:**
   - Sau khi reserve thành công
   - UI tự động update
   - Không cần refresh thủ công

---

## 🧪 Testing Scenarios

### Test 1: Reserve sách thành công

```
1. Login với member account
2. Tìm sách có availableCopies = 0
3. Click "Reserve" → Dialog xuất hiện
4. Click "Xác nhận đặt giữ"
5. Expected: Snackbar xanh "Đặt giữ sách thành công!"
6. Vào tab "Reservations" → Thấy reservation với status "WAITING"
```

### Test 2: Reserve sách đã reserve

```
1. Reserve sách lần 1 → Thành công
2. Quay lại Book Details
3. Click "Reserve" lại → Dialog xuất hiện
4. Click "Xác nhận đặt giữ"
5. Expected: Snackbar đỏ "Bạn đã đặt giữ sách này rồi..."
```

### Test 3: Cancel trong dialog

```
1. Click "Reserve" → Dialog xuất hiện
2. Click "Hủy"
3. Expected: Dialog đóng, không làm gì
```

### Test 4: Reserve khi chưa login

```
1. Logout
2. Vào Book Details của sách có availableCopies = 0
3. Expected: Nút "Reserve" KHÔNG hiển thị
4. Hiển thị text "Please sign in to borrow or reserve books"
```

### Test 5: Sách có available → không có nút Reserve

```
1. Tìm sách có availableCopies > 0
2. Expected: Hiển thị nút "Borrow" màu xanh
3. KHÔNG hiển thị nút "Reserve"
```

---

## 🔒 Security & Permissions

### Firestore Rules:

```javascript
// Allow member to create reservation
match /reservations/{reservationId} {
  allow create: if request.auth != null
    && request.auth.uid == request.resource.data.userId
    && get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'member';

  allow read: if request.auth != null
    && request.auth.uid == resource.data.userId;

  allow update: if request.auth != null
    && request.auth.uid == resource.data.userId
    && request.resource.data.status == 'cancelled'; // Only allow cancel
}
```

**Giải thích:**

- ✅ Member chỉ tạo được reservation cho chính mình
- ✅ Member chỉ đọc được reservation của mình
- ✅ Member chỉ có thể update status → "cancelled"
- ❌ Librarian có full access (rule riêng)

---

## 📊 Database Schema

### Collection: `reservations`

```typescript
{
  id: string;              // Document ID
  userId: string;          // Reference to users collection
  bookId: string;          // Reference to books collection
  itemId: string | null;   // Reference to bookItems (null until notified)
  reservedAt: Timestamp;   // Thời điểm đặt giữ
  notifiedAt?: Timestamp;  // Thời điểm được thông báo (if status = notified)
  status: 'waiting' | 'notified' | 'fulfilled' | 'cancelled';
}
```

**Indexes cần tạo:**

```
1. (bookId, status, reservedAt) - Composite index
   → Tìm reservation tiếp theo khi sách available

2. (userId, status) - Composite index
   → Lấy tất cả reservations của user theo status

3. (userId, bookId, status) - Composite index
   → Check duplicate reservation
```

---

## 🚀 Tính năng nâng cao (Future)

### 1. Queue Position Display

Hiển thị vị trí trong hàng đợi:

```
"Bạn đang ở vị trí #3 trong hàng đợi"
```

### 2. Estimated Wait Time

Dự đoán thời gian chờ:

```
"Thời gian chờ dự kiến: 5-7 ngày"
```

### 3. Priority Reservations

Ưu tiên theo:

- VIP members
- Student/Teacher role
- Urgent need flag

### 4. Auto-borrow khi notified

Option tự động mượn khi được thông báo:

```
[✓] Tự động mượn khi sách có sẵn
```

### 5. Reservation Expiry Warning

Email/notification trước 1 ngày:

```
"Reservation của bạn sẽ hết hạn vào ngày mai!"
```

---

## ✅ Checklist hoàn thành

- [x] UI nút Reserve hiển thị khi availableCopies = 0
- [x] Dialog xác nhận với thông tin sách
- [x] Warning box về quy trình
- [x] Validation duplicate reservation
- [x] Error handling chi tiết
- [x] Success/error snackbar với icon
- [x] Auto-reload sau khi reserve
- [x] Tiếng Việt cho member
- [x] Loading state với disabled button
- [x] Integration với ReservationService
- [x] Firestore rules security
- [ ] Notification system (future)
- [ ] Queue position display (future)
- [ ] Auto-borrow option (future)

---

## 🎓 Tóm tắt cho Member

### Khi nào dùng Reserve?

**Sách muốn mượn đang hết** → Click "Reserve"

### Sau khi Reserve?

1. Vào hàng đợi
2. Đợi thông báo
3. Có 3 ngày để mượn khi được thông báo
4. Hoặc Cancel nếu không muốn nữa

### Xem Reservations ở đâu?

**Member Home → Tab "Reservations" (tab thứ 3)**

---

**Chúc bạn sử dụng thư viện thành công! 📚✨**
