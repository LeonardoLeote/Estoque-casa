import 'package:estoque_casa/models/item_model.dart';
import 'package:estoque_casa/screens/lista_compras_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

ItemModel _item(
  String nome,
  String categoria,
  double quantidade,
  double minimo,
) =>
    ItemModel(
      id: nome,
      nome: nome,
      categoria: categoria,
      quantidade: quantidade,
      unidade: 'un',
      minimo: minimo,
      emoji: '📦',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

Future<void> _montar(WidgetTester tester, List<ItemModel> itens) async {
  await tester.pumpWidget(
    MaterialApp(home: ListaComprasScreen(itens: itens)),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('lista só o que precisa repor, agrupado por categoria',
      (tester) async {
    await _montar(tester, [
      _item('Arroz', 'Grãos', 0, 1), // faltando
      _item('Leite', 'Laticínios', 1, 2), // baixo
      _item('Feijão', 'Grãos', 10, 1), // ok — não deve aparecer
    ]);

    expect(find.text('Arroz'), findsOneWidget);
    expect(find.text('Leite'), findsOneWidget);
    expect(find.text('Feijão'), findsNothing);

    // Cabeçalhos de categoria dos itens que sobraram.
    expect(find.text('Grãos'), findsOneWidget);
    expect(find.text('Laticínios'), findsOneWidget);
  });

  testWidgets('marcar um item é só visual e alimenta o contador',
      (tester) async {
    await _montar(tester, [_item('Arroz', 'Grãos', 0, 1)]);

    expect(find.textContaining('0 marcado'), findsOneWidget);

    await tester.tap(find.byType(Checkbox).first);
    await tester.pump();

    expect(find.textContaining('1 marcado'), findsOneWidget);
  });

  testWidgets('estoque todo em dia mostra o estado vazio', (tester) async {
    await _montar(tester, [_item('Feijão', 'Grãos', 10, 1)]);

    expect(find.text('Nada para comprar!'), findsOneWidget);
    expect(find.text('Compartilhar lista'), findsNothing);
  });
}
