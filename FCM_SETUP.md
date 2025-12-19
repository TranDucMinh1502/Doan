# FCM Setup Instructions

## Prerequisites

- Firebase project with Cloud Messaging enabled
- Flutter app with firebase_messaging package

## Step-by-Step Setup

### 1. Android Configuration

#### Enable Cloud Messaging API

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Select your project
3. Enable "Firebase Cloud Messaging API"

#### Add google-services.json

- Already done in `android/app/google-services.json`

#### Permissions

- Already added in `android/app/src/main/AndroidManifest.xml`

### 2. iOS Configuration

#### Add GoogleService-Info.plist

1. Download from Firebase Console
2. Add to `ios/Runner/GoogleService-Info.plist`

#### Enable Push Notifications

1. Open `ios/Runner.xcworkspace` in Xcode
2. Select Runner target → Signing & Capabilities
3. Click "+ Capability" → Push Notifications
4. Click "+ Capability" → Background Modes
5. Check "Remote notifications"

#### Upload APNs Certificate

1. Go to Firebase Console → Project Settings → Cloud Messaging
2. Upload your APNs authentication key or certificate

### 3. Test Notifications

#### From Firebase Console:

1. Go to Cloud Messaging → Send test message
2. Enter FCM token (check console logs when app starts)
3. Send notification

#### From Cloud Functions:

```bash
cd functions
npm install
firebase deploy --only functions
```

### 4. Notification Handling

The app handles 3 states:

1. **Foreground** - App is open

   - Handled in `notification_service.dart`
   - Shows in-app notification

2. **Background** - App is minimized

   - System shows notification
   - Handled by `_firebaseMessagingBackgroundHandler`

3. **Terminated** - App is closed
   - System shows notification
   - Opens app when tapped

### 5. Get FCM Token

Check console logs after app starts:

```
flutter run
```

Look for: "FCM Token: ..."

### 6. Cloud Functions Triggers

Automatic notifications are sent by:

1. **onBookItemAvailable**

   - Triggers when bookItem status changes to 'available'
   - Notifies users with waiting reservations

2. **checkOverdueLoans** (Scheduled)

   - Runs daily at 9 AM
   - Finds overdue loans
   - Sends overdue alerts

3. **sendDueReminders** (Scheduled)
   - Runs daily at 9 AM
   - Finds loans due in 2 days
   - Sends reminder notifications

### 7. Debugging

#### Check FCM token is saved:

1. Open Firestore
2. Go to `users/{userId}`
3. Check `fcmTokens` array

#### Check Cloud Functions logs:

```bash
firebase functions:log
```

#### Test in emulator:

```bash
cd functions
npm run serve
```

## Troubleshooting

### No notifications received

1. Check notification permissions granted
2. Verify FCM token is saved in Firestore
3. Check Cloud Functions logs for errors
4. Ensure Cloud Messaging API is enabled

### iOS not working

1. Verify APNs certificate is uploaded
2. Check Bundle ID matches Firebase config
3. Ensure capabilities are added in Xcode
4. Test on physical device (not simulator)

### Android not working

1. Verify google-services.json is correct
2. Check package name matches
3. Rebuild app after config changes

## Production Checklist

- [ ] Upload APNs certificate (iOS)
- [ ] Enable Cloud Messaging API
- [ ] Deploy Cloud Functions
- [ ] Test all notification types
- [ ] Set up monitoring/logging
- [ ] Configure notification channels (Android)
- [ ] Add notification icons
- [ ] Handle notification tap actions
