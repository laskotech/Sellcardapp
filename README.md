
# Sell Card — REAL Source

This zip contains the actual app code (Dart + pubspec + icon).

## Apply to a Flutter project
1) `flutter create sellcard && cd sellcard`
2) Overwrite `lib/main.dart` and `pubspec.yaml` with the ones from this zip.
3) Copy `assets/` into the project root.
4) Put your `google-services.json` at `android/app/google-services.json`.
5) Ensure Google services plugin is configured in Android gradle (see previous messages).
6) `flutter pub get && flutter build apk --release`
