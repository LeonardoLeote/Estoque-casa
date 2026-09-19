import 'dart:convert';

import 'package:estoque_casa/services/gemini_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Resposta 200 do Gemini com um produto.
String _respostaOk() => jsonEncode({
      'candidates': [
        {
          'content': {
            'parts': [
              {
                'text': '[{"nome":"Arroz","quantidade":5,'
                    '"unidade":"kg","categoria":"Grãos"}]'
              }
            ]
          }
        }
      ]
    });

String _respostaErro(String msg) => jsonEncode({
      'error': {'message': msg}
    });

Future<List<ProdutoNota>> _analisar(MockClient client) =>
    GeminiService.analisarImagem([1, 2, 3], 'image/jpeg', client: client);

void main() {
  group('classificação de erro', () {
    test('sobrecarga e limite são transitórios', () {
      for (final s in [429, 500, 502, 503, 504]) {
        expect(GeminiService.ehTransitorio(s), isTrue, reason: 'status $s');
      }
    });

    test('chave e modelo errados não são transitórios', () {
      for (final s in [400, 403, 404]) {
        expect(GeminiService.ehTransitorio(s), isFalse, reason: 'status $s');
      }
    });
  });

  group('retry', () {
    test('um 503 passageiro não derruba a leitura', () async {
      var chamadas = 0;
      final produtos = await _analisar(MockClient((_) async {
        chamadas++;
        if (chamadas == 1) {
          return http.Response(_respostaErro('high demand'), 503);
        }
        return http.Response(_respostaOk(), 200);
      }));

      expect(chamadas, 2);
      expect(produtos.single.nome, 'Arroz');
      expect(produtos.single.quantidade, 5);
    });

    test('503 sem fim cai no modelo reserva e depois desiste', () async {
      final modelosUsados = <String>[];
      await expectLater(
        _analisar(MockClient((req) async {
          modelosUsados.add(req.url.pathSegments.last);
          return http.Response(_respostaErro('high demand'), 503);
        })),
        throwsA(isA<GeminiException>().having(
          (e) => e.mensagem,
          'mensagem',
          contains('sobrecarregado'),
        )),
      );

      // 3 tentativas no principal + 3 no reserva.
      expect(modelosUsados.length, 6);
      expect(modelosUsados.toSet().length, 2, reason: 'trocou de modelo');
    });

    test('chave recusada falha na hora, sem insistir', () async {
      var chamadas = 0;
      await expectLater(
        _analisar(MockClient((_) async {
          chamadas++;
          return http.Response(_respostaErro('invalid key'), 403);
        })),
        throwsA(isA<GeminiException>().having(
          (e) => e.mensagem,
          'mensagem',
          contains('chave do Gemini foi recusada'),
        )),
      );

      // Uma por modelo, sem repetir: insistir com chave inválida é inútil.
      expect(chamadas, 2);
    });

    test('resposta 200 ilegível não vira retry', () async {
      var chamadas = 0;
      await expectLater(
        _analisar(MockClient((_) async {
          chamadas++;
          return http.Response('isso não é json', 200);
        })),
        throwsA(isA<GeminiException>()),
      );
      expect(chamadas, 2);
    });
  });

  group('parsing', () {
    test('categoria e unidade inválidas caem no padrão', () async {
      final produtos = await _analisar(MockClient((_) async {
        return http.Response(
          jsonEncode({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {
                      'text': '```json\n[{"nome":"Sabão","quantidade":"2",'
                          '"unidade":"litro","categoria":"Casa"}]\n```'
                    }
                  ]
                }
              }
            ]
          }),
          200,
        );
      }));

      final p = produtos.single;
      expect(p.nome, 'Sabão');
      expect(p.quantidade, 2, reason: 'quantidade veio como string');
      expect(p.unidade, 'un', reason: '"litro" não é unidade válida');
      expect(p.categoria, 'Grãos', reason: '"Casa" não é categoria válida');
    });

    test('ignora partes de raciocínio dos modelos novos', () async {
      final produtos = await _analisar(MockClient((_) async {
        return http.Response(
          jsonEncode({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {'text': 'pensando...', 'thought': true},
                    {
                      'text': '[{"nome":"Leite","quantidade":1,'
                          '"unidade":"L","categoria":"Laticínios"}]'
                    }
                  ]
                }
              }
            ]
          }),
          200,
        );
      }));

      expect(produtos.single.nome, 'Leite');
    });
  });
}
