import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dz6g_app/main.dart';

void main() {
  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const Dz6gApp());
    expect(find.text('校园墙'), findsOneWidget);
  });
}
