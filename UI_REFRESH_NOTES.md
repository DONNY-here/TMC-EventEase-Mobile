# EventEase UI refresh — student dashboard

## Changed
- `lib/dashboard_page.dart`: redesigned greeting hero, accessible navigation buttons, quick actions and section labels.
- `lib/main_page.dart`: revised student navigation wording and spacing.
- `lib/config_and_data.dart`: refined light background and border colors.

## Preserved
- Existing role routing, event/detail views, registration collections, QR behavior, backend setup and authentication logic.
- Existing scanner/admin navigation.

## Test locally
1. `flutter pub get`
2. `flutter analyze`
3. `flutter run -d <your-device-id>`
4. Verify student dashboard, Find Events, My Passes, Campus Updates and scanner login.

This is a first-pass UI redesign, not a completed backend integration or a verified production build. Flutter SDK was not available in the editing environment, so compile and device testing remain necessary.
