import 'package:estoque_casa/models/categoria_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CategoriaModel.fromJson', () {
    test('lê a lista de emojis do Postgres', () {
      final c = CategoriaModel.fromJson({
        'nome': 'Besteiras',
        'emoji': '🍕',
        'emojis': ['🍕', '🍔', '🌭'],
        'ordem': 60,
      });
      expect(c.nome, 'Besteiras');
      expect(c.emoji, '🍕');
      expect(c.emojis, ['🍕', '🍔', '🌭']);
      expect(c.ordem, 60);
    });

    test('categoria sem ícones ganha um genérico', () {
      // Uma lista vazia deixaria o grid de ícones sem nada para escolher.
      final c = CategoriaModel.fromJson({'nome': 'Vazia', 'emojis': []});
      expect(c.emojis, ['📦']);
      expect(c.emoji, '📦');
    });

    test('descarta entradas vazias vindas do banco', () {
      final c = CategoriaModel.fromJson({
        'nome': 'X',
        'emojis': ['🍕', '', '🍔'],
      });
      expect(c.emojis, ['🍕', '🍔']);
    });

    test('ordem ausente vai para o fim da lista', () {
      expect(CategoriaModel.fromJson({'nome': 'X'}).ordem, 100);
    });
  });

  group('fallback embutido', () {
    test('existe mesmo sem a tabela no banco', () {
      final padrao = CategoriaModel.padrao;
      expect(padrao, isNotEmpty);
      for (final c in padrao) {
        expect(c.emojis, isNotEmpty, reason: '${c.nome} sem ícones');
        expect(c.nome, isNotEmpty);
      }
    });
  });

  group('copyWith', () {
    test('renomear preserva os ícones', () {
      final c = CategoriaModel(
        nome: 'Besteiras',
        emoji: '🍕',
        emojis: const ['🍕', '🍔'],
        ordem: 60,
      );
      final nova = c.copyWith(nome: 'Junk Food');
      expect(nova.nome, 'Junk Food');
      expect(nova.emojis, ['🍕', '🍔']);
      expect(nova.ordem, 60);
    });
  });

  group('toSupabase', () {
    test('manda os campos que a tabela espera', () {
      final json = CategoriaModel(
        nome: 'Padaria',
        emoji: '🥖',
        emojis: const ['🥖', '🍞'],
        ordem: 50,
      ).toSupabase();
      expect(json.keys.toSet(), {'nome', 'emoji', 'emojis', 'ordem'});
      expect(json['emojis'], ['🥖', '🍞']);
    });
  });
}
