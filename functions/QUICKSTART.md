# Quick Start - Deploy Firebase Cloud Functions

## Step 1: Install Dependencies

```bash
cd functions
npm install
```

## Step 2: Configure Firebase Project

Make sure your Firebase project is configured:

```bash
firebase use --add
# Select your Firebase project from the list
```

## Step 3: Deploy Functions

```bash
firebase deploy --only functions
```

This will deploy three functions:

- ✅ `overdueChecker` - Scheduled to run daily at midnight UTC
- ✅ `manualOverdueCheck` - Callable function for librarians
- ✅ `sendNotification` - Callable function for sending custom notifications

## Step 4: Verify Deployment

Check the Firebase Console:

1. Go to https://console.firebase.google.com
2. Select your project
3. Navigate to **Functions** section
4. You should see all three functions listed

## Step 5: Test the Functions

### Test Manual Overdue Check (from Flutter app)

```dart
import 'package:cloud_functions/cloud_functions.dart';

final functions = FirebaseFunctions.instance;

try {
  final result = await functions
      .httpsCallable('manualOverdueCheck')
      .call();

  print('Success: ${result.data['message']}');
  print('Processed: ${result.data['processedCount']} loans');
} catch (e) {
  print('Error: $e');
}
```

### Test Send Notification (from Flutter app)

```dart
try {
  final result = await functions
      .httpsCallable('sendNotification')
      .call({
    'userId': 'user123',
    'title': 'Test Notification',
    'body': 'This is a test message',
    'data': {'type': 'test'}
  });

  print('Sent: ${result.data['successCount']} notifications');
} catch (e) {
  print('Error: $e');
}
```

## Step 6: Monitor Function Execution

### View Logs in Terminal

```bash
firebase functions:log --only overdueChecker
```

### View Logs in Firebase Console

1. Go to Firebase Console → Functions
2. Click on function name
3. Click "Logs" tab

## Common Issues

### Issue: "Firebase project not found"

**Solution**: Run `firebase use --add` and select your project

### Issue: "Permission denied"

**Solution**: Make sure you're logged in with `firebase login`

### Issue: "Function timeout"

**Solution**: Increase timeout in index.js:

```javascript
setGlobalOptions({
  timeoutSeconds: 540, // Increase this value
});
```

### Issue: "No overdue loans found"

**Solution**: This is normal if there are no overdue loans. The function is working correctly.

## Production Checklist

- ✅ Firebase CLI installed and logged in
- ✅ Firebase project selected
- ✅ Functions deployed successfully
- ✅ Firestore indexes created (check Firebase Console)
- ✅ FCM tokens registered in user documents
- ✅ Scheduled function appears in Cloud Scheduler
- ✅ Test manual function call works
- ✅ Logs show no errors

## Next Steps

1. Wait for the scheduled function to run (midnight UTC) or trigger manually
2. Check Firestore `notifications` collection for new documents
3. Verify users receive push notifications on their devices
4. Monitor function execution logs for any issues

## Support

If you encounter issues:

1. Check the logs: `firebase functions:log`
2. Verify Firestore data structure matches expected format
3. Ensure FCM tokens are registered in user documents
4. Check Firebase Console for any error messages
