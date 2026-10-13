# Bill Reminder & Payment App (Flutter + Dart)

## Run
1. Install Flutter: https://docs.flutter.dev/get-started/install
2. In this folder run:
   flutter create .          # adds android/ios/web folders (keeps lib/ and pubspec.yaml)
   flutter pub get
   flutter run               # pick a phone, emulator or Chrome

## Build a web version (to host as a link)
   flutter build web --release
   Upload build/web to GitHub Pages or Firebase Hosting.

## Features
- Add bills (name, amount, due date, category, reminder days)
- In-app reminder banners for bills inside their reminder window
- Pay with UPI / Card / Net Banking (demo, no real money)
- Paid history, delete by long-press, data saved with shared_preferences
