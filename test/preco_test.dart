import 'dart:convert';

import 'package:estoque_casa/models/item_model.dart';
import 'package:estoque_casa/services/gemini_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

ItemModel _item({double? preco, double quantidade = 2}) => ItemModel(
      id: 'x',
      nome: 'Arroz',
      categoria: 'Grãos',
      quantidade: quantidade,
      unidade: 'kg',
      minimo: 1,
      emoji: '🍚',
      preco: preco,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

Future<List<ProdutoNota>> _lerNota(String textoDoGemini) =>
    GeminiService.analisarImagem(
      [1],
      'image/jpeg',
      client: MockClient((_) async => http.Response(
            jsonEncode({
              'candidates': [
                {
                  'content': {
                    'parts': [
                      {'text': textoDoGemini}
                    ]
                  }
                }
              ]
            }),
            200,
          )),
    );

void main() {
  group('preço no item', () {
    test('sem preço não vira zero', () {
      final item = _item();
      expect(item.preco, isNull);
      expect(item.precoFormatado, isNull);
      expect(item.valorEmEstoque, isNull);
    });

    test('valor em estoque é preço × quantidade', () {
      expect(_item(preco: 5.5, quantidade: 4).valorEmEstoque, 22);
    });

    test('formata em reais com vírgula', () {
      expect(_item(preco: 24.9).precoFormatado, r'R$ 24,90');
      expect(ItemModel.formatarDinheiro(7), r'R$ 7,00');
    });

    test('vai e volta pelo JSON do Supabase', () {
      final json = _item(preco: 12.34).toCache();
      expect(ItemModel.fromJson(json).preco, 12.34);
    });

    test('lê preço que o Postgres devolve como string', () {
      final item = ItemModel.fromJson({
        'id': '1',
        'nome': 'Leite',
        'preco': '4.49',
      });
      expect(item.preco, 4.49);
    });

    test('copyWith preserva o preço, e limparPreco apaga', () {
      final base = _item(preco: 10);
      expect(base.copyWith(quantidade: 9).preco, 10);
      expect(base.copyWith(limparPreco: true).preco, isNull);
    });
  });

  group('preço lido da nota', () {
    test('número simples', () async {
      final p = await _lerNota(
        '[{"nome":"Arroz","quantidade":1,"unidade":"kg",'
        '"categoria":"Grãos","preco_unitario":24.90}]',
      );
      expect(p.single.preco, 24.90);
    });

    test('texto com R\$ e vírgula', () async {
      final p = await _lerNota(
        '[{"nome":"Arroz","quantidade":1,"unidade":"kg",'
        '"categoria":"Grãos","preco_unitario":"R\$ 24,90"}]',
      );
      expect(p.single.preco, 24.90);
    });

    test('null e zero viram "sem preço", não grátis', () async {
      final p = await _lerNota(
        '[{"nome":"A","quantidade":1,"unidade":"un","categoria":"Grãos","preco_unitario":null},'
        '{"nome":"B","quantidade":1,"unidade":"un","categoria":"Grãos","preco_unitario":0}]',
      );
      expect(p[0].preco, isNull);
      expect(p[1].preco, isNull);
    });

    test('campo ausente não quebra a leitura', () async {
      final p = await _lerNota(
        '[{"nome":"Arroz","quantidade":1,"unidade":"kg","categoria":"Grãos"}]',
      );
      expect(p.single.nome, 'Arroz');
      expect(p.single.preco, isNull);
    });
  });

  group('produto da nota é editável', () {
    test('a tela de revisão consegue corrigir os campos', () async {
      final p = (await _lerNota(
        '[{"nome":"ARR TIO JOAO","quantidade":1,"unidade":"un",'
        '"categoria":"Grãos","preco_unitario":24.90}]',
      ))
          .single;

      p.nome = 'Arroz Tio João';
      p.quantidade = 5;
      p.unidade = 'kg';
      p.preco = 22.5;

      expect(p.nome, 'Arroz Tio João');
      expect(p.quantidade, 5);
      expect(p.unidade, 'kg');
      expect(p.preco, 22.5);
    });
  });
}
