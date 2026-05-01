import 'package:finance_pet/app.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  testWidgets('abre a tela de login quando nao autenticado', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: FinancePetApp()));

    expect(find.text('Bem-vindo'), findsOneWidget);
    expect(find.text('Entrar'), findsOneWidget);
  });
}
