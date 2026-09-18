import 'package:estoque_casa/models/item_model.dart';
import 'package:flutter_test/flutter_test.dart';

ItemModel _item({required double quantidade, required double minimo}) =>
    ItemModel(
      id: 'x',
      nome: 'Arroz',
      categoria: 'Grãos',
      quantidade: quantidade,
      unidade: 'kg',
      minimo: minimo,
      emoji: '🍚',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

void main() {
  group('status do item', () {
    test('quantidade zerada é "vazio"', () {
      expect(_item(quantidade: 0, minimo: 2).status, ItemStatus.vazio);
    });

    test('no mínimo exato já conta como "baixo"', () {
      expect(_item(quantidade: 2, minimo: 2).status, ItemStatus.baixo);
    });

    test('acima do mínimo é "ok"', () {
      expect(_item(quantidade: 3, minimo: 2).status, ItemStatus.ok);
    });

    test('mínimo 0 desliga o alerta de estoque baixo', () {
      expect(_item(quantidade: 0.5, minimo: 0).status, ItemStatus.ok);
    });

    test('mínimo 0 ainda detecta quantidade zerada', () {
      expect(_item(quantidade: 0, minimo: 0).status, ItemStatus.vazio);
    });
  });

  group('formatação', () {
    test('inteiro não ganha casa decimal', () {
      expect(ItemModel.formatarNumero(5), '5');
    });

    test('decimal usa vírgula', () {
      expect(ItemModel.formatarNumero(1.5), '1,50');
    });

    test('quantidade formatada junta número e unidade', () {
      expect(_item(quantidade: 2, minimo: 0).quantidadeFormatada, '2 kg');
    });
  });

  group('fromJson', () {
    test('aceita número vindo como string (NUMERIC do Postgres)', () {
      final item = ItemModel.fromJson({
        'id': 'abc',
        'nome': 'Leite',
        'categoria': 'Laticínios',
        'quantidade': '1.50',
        'unidade': 'L',
        'minimo': '2',
        'emoji': '🥛',
        'created_at': '2026-01-01T00:00:00Z',
        'updated_at': '2026-01-01T00:00:00Z',
      });
      expect(item.quantidade, 1.5);
      expect(item.minimo, 2);
      expect(item.status, ItemStatus.baixo);
    });

    test('usa padrões quando campos opcionais faltam', () {
      final item = ItemModel.fromJson({'id': 1, 'nome': 'Sal'});
      expect(item.emoji, '📦');
      expect(item.unidade, 'un');
      expect(item.quantidade, 0);
    });
  });
}
