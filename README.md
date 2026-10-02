# WorkNear — Flutter (Android)

Built against the real endpoints in github.com/CODEWITH-JAIVY/WorkNear (read from the controllers).

## Setup
```
flutter create --org com.worknear --platforms android worknear_app
cd worknear_app
# copy lib/ and pubspec.yaml from this folder over the generated ones
flutter pub get
```

### android/app/src/main/AndroidManifest.xml
Inside `<manifest>`:
```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
<uses-permission android:name="android.permission.CAMERA"/>
```
On `<application>` (DEV ONLY - remove for prod, use HTTPS/WSS): `android:usesCleartextTraffic="true"`

Inside `<application>` (Google login deep link):
```xml
<activity android:name="com.linusu.flutter_web_auth_2.CallbackActivity" android:exported="true">
  <intent-filter android:label="flutter_web_auth_2">
    <action android:name="android.intent.action.VIEW"/>
    <category android:name="android.intent.category.DEFAULT"/>
    <category android:name="android.intent.category.BROWSABLE"/>
    <data android:scheme="worknear"/>
  </intent-filter>
</activity>
```
android/app/build.gradle: `minSdkVersion 23`.

## Run
```
docker compose up --build                                   # backend
flutter run --dart-define=RAZORPAY_KEY=rzp_test_xxxxx       # emulator -> 10.0.2.2:8080
flutter run --dart-define=API_BASE=http://192.168.x.x:8080 --dart-define=RAZORPAY_KEY=...   # real phone
```
Google login needs a redirect URI Google accepts. Easiest in dev: `adb reverse tcp:8080 tcp:8080`
and run with `--dart-define=API_BASE=http://localhost:8080` (Google allows localhost).

## Firebase (push) - optional, app runs without it
1. Firebase console -> add Android app (package com.worknear.worknear_app) -> download google-services.json -> android/app/
2. android/build.gradle: `classpath 'com.google.gms:google-services:4.4.2'`; android/app/build.gradle: `apply plugin: 'com.google.gms.google-services'`
3. Apply BACKEND_PATCHES.md section 3.

## Screens
| Role | Screen | Endpoints |
|---|---|---|
| all | Login / Signup / Google / Select role | /api/auth/* |
| customer | My jobs, Post job, Job detail | /api/jobs, /api/jobs/mine, /api/jobs/{id} |
| customer | Pay | /api/payments/orders (+ Razorpay checkout) |
| both | Chat | /api/chat/jobs/{id}/messages, WS /ws/chat |
| both | Rate | /api/reviews |
| labour | Job feed + availability + location | WS /ws/notifications, /api/labour/me/* , /api/jobs/{id}/accept |
| labour | Wallet | /api/payments/wallet/{id} |
| labour | KYC | /api/media/upload, /api/kyc/documents |
| both | Profile | /api/customers/me, /api/labour/me |
