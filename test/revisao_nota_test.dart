import 'package:estoque_casa/screens/revisao_nota_screen.dart';
import 'package:estoque_casa/services/gemini_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

ProdutoNota _produto({String nome = 'ARR TIO JOAO', double? preco}) =>
    ProdutoNota(
      nome: nome,
      quantidade: 1,
      unidade: 'un',
      categoria: 'Grãos',
      emoji: '🍚',
      preco: preco,
    );

Future<void> _montar(WidgetTester tester, List<ProdutoNota> produtos) async {
  await tester.pumpWidget(
    MaterialApp(home: RevisaoNotaScreen(produtos: produtos)),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('mostra o preço lido e o total dos selecionados',
      (tester) async {
    await _montar(tester, [
      _produto(nome: 'Arroz', preco: 10),
      _produto(nome: 'Leite', preco: 5),
    ]);

    expect(find.textContaining(r'R$ 10,00'), findsOneWidget);
    expect(find.text('Total'), findsOneWidget);
    expect(find.text(r'R$ 15,00'), findsOneWidget);
  });

  testWidgets('total vira "parcial" quando algum item não tem preço',
      (tester) async {
    await _montar(tester, [
      _produto(nome: 'Arroz', preco: 10),
      _produto(nome: 'Sal'),
    ]);

    expect(find.text('Total (itens com preço)'), findsOneWidget);
    expect(find.text(r'R$ 10,00'), findsOneWidget);
  });

  testWidgets('desmarcar um item tira ele do total', (tester) async {
    await _montar(tester, [
      _produto(nome: 'Arroz', preco: 10),
      _produto(nome: 'Leite', preco: 5),
    ]);

    await tester.tap(find.byType(Checkbox).last);
    await tester.pumpAndSettle();

    expect(find.text(r'R$ 10,00'), findsWidgets);
    expect(find.text('Importar 1 item'), findsOneWidget);
  });

  testWidgets('o lápis abre o editor e a correção aparece na lista',
      (tester) async {
    await _montar(tester, [_produto(nome: 'ARR TIO JOAO')]);

    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Corrigir produto'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nome'),
      'Arroz Tio João',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Preço unitário'),
      '22,50',
    );
    await tester.tap(find.text('Salvar correção'));
    await tester.pumpAndSettle();

    expect(find.text('Arroz Tio João'), findsOneWidget);
    expect(find.text('ARR TIO JOAO'), findsNothing);
    expect(find.textContaining(r'R$ 22,50'), findsWidgets);
  });

  testWidgets('o editor recusa nome vazio', (tester) async {
    await _montar(tester, [_produto(nome: 'Arroz')]);

    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'Nome'), '');
    await tester.tap(find.text('Salvar correção'));
    await tester.pumpAndSettle();

    expect(find.text('Informe o nome'), findsOneWidget);
    expect(find.text('Corrigir produto'), findsOneWidget, reason: 'não fechou');
  });
}
