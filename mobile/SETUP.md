# Flutter launch checklist

1. Install Flutter stable and Android Studio.
2. Run `flutter doctor`.
3. From `mobile/`, run `flutter pub get`.
4. Put your Supabase URL and anon key in `lib/config.dart`.
5. Start an emulator or connect an Android phone with USB debugging.
6. Run `flutter run`.
7. Build with `flutter build apk --release`.

The assignment asks for Flutter Android/iOS. This source is shared across Android and iOS; the generated platform folders are intentionally omitted from this source package so Flutter can generate them with:

`flutter create .`

Run that command from the `mobile/` folder if your environment does not already contain the Android/iOS platform folders.
