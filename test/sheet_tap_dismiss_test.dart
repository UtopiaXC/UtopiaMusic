import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('tapping outside DraggableScrollableSheet dismisses sheet with Stack + GestureDetector', (tester) async {
    bool dismissed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (ctx) => Stack(
                    children: [
                      Positioned.fill(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            dismissed = true;
                            Navigator.of(ctx).pop();
                          },
                        ),
                      ),
                      DraggableScrollableSheet(
                        initialChildSize: 0.5,
                        minChildSize: 0.3,
                        maxChildSize: 0.95,
                        builder: (ctx, scrollController) {
                          return Container(
                            color: Colors.blue,
                            child: ListView(
                              controller: scrollController,
                              children: const [
                                SizedBox(height: 100, child: Text('Card Content')),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
              child: const Text('Open Sheet'),
            ),
          ),
        ),
      ),
    );

    // Open sheet
    await tester.tap(find.text('Open Sheet'));
    await tester.pumpAndSettle();
    expect(find.text('Card Content'), findsOneWidget);

    // Tap on card content -> should NOT dismiss
    await tester.tap(find.text('Card Content'));
    await tester.pumpAndSettle();
    expect(dismissed, false);
    expect(find.text('Card Content'), findsOneWidget);

    // Tap on top area (y = 100, above 0.5 of 600 height)
    await tester.tapAt(const Offset(200, 100));
    await tester.pumpAndSettle();
    expect(dismissed, true);
    expect(find.text('Card Content'), findsNothing);
  });
}
