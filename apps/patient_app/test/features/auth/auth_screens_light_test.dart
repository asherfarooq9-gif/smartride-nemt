import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patient_app/features/auth/login_screen.dart';
import 'package:patient_app/features/auth/signup_screen.dart';
import 'package:smartride_core/smartride_core.dart';

Future<void> _show(WidgetTester tester, Widget screen) async {
  FlutterSecureStorage.setMockInitialValues({});
  tester.view.physicalSize = const Size(412, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(child: MaterialApp(home: screen)),
  );
  await tester.pump();
}

Color? _background(WidgetTester tester) =>
    tester.widget<Scaffold>(find.byType(Scaffold).first).backgroundColor;

void main() {
  testWidgets('sign up has a light background and readable title', (t) async {
    await _show(t, const SignupScreen());

    expect(_background(t), kAuthLightBg);
    // The same words are also on the submit button; the title comes first.
    final title = t.widget<Text>(find.text('Create Account').first);
    expect(title.style?.color, kAuthText);
  });

  testWidgets('login has a light background and readable title', (t) async {
    await _show(t, const LoginScreen());

    expect(_background(t), kAuthLightBg);
    final title = t.widget<Text>(find.text('Welcome back'));
    expect(title.style?.color, kAuthText);
  });

  testWidgets('form fields are white boxes with dark text', (t) async {
    await _show(t, const SignupScreen());

    final field = t.widget<TextField>(find.byType(TextField).first);
    expect(field.decoration?.fillColor, kAuthFieldBg);
    expect(field.style?.color, kAuthText);
  });
}
