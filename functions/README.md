# Firebase Cloud Functions - Library Management System

This directory contains Firebase Cloud Functions for automating library operations and sending notifications.

## Functions

### 1. `overdueChecker` (Scheduled)

**Schedule**: Runs daily at midnight UTC (`0 0 * * *`)

**Purpose**: Automatically checks for overdue loans and processes them.

**Process**:

1. Queries all loans with `status == "borrowed"` and `dueDate < now`
2. Calculates fine: `daysOverdue × $1.00 per day`
3. Updates loan status to "overdue" and sets fine amount
4. Creates notification documents in Firestore
5. Sends FCM push notifications to users with overdue books

**Configuration**:

- `FINE_PER_DAY`: $1.00 (configurable in code)
- `BATCH_SIZE`: 100 loans per batch
- Timeout: 540 seconds
- Memory: 256MB
- Max Instances: 10

**Error Handling**:

- Retries up to 3 times with exponential backoff
- Processes loans in batches to prevent timeouts
- Continues processing even if individual loans fail
- Logs all errors for debugging

---

### 2. `manualOverdueCheck` (Callable)

**Purpose**: Allows librarians to manually trigger the overdue checker without waiting for the scheduled time.

**Authentication**: Required (Librarian role only)

**Usage**:

```javascript
const functions = firebase.functions();
const manualCheck = functions.httpsCallable("manualOverdueCheck");

try {
  const result = await manualCheck();
  console.log(result.data.message);
  // Output: "Processed 5 overdue loans"
} catch (error) {
  console.error(error.message);
}
```

**Returns**:

```json
{
  "success": true,
  "message": "Processed X overdue loans",
  "processedCount": 5,
  "errorCount": 0,
  "totalLoans": 5
}
```

---

### 3. `sendNotification` (Callable)

**Purpose**: Sends custom push notifications to specific users.

**Authentication**: Not required (can be added based on needs)

**Parameters**:

- `userId` (string, required): Target user ID
- `title` (string, required): Notification title
- `body` (string, required): Notification message
- `data` (object, optional): Custom data payload

**Usage**:

```javascript
const functions = firebase.functions();
const sendNotif = functions.httpsCallable("sendNotification");

await sendNotif({
  userId: "user123",
  title: "New Book Available",
  body: "The book you reserved is now available for pickup",
  data: {
    type: "reservation_ready",
    bookId: "book456",
  },
});
```

**Returns**:

```json
{
  "success": true,
  "successCount": 2,
  "failureCount": 0
}
```

---

## Deployment

### Prerequisites

1. Firebase CLI installed: `npm install -g firebase-tools`
2. Logged in to Firebase: `firebase login`
3. Firebase project initialized: `firebase init functions`

### Deploy All Functions

```bash
cd functions
npm install
firebase deploy --only functions
```

### Deploy Specific Function

```bash
firebase deploy --only functions:overdueChecker
firebase deploy --only functions:manualOverdueCheck
firebase deploy --only functions:sendNotification
```

### View Logs

```bash
firebase functions:log
```

### Test Locally

```bash
npm run serve
```

---

## Firestore Data Structure

### Loans Collection

```javascript
{
  "userId": "user123",
  "bookId": "book456",
  "itemId": "item789",
  "status": "borrowed" | "overdue" | "returned",
  "dueDate": Timestamp,
  "borrowedAt": Timestamp,
  "returnDate": Timestamp | null,
  "fine": 0.0,
  "daysOverdue": 0,
  "lastChecked": Timestamp,
  "overdueNotifiedAt": Timestamp
}
```

### Notifications Collection

```javascript
{
  "userId": "user123",
  "type": "overdue" | "reminder" | "general",
  "title": "Book Overdue",
  "message": "Your book is 3 days overdue...",
  "data": {
    "loanId": "loan123",
    "bookId": "book456",
    "daysOverdue": 3,
    "fine": 3.0
  },
  "read": false,
  "createdAt": Timestamp
}
```

### Users Collection (FCM Tokens)

```javascript
{
  "uid": "user123",
  "email": "user@example.com",
  "fcmTokens": [
    "fcm_token_1",
    "fcm_token_2"
  ],
  "lastTokenUpdate": Timestamp
}
```

---

## FCM Push Notification Format

**Overdue Notification**:

```javascript
{
  "notification": {
    "title": "Book Overdue!",
    "body": "The Great Gatsby is 3 days overdue. Fine: $3.00"
  },
  "data": {
    "type": "overdue",
    "loanId": "loan123",
    "bookId": "book456",
    "daysOverdue": "3",
    "fine": "3.0"
  }
}
```

---

## Monitoring

### Check Function Status

```bash
firebase functions:list
```

### View Recent Logs

```bash
firebase functions:log --only overdueChecker
firebase functions:log --only manualOverdueCheck
```

### View Logs in Firebase Console

1. Go to Firebase Console → Functions
2. Click on function name
3. View "Logs" tab for execution history

---

## Cost Considerations

### Scheduled Function (overdueChecker)

- Runs once per day (30 times per month)
- Estimated cost: ~$0.01 - $0.10/month (depending on loan volume)

### Callable Functions

- Charged per invocation
- Free tier: 2M invocations/month

### Best Practices

- Batch processing prevents timeout issues
- `maxInstances: 10` prevents cost spikes
- Invalid FCM tokens automatically removed
- Detailed logging for troubleshooting

---

## Troubleshooting

### Function Timeout

- **Cause**: Too many loans to process
- **Solution**: Increase `BATCH_SIZE` or `timeoutSeconds`

### FCM Delivery Failures

- **Cause**: Invalid or expired tokens
- **Solution**: Function automatically removes invalid tokens

### Missing Notifications

- **Cause**: User has no FCM tokens registered
- **Solution**: Ensure `NotificationService.initialize()` is called on app login

### Permission Errors

- **Cause**: Firebase Admin SDK not properly initialized
- **Solution**: Verify service account has Firestore and FCM permissions

---

## Development

### Local Testing

```bash
cd functions
npm run serve
```

### Run Lint

```bash
npm run lint
```

### Fix Lint Issues

```bash
npm run lint -- --fix
```

### Update Dependencies

```bash
npm update
```

---

## Security Rules

Ensure Firestore security rules allow the Cloud Functions to read/write:

```javascript
// Firestore Rules
service cloud.firestore {
  match /databases/{database}/documents {
    // Allow Cloud Functions to access all documents
    match /{document=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```

---

## Support

For issues or questions:

1. Check Firebase Console logs
2. Review function execution history
3. Verify Firestore indexes are created
4. Check FCM token registration in user documents
