import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lapzy/widgets/pressable.dart';

void main() {
  group('Pressable', () {
    testWidgets('renderiza o filho corretamente', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Pressable(
              child: Text('BOTÃO'),
            ),
          ),
        ),
      );

      expect(find.text('BOTÃO'), findsOneWidget);
    });

    testWidgets('chama onTap ao ser tocado', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Pressable(
              onTap: () => tapped = true,
              child: const Text('BOTÃO'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('BOTÃO'));
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
    });

    testWidgets('não chama callback quando onTap é null', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Pressable(
              child: Text('BOTÃO'),
            ),
          ),
        ),
      );

      // Deve renderizar e aceitar toque sem crash
      await tester.tap(find.text('BOTÃO'));
      await tester.pumpAndSettle();
    });

    testWidgets('aplica escala reduzida ao pressionar', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Pressable(
              onTap: () {},
              // Container com cor é necessário para ser opaco ao hit testing
              child: Container(
                key: const Key('inner'),
                width: 80,
                height: 40,
                color: Colors.white,
              ),
            ),
          ),
        ),
      );

      // createGesture + down + pump garante que onTapDown processe antes da leitura
      final gesture = await tester.createGesture();
      await gesture.down(tester.getCenter(find.byKey(const Key('inner'))));
      await tester.pump();

      // AnimatedScale.scale é o target (0.93 quando pressionado)
      final scale = tester.widget<AnimatedScale>(find.byType(AnimatedScale));
      expect(scale.scale, lessThan(1.0));

      await gesture.up();
      await tester.pumpAndSettle();

      final scaleAfter = tester.widget<AnimatedScale>(find.byType(AnimatedScale));
      expect(scaleAfter.scale, equals(1.0));
    });
  });
}
