# 📚 Hướng Dẫn Chức Năng Gia Hạn Sách (Renew Book)

## ✅ Chức Năng Đã Hoàn Thiện

### 🔄 Gia Hạn Sách (Renew Book)

Chức năng cho phép member gia hạn thời gian mượn sách thêm 15 ngày.

---

## 📋 Thông Tin Cơ Bản

### Quy định gia hạn:

- ✅ **Số lần gia hạn tối đa**: 2 lần
- ✅ **Thời gian mỗi lần gia hạn**: 15 ngày
- ✅ **Điều kiện**: Chỉ gia hạn được cho sách đang mượn (status = "borrowed")
- ✅ **Tổng thời gian tối đa**: 15 + 15 + 15 = 45 ngày

### Ai có thể gia hạn?

- ✅ Member đang mượn sách
- ✅ Sách chưa quá hạn (hoặc đang quá hạn nhưng vẫn gia hạn được)
- ✅ Còn lượt gia hạn (chưa đạt 2 lần)

---

## 🎯 Cách Sử Dụng

### Bước 1: Vào màn hình My Loans

1. Login với tài khoản Member
2. Click tab **"My Loans"** ở Bottom Navigation
3. Xem danh sách sách đang mượn

### Bước 2: Kiểm tra số lần gia hạn

Mỗi sách hiển thị:

```
📚 Tên sách
📅 Issue Date: [Ngày mượn]
📅 Due Date: [Hạn trả]
🔁 Số lần gia hạn: 0 / 2 (Còn 2)
```

### Bước 3: Click nút "Renew"

- Nút **"Renew"** (màu xanh) nằm bên cạnh nút "Return"
- Nếu đã gia hạn 2 lần → Nút bị ẩn
- Click để mở dialog xác nhận

### Bước 4: Xác nhận gia hạn

Dialog hiển thị:

```
🔄 Gia hạn sách

Bạn muốn gia hạn thêm 15 ngày?

📅 Thông tin gia hạn:
━━━━━━━━━━━━━━━━━━━━━
📆 Hạn trả hiện tại: 10 Th12 2025
✅ Hạn trả mới:     25 Th12 2025
🔁 Số lần gia hạn đã dùng: 0 / 2
ℹ️  Còn lại sau khi gia hạn: 1 lần

⚠️ Bạn còn 1 lần gia hạn sau này.

[Hủy]  [✓ Xác nhận gia hạn]
```

### Bước 5: Kết quả

- ✅ **Thành công**: "Gia hạn thành công! Hạn mới: 25 Th12 2025"
- ✅ Due date được cập nhật
- ✅ Renew count tăng lên (0 → 1)
- ✅ UI cập nhật ngay lập tức

---

## 🎨 Giao Diện

### Card sách trong My Loans:

```
┌────────────────────────────────────────┐
│ 📚 [Ảnh]  Tên sách                     │
│           Tác giả                       │
│                                         │
│ 📅 Issue Date: 01 Th12 2025            │
│ 📅 Due Date:   15 Th12 2025            │
│ ⏱️  14 days remaining                   │
│                                         │
│ 🔁 Số lần gia hạn: [0 / 2 (Còn 2)]    │ ← Badge màu xanh
│                                         │
│ [Return]  [Renew]                      │
└────────────────────────────────────────┘
```

### Badge số lần gia hạn:

- **0 / 2 (Còn 2)** → Badge màu xanh ✅
- **1 / 2 (Còn 1)** → Badge màu cam 🟧
- **2 / 2** → Badge màu đỏ ⛔ (nút Renew bị ẩn)

### Dialog xác nhận:

- 🔷 **Header**: Icon update + "Gia hạn sách"
- 📊 **Thông tin**: Box màu xanh nhạt với chi tiết
- ⚠️ **Warning**: Box màu vàng với lưu ý
- ✅ **Actions**: Nút Hủy + Xác nhận

---

## 🔧 Technical Details

### Files liên quan:

```
lib/
├── services/
│   └── loan_service.dart           # renewLoan() method
└── screens/
    └── member/
        └── my_loans.dart           # UI + _handleRenew()
```

### Key Method: renewLoan()

**Location**: `lib/services/loan_service.dart`

```dart
Future<void> renewLoan(String loanId, {int additionalDays = 15}) async {
  // 1. Validate loan exists
  // 2. Check status = "borrowed"
  // 3. Check renewCount < 2
  // 4. Calculate new due date (current + 15 days)
  // 5. Update loan document:
  //    - dueDate: newDueDate
  //    - renewCount: renewCount + 1
}
```

**Parameters**:

- `loanId`: ID của loan cần gia hạn
- `additionalDays`: Số ngày gia hạn (default = 15)

**Validation**:

- ❌ Loan không tồn tại → "Loan not found"
- ❌ Status != "borrowed" → "Only active loans can be renewed"
- ❌ renewCount >= 2 → "Maximum renewal limit (2) reached"
- ✅ Hợp lệ → Update dueDate + renewCount

### UI Flow:

```
Member clicks "Renew"
       ↓
_handleRenew(loan)
       ↓
Check renewCount < 2
       ↓
Show confirmation dialog
   ├─ Current due date
   ├─ New due date (+15 days)
   ├─ Used renewals: X / 2
   └─ Remaining renewals: Y
       ↓
User confirms
       ↓
loanService.renewLoan(loan.id)
       ↓
Update Firestore:
   - dueDate: +15 days
   - renewCount: +1
       ↓
Success message + Reload UI
```

---

## 📊 Scenarios

### Scenario 1: Gia hạn lần đầu (0/2)

```
Trạng thái ban đầu:
- Issue Date: 01/12/2025
- Due Date:   15/12/2025
- Renew Count: 0 / 2

Member clicks "Renew" → Confirms

Trạng thái sau gia hạn:
- Due Date:   30/12/2025  ← +15 days
- Renew Count: 1 / 2      ← +1
- Message: "Gia hạn thành công! Hạn mới: 30 Th12 2025"
```

### Scenario 2: Gia hạn lần 2 (1/2)

```
Trạng thái ban đầu:
- Due Date:   30/12/2025
- Renew Count: 1 / 2

Member clicks "Renew" → Confirms

Trạng thái sau gia hạn:
- Due Date:   14/01/2026  ← +15 days
- Renew Count: 2 / 2      ← +1
- Message: "Gia hạn thành công! Hạn mới: 14 Th1 2026"
- Warning: "Đây là lần gia hạn cuối cùng của bạn."
- Nút "Renew" bị ẩn
```

### Scenario 3: Đã hết lượt gia hạn (2/2)

```
Trạng thái:
- Renew Count: 2 / 2
- Nút "Renew" KHÔNG hiển thị

Member không thể gia hạn thêm
→ Phải trả sách và mượn lại (nếu cần)
```

### Scenario 4: Sách quá hạn nhưng vẫn gia hạn được

```
Trạng thái:
- Due Date: 01/12/2025 (quá hạn 5 ngày)
- Status: "overdue"
- Renew Count: 0 / 2

Member vẫn có thể gia hạn:
- Due Date mới: 16/12/2025 (từ ngày hiện tại +15)
- Renew Count: 1 / 2
```

---

## ⚠️ Lưu Ý Quan Trọng

### 1. Giới hạn gia hạn

- Mỗi loan chỉ được gia hạn **tối đa 2 lần**
- Mỗi lần gia hạn thêm **15 ngày**
- Không thể gia hạn sau khi đã trả sách

### 2. Tính toán due date

- Due date mới = Due date hiện tại + 15 ngày
- KHÔNG phải từ ngày hiện tại
- Ví dụ:
  - Current due: 15/12
  - Gia hạn ngày: 10/12
  - New due: 30/12 (15/12 + 15)

### 3. Sách quá hạn

- Vẫn có thể gia hạn nếu còn lượt
- Fine (nếu có) vẫn được tính
- Gia hạn không xóa fine đã có

### 4. Firestore Rules

Cần permission để update loan:

```javascript
allow update: if isSignedIn() &&
  (isOwner(resource.data.userId) || isLibrarian());
```

### 5. UI/UX

- Nút "Renew" chỉ hiện khi renewCount < 2
- Dialog hiển thị đầy đủ thông tin
- Success message bao gồm due date mới
- Badge hiển thị số lần còn lại

---

## 🧪 Testing Checklist

### Test Case 1: Gia hạn lần đầu

- [ ] Login as Member
- [ ] Có sách đang mượn (renewCount = 0)
- [ ] Click "Renew"
- [ ] Xem dialog với thông tin đầy đủ
- [ ] Confirm → Success
- [ ] Due date +15 days
- [ ] Renew count: 0 → 1
- [ ] Badge hiển thị "1 / 2 (Còn 1)"

### Test Case 2: Gia hạn lần 2

- [ ] Sách đã gia hạn 1 lần (renewCount = 1)
- [ ] Click "Renew"
- [ ] Dialog warning: "Đây là lần gia hạn cuối cùng"
- [ ] Confirm → Success
- [ ] Renew count: 1 → 2
- [ ] Nút "Renew" biến mất
- [ ] Badge hiển thị "2 / 2" (màu đỏ)

### Test Case 3: Không thể gia hạn (đã hết lượt)

- [ ] Sách đã gia hạn 2 lần (renewCount = 2)
- [ ] Nút "Renew" KHÔNG hiển thị
- [ ] Không có cách nào gia hạn thêm

### Test Case 4: Gia hạn sách quá hạn

- [ ] Sách quá hạn (overdue)
- [ ] Vẫn còn lượt gia hạn
- [ ] Click "Renew" → Thành công
- [ ] Due date được cập nhật
- [ ] Status vẫn là "overdue" (nếu vẫn quá hạn)

### Test Case 5: Error handling

- [ ] Network error → Show error message
- [ ] Permission denied → "Vui lòng kiểm tra Firestore rules"
- [ ] Max limit → "Đã đạt giới hạn gia hạn tối đa"

---

## 🎯 Kết Luận

### ✅ Hoàn thiện:

1. ✅ Backend: `renewLoan()` method in LoanService
2. ✅ UI: Nút "Renew" trong My Loans
3. ✅ Dialog: Xác nhận với thông tin đầy đủ
4. ✅ Validation: Check renewCount, status
5. ✅ Display: Badge hiển thị số lần gia hạn
6. ✅ Messages: Success/error messages
7. ✅ Real-time: UI cập nhật ngay sau gia hạn

### 📊 Thống kê:

- **Số lần gia hạn tối đa**: 2 lần
- **Thời gian mỗi lần**: 15 ngày
- **Tổng thời gian tối đa**: 45 ngày (15 + 15 + 15)
- **UI elements**: 3 badges (green/orange/red)
- **Error cases**: 3 types handled

### 🚀 Sẵn sàng sử dụng!

Chức năng gia hạn sách đã hoàn thiện 100% và sẵn sàng để test! 🎉
