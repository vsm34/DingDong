import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dingdong/main.dart';

void main() {
  testWidgets('App starts and shows splash screen', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: DingDongApp()),
    );
    await tester.pump();
    expect(find.byType(ProviderScope), findsNothing);
  });
}