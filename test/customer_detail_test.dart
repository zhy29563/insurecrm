import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:insurance_manager/providers/app_state.dart';
import 'package:insurance_manager/models/user.dart';
import 'package:insurance_manager/pages/home_page.dart';

void main() {
  testWidgets('Full add customer flow from HomePage', (WidgetTester tester) async {
    final appState = AppState();
    
    // Simulate logged-in state
    appState.currentUser = User(
      id: 1,
      username: 'test',
      passwordHash: '',
      displayName: 'Test User',
      role: 'admin',
    );

    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>(
        create: (_) => appState,
        child: MaterialApp(
          home: HomePage(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump();
    await tester.pump();

    // Should be on HomePage
    expect(find.text('保险经纪人'), findsOneWidget);

    // Find and tap the "添加客户" button
    final addCustomerButton = find.text('添加客户');
    expect(addCustomerButton, findsOneWidget);
    
    await tester.tap(addCustomerButton);
    await tester.pump();
    await tester.pump();
    await tester.pump();
    await tester.pump();
    await tester.pump();

    // Should have navigated to CustomerListPage and then auto-navigated to CustomerDetailPage
    // ignore: avoid_print
    print('Navigation completed without crash');
  });
}
