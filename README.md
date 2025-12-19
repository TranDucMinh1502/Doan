# Library Management System - Flutter + Firebase

## 📚 Features

- Browse books catalog (real-time from Firestore)
- Book checkout with transaction-safe Firestore operations
- Reserve books when unavailable
- Return books with automatic fine calculation
- User authentication (Firebase Auth)
- Real-time updates via Firestore streams

## 🚀 Setup Instructions

### 1. Firebase Configuration

#### For Android:

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project → Project Settings → Download `google-services.json`
3. Place it in: `android/app/google-services.json`

#### For iOS:

1. Download `GoogleService-Info.plist` from Firebase Console
2. Place it in: `ios/Runner/GoogleService-Info.plist`

#### For Web:

Add to `web/index.html` before `</body>`:

```html
<script src="https://www.gstatic.com/firebasejs/10.7.0/firebase-app.js"></script>
<script src="https://www.gstatic.com/firebasejs/10.7.0/firebase-firestore.js"></script>
<script>
  const firebaseConfig = {
    apiKey: "YOUR_API_KEY",
    authDomain: "YOUR_PROJECT.firebaseapp.com",
    projectId: "YOUR_PROJECT_ID",
    storageBucket: "YOUR_PROJECT.appspot.com",
    messagingSenderId: "YOUR_SENDER_ID",
    appId: "YOUR_APP_ID",
  };
  firebase.initializeApp(firebaseConfig);
</script>
```

### 2. Firestore Security Rules (Example)

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /books/{bookId} {
      allow read: if true;
      allow write: if request.auth != null && get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'librarian';
    }

    match /bookItems/{itemId} {
      allow read: if true;
      allow write: if request.auth != null;
    }

    match /loans/{loanId} {
      allow read: if request.auth.uid == resource.data.userId || get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'librarian';
      allow write: if request.auth != null;
    }

    match /reservations/{resId} {
      allow read: if request.auth.uid == resource.data.userId || get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'librarian';
      allow create: if request.auth != null;
      allow update, delete: if request.auth != null;
    }

    match /users/{userId} {
      allow read: if request.auth.uid == userId || get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'librarian';
      allow write: if request.auth != null;
    }
  }
}
```

### 3. Firestore Indexes (Add in Firebase Console)

- **bookItems**: `bookId` (ASC) + `status` (ASC)
- **reservations**: `bookId` (ASC) + `status` (ASC) + `reservedAt` (ASC)
- **loans**: `userId` (ASC) + `status` (ASC) + `dueDate` (ASC)

### 4. Run the app

```bash
flutter run
```

## 📁 Project Structure

```
lib/
├── models/
│   ├── book.dart              # Book model
│   ├── book_item.dart         # BookItem (physical copy)
│   ├── loan.dart              # Loan transaction
│   ├── reservation.dart       # Book reservation
│   └── user_model.dart        # User/Member model
├── services/
│   └── firestore_service.dart # Firestore operations (checkout, return, reserve)
├── screens/
│   ├── home_screen.dart       # Home/landing
│   ├── book_list_screen.dart  # Books catalog
│   ├── book_detail_screen.dart# Book details + actions
│   └── login_screen.dart      # Login with Firebase Auth
└── main.dart                  # App entry point
```

## 🔧 Key Firestore Collections

### `books`

```json
{
  "title": "Đắc Nhân Tâm",
  "authors": ["Nhật Ánh"],
  "isbn": "12",
  "totalCopies": 15,
  "availableCopies": 10,
  "description": "..."
}
```

### `bookItems`

```json
{
  "bookId": "4jf5yK4VcXjawrFfyPa5",
  "barcode": "BOOK-4JF5YK4V-007",
  "status": "available",
  "location": "General Section"
}
```

### `loans`

```json
{
  "userId": "Gm1UX62RhKRktCJSJLmmBaWaWbx1",
  "bookId": "4jf5yK4VcXjawrFfyPa5",
  "itemId": "puHW4UTMIf3dWEIWnqsp",
  "issueDate": "2025-12-17T...",
  "dueDate": "2026-01-01T...",
  "returnDate": null,
  "status": "issued",
  "fine": 0
}
```

### `reservations`

```json
{
  "userId": "eGAXMyUOkQe1IYkAaN1EcZZmJly2",
  "bookId": "aJtqygxJPiCbwzo988Aq",
  "itemId": null,
  "reservedAt": "2025-12-07T...",
  "status": "waiting"
}
```

### `users`

```json
{
  "fullName": "Pro",
  "email": "s2@gmail.com",
  "role": "member",
  "borrowedCount": 0,
  "maxBorrow": 3,
  "fcmTokens": ["..."],
  "cardNumber": "LIB-EGAXMYUO"
}
```

## � Push Notifications Setup

### 1. Enable Firebase Cloud Messaging

In Firebase Console:

1. Go to Project Settings → Cloud Messaging
2. Enable Cloud Messaging API (V1)
3. Download service account key for server

### 2. Deploy Cloud Functions

```bash
cd functions
npm install
firebase deploy --only functions
```

### 3. Notification Types

- **Reservation Ready**: When a reserved book becomes available
- **Due Reminder**: 2 days before book is due
- **Overdue Alert**: Daily check for overdue books

### 4. Test Notifications

Send test from Firebase Console → Cloud Messaging → Send test message

## 🛠️ Cloud Functions

Located in `functions/index.js`:

- `onBookItemAvailable` - Triggers when book becomes available
- `checkOverdueLoans` - Runs daily at 9 AM (Asia/Ho_Chi_Minh timezone)
- `sendDueReminders` - Sends reminders 2 days before due date

## 🎯 Next Steps (TODO)

- [x] User authentication with profile creation
- [x] Search functionality
- [x] My Loans screen
- [x] My Reservations screen
- [x] FCM notifications setup
- [ ] Add librarian admin panel (add/edit books)
- [ ] Add QR/Barcode scanner for checkout
- [ ] Implement renew functionality
- [ ] Add fine payment integration
- [ ] Analytics dashboard

## 📝 Notes

- All checkout/return operations use Firestore transactions for data consistency
- Fine calculation: 1 unit per day overdue (configurable)
- Max borrow limit: 3 books per user (configurable in user document)
- Loan duration: 15 days (configurable in checkout call)

---

Built with Flutter 💙 + Firebase 🔥
