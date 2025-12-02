# Push Notifications Setup Guide

## Overview
This guide will help you set up push notifications for the ERP app so students receive notifications when:
- New assignments are uploaded
- New study materials are uploaded
- Announcements are made

Notifications will work even when the app is closed or cleared from recent apps.

## Prerequisites
1. Firebase account
2. Firebase project created
3. Flutter app registered with Firebase

## Step 1: Add Firebase to Your Project

### 1.1 Install Firebase CLI
```bash
npm install -g firebase-tools
firebase login
```

### 1.2 Install FlutterFire CLI
```bash
dart pub global activate flutterfire_cli
```

### 1.3 Configure Firebase for Flutter
```bash
cd /path/to/erp
flutterfire configure
```

Select your Firebase project and platforms (iOS, Android).

## Step 2: Add Dependencies

Add these to `pubspec.yaml`:

```yaml
dependencies:
  firebase_core: ^2.24.2
  firebase_messaging: ^14.7.9
  flutter_local_notifications: ^16.3.0
```

Then run:
```bash
flutter pub get
```

## Step 3: Android Configuration

### 3.1 Update `android/app/build.gradle`
```gradle
android {
    defaultConfig {
        minSdkVersion 21  // Change from 19 to 21
    }
}
```

### 3.2 Add to `android/app/src/main/AndroidManifest.xml`
```xml
<manifest>
    <application>
        <!-- Add this inside <application> tag -->
        <meta-data
            android:name="com.google.firebase.messaging.default_notification_channel_id"
            android:value="high_importance_channel" />
            
        <meta-data
            android:name="com.google.firebase.messaging.default_notification_icon"
            android:resource="@drawable/ic_notification" />
    </application>
    
    <!-- Add these permissions before <application> tag -->
    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
    <uses-permission android:name="android.permission.VIBRATE" />
</manifest>
```

## Step 4: iOS Configuration

### 4.1 Update `ios/Runner/Info.plist`
```xml
<key>UIBackgroundModes</key>
<array>
    <string>fetch</string>
    <string>remote-notification</string>
</array>
```

### 4.2 Enable Push Notifications in Xcode
1. Open `ios/Runner.xcworkspace` in Xcode
2. Select Runner target
3. Go to "Signing & Capabilities"
4. Click "+ Capability"
5. Add "Push Notifications"
6. Add "Background Modes" and check "Remote notifications"

## Step 5: Create Notification Service

Create `lib/services/notification_service.dart`:

```dart
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('Background message: ${message.messageId}');
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    // Request permission
    await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Initialize local notifications
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(settings);

    // Create notification channel for Android
    const channel = AndroidNotificationChannel(
      'high_importance_channel',
      'High Importance Notifications',
      description: 'This channel is used for important notifications.',
      importance: Importance.high,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // Set background message handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _showLocalNotification(message);
    });

    // Get FCM token and save to Supabase
    final token = await _fcm.getToken();
    if (token != null) {
      await _saveFCMToken(token);
    }

    // Listen for token refresh
    _fcm.onTokenRefresh.listen(_saveFCMToken);
  }

  Future<void> _saveFCMToken(String token) async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId != null) {
        await Supabase.instance.client.from('user_fcm_tokens').upsert({
          'user_id': userId,
          'fcm_token': token,
          'updated_at': DateTime.now().toIso8601String(),
        });
        print('✅ FCM token saved: $token');
      }
    } catch (e) {
      print('❌ Error saving FCM token: $e');
    }
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    const androidDetails = AndroidNotificationDetails(
      'high_importance_channel',
      'High Importance Notifications',
      channelDescription: 'This channel is used for important notifications.',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails();

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      message.hashCode,
      message.notification?.title ?? 'New Notification',
      message.notification?.body ?? '',
      details,
    );
  }
}
```

## Step 6: Create Database Table for FCM Tokens

Run this SQL in Supabase:

```sql
CREATE TABLE IF NOT EXISTS user_fcm_tokens (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    fcm_token TEXT NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id)
);

CREATE INDEX idx_fcm_tokens_user ON user_fcm_tokens(user_id);

ALTER TABLE user_fcm_tokens ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage their own tokens"
ON user_fcm_tokens FOR ALL
USING (auth.uid() = user_id);
```

## Step 7: Initialize in main.dart

Update your `main.dart`:

```dart
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Initialize Supabase
  await SupabaseService.initialize();
  
  // Initialize Notifications
  await NotificationService().initialize();
  
  runApp(const MyApp());
}
```

## Step 8: Create Cloud Functions to Send Notifications

You'll need to create Firebase Cloud Functions or Supabase Edge Functions to send notifications when:
- Teacher uploads assignment
- Teacher uploads study material
- Teacher makes announcement

### Example Supabase Edge Function:

Create `supabase/functions/send-notification/index.ts`:

```typescript
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

serve(async (req) => {
  try {
    const { title, body, studentIds } = await req.json()
    
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // Get FCM tokens for students
    const { data: tokens } = await supabase
      .from('user_fcm_tokens')
      .select('fcm_token')
      .in('user_id', studentIds)

    if (!tokens || tokens.length === 0) {
      return new Response(JSON.stringify({ message: 'No tokens found' }), {
        headers: { 'Content-Type': 'application/json' },
      })
    }

    // Send notifications using FCM
    const fcmTokens = tokens.map(t => t.fcm_token)
    
    // Call FCM API here
    // (You'll need to implement FCM HTTP v1 API call)

    return new Response(
      JSON.stringify({ message: 'Notifications sent', count: fcmTokens.length }),
      { headers: { 'Content-Type': 'application/json' } }
    )
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 400,
      headers: { 'Content-Type': 'application/json' },
    })
  }
})
```

## Step 9: Trigger Notifications

Update teacher service methods to trigger notifications:

```dart
// After uploading assignment
await _supabase.functions.invoke('send-notification', body: {
  'title': 'New Assignment',
  'body': 'New assignment uploaded for $subjectName',
  'studentIds': studentIds, // Get from class
});
```

## Testing

1. **Foreground**: Open app, upload assignment from teacher side, check if notification appears
2. **Background**: Minimize app, upload assignment, check notification
3. **Terminated**: Close app completely, upload assignment, check notification

## Troubleshooting

### Android
- Check `google-services.json` is in `android/app/`
- Verify minSdkVersion is 21+
- Check Firebase Console for errors

### iOS
- Check `GoogleService-Info.plist` is in `ios/Runner/`
- Verify APNs certificates are configured in Firebase
- Test on real device (not simulator)

### General
- Check Firebase Console → Cloud Messaging
- Verify FCM tokens are being saved in database
- Check app logs for errors

## Summary

After setup:
- ✅ Students get notifications for new assignments
- ✅ Students get notifications for new study materials
- ✅ Notifications work even when app is closed
- ✅ Notifications work in background
- ✅ FCM tokens stored in database

This is a comprehensive setup that requires Firebase configuration. The actual implementation depends on your Firebase project setup.
