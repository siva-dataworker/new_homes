// Smoke test — verifies the app boots without throwing and shows its
// initial loading state. The previous version of this file was the
// unmodified `flutter create` template test (asserting a counter button
// that has never existed in this app), so `flutter test` had never
// actually verified anything about this codebase.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:otp_phone_auth/main.dart';

void main() {
  testWidgets('App boots and shows the initial loading state', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());

    // AuthChecker's build() renders immediately (before its async
    // _checkAuth() resolves); pump once rather than pumpAndSettle so the
    // test doesn't hang on the CircularProgressIndicator's animation.
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
