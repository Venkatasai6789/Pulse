import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/phi.dart';
import 'package:pulse/widgets/widgets.dart';

void main() {
  testWidgets('PhiGauge renders and displays score correctly', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PhiGauge(
            phi: 91,
            size: 200,
            animate: false,
            label: 'PHI',
          ),
        ),
      ),
    );

    expect(find.text('91'), findsOneWidget);
    expect(find.text(' / 100'), findsOneWidget);
    expect(find.text('PHI'), findsOneWidget);
  });

  testWidgets('ScoreChip renders tier label', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ScoreChip.forTier(Tier.protect),
        ),
      ),
    );

    expect(find.text('PROTECT'), findsOneWidget);
  });

  testWidgets('TierBadge renders PROTECT with category name', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TierBadge(
            tier: Tier.protect,
            showCategory: true,
          ),
        ),
      ),
    );

    expect(find.text('PROTECT'), findsOneWidget);
    expect(find.text('Pollinator Paradise'), findsOneWidget);
  });

  testWidgets('PulseCard and PressableScale handle tap', (tester) async {
    bool tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PulseCard(
            onTap: () => tapped = true,
            child: const Text('Tap Me'),
          ),
        ),
      ),
    );

    expect(find.text('Tap Me'), findsOneWidget);
    await tester.tap(find.text('Tap Me'));
    expect(tapped, isTrue);
  });

  testWidgets('ParameterCard displays title and score', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ParameterCard(
            title: 'Pollinator Activity',
            score: 90,
            weight: '30%',
            label: 'Good',
          ),
        ),
      ),
    );

    expect(find.text('Pollinator Activity'), findsOneWidget);
    expect(find.text('90'), findsOneWidget);
    expect(find.text('Weight: 30%'), findsOneWidget);
    expect(find.text('Good'), findsOneWidget);
  });
}
