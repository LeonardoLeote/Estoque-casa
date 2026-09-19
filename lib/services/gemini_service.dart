import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../constants.dart';

/// Produto identificado pelo Gemini numa foto de nota fiscal.
/// Campos mutáveis: a tela de revisão deixa o usuário corrigir o que o
/// Gemini leu errado antes de importar.
class ProdutoNota {
  String nome;
  double quantidade;
  String unidade;
  String categoria;
  String emoji;

  /// Preço unitário lido da nota. `null` quando não apareceu.
  double? preco;

  /// Marcado pelo usuário na tela de revisão antes de importar.
  bool selecionado;

  ProdutoNota({
    required this.nome,
    required this.quantidade,
    required this.unidade,
    required this.categoria,
    required this.emoji,
    this.preco,
    this.selecionado = true,
  });
}

class GeminiException implements Exception {
  final String mensagem;
  GeminiException(this.mensagem);
  @override
  String toString() => mensagem;
}

/// Leitura de nota fiscal via API REST do Gemini.
///
/// Optei pela REST direta em vez do pacote `google_generative_ai`: o modelo
/// é um parâmetro livre (o pacote é datado e os modelos mudam de nome com
/// frequência) e o parsing da resposta fica sob controle aqui.
class GeminiService {
  static const _endpointBase =
      'https://generativelanguage.googleapis.com/v1beta/models';

  static const _prompt = '''
Analise esta imagem de nota fiscal/cupom fiscal brasileiro e extraia APENAS os
produtos alimentícios e de limpeza doméstica. Ignore serviços, taxas,
descontos, totais e produtos que não sejam comida ou limpeza.

Responda SOMENTE com um array JSON, sem markdown e sem texto em volta:
[
  {"nome": "Arroz Tipo 1", "quantidade": 5.0, "unidade": "kg", "categoria": "Grãos", "preco_unitario": 24.90},
  {"nome": "Leite Integral", "quantidade": 1.0, "unidade": "L", "categoria": "Laticínios", "preco_unitario": 4.49}
]

Regras:
- "nome": nome limpo e legível do produto, sem códigos e sem abreviações do cupom.
- "categoria": exatamente uma de Hortifruti, Carnes, Laticínios, Grãos, Bebidas, Limpeza.
- "unidade": exatamente uma de kg, g, ml, L, un, cx.
- "preco_unitario": preço de UMA unidade em reais, como número (24.90, não "R\$ 24,90").
  Se a nota mostrar só o total da linha, divida pelo total de unidades.
  Se não conseguir identificar o preço, use null.
- Se não identificar a quantidade, use 1.0 e unidade "un".
- Se não houver nenhum produto válido, responda [].
''';

  /// Quantas vezes insistir no mesmo modelo antes de trocar.
  static const _tentativasPorModelo = 3;

  /// Respostas que valem uma nova tentativa: sobrecarga e limite de uso são
  /// passageiros, e falhar de primeira obrigaria o usuário a refotografar.
  static bool ehTransitorio(int status) =>
      status == 429 || status == 500 || status == 502 || status == 503 ||
      status == 504;

  static Future<List<ProdutoNota>> lerNotaFiscal(
    File imagem, {
    http.Client? client,
  }) async {
    final bytes = await imagem.readAsBytes();
    return analisarImagem(
      bytes,
      _mimeType(imagem.path),
      client: client,
    );
  }

  /// Separado de [lerNotaFiscal] para poder ser testado sem tocar no disco.
  static Future<List<ProdutoNota>> analisarImagem(
    List<int> bytes,
    String mimeType, {
    http.Client? client,
  }) async {
    if (!AppConstants.geminiConfigurado) {
      throw GeminiException(
        'Leitura de nota indisponível: GEMINI_API_KEY não foi configurada no build.',
      );
    }

    final cliente = client ?? http.Client();
    final nossoCliente = client == null;
    try {
      GeminiException? ultimoErro;

      // Se o modelo principal estiver sobrecarregado, o reserva costuma
      // estar em outra fila de capacidade.
      for (final modelo in AppConstants.modelosGemini) {
        for (var tentativa = 1; tentativa <= _tentativasPorModelo; tentativa++) {
          final resultado = await _tentar(cliente, modelo, bytes, mimeType);

          if (resultado.produtos != null) return resultado.produtos!;

          ultimoErro = resultado.erro;
          if (!resultado.podeTentarDeNovo) break; // erro definitivo: troca de modelo

          if (tentativa < _tentativasPorModelo) {
            await Future<void>.delayed(
              Duration(milliseconds: 1500 * tentativa),
            );
          }
        }
      }

      throw ultimoErro ??
          GeminiException('Não consegui falar com o Gemini agora.');
    } finally {
      // Só fechamos o que criamos: um client injetado é do chamador.
      if (nossoCliente) cliente.close();
    }
  }

  static Future<_Tentativa> _tentar(
    http.Client client,
    String modelo,
    List<int> bytes,
    String mimeType,
  ) async {
    final uri = Uri.parse('$_endpointBase/$modelo:generateContent');

    late final http.Response resposta;
    try {
      resposta = await client
          .post(
            uri,
            headers: {
              'x-goog-api-key': AppConstants.geminiApiKey,
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'contents': [
                {
                  'parts': [
                    {'text': _prompt},
                    {
                      'inline_data': {
                        'mime_type': mimeType,
                        'data': base64Encode(bytes),
                      }
                    },
                  ]
                }
              ],
              'generationConfig': {'temperature': 0.1},
            }),
          )
          .timeout(const Duration(seconds: 90));
    } on SocketException {
      return _Tentativa.falha(
        GeminiException('Sem internet para ler a nota fiscal.'),
        podeTentarDeNovo: false,
      );
    } catch (_) {
      return _Tentativa.falha(
        GeminiException('A leitura da nota demorou demais. Tente de novo.'),
        podeTentarDeNovo: true,
      );
    }

    if (resposta.statusCode != 200) {
      return _Tentativa.falha(
        GeminiException(_erroDaApi(resposta)),
        podeTentarDeNovo: ehTransitorio(resposta.statusCode),
      );
    }

    final texto = _extrairTexto(resposta.body);
    if (texto == null) {
      return _Tentativa.falha(
        GeminiException('O Gemini não retornou nada legível.'),
        podeTentarDeNovo: false,
      );
    }

    try {
      return _Tentativa.ok(_parsearProdutos(texto));
    } on GeminiException catch (e) {
      return _Tentativa.falha(e, podeTentarDeNovo: false);
    }
  }

  static String _mimeType(String caminho) {
    final p = caminho.toLowerCase();
    if (p.endsWith('.png')) return 'image/png';
    if (p.endsWith('.webp')) return 'image/webp';
    if (p.endsWith('.heic')) return 'image/heic';
    return 'image/jpeg';
  }

  /// Mensagens em português: o texto cru do Google é em inglês e não diz ao
  /// usuário o que fazer.
  static String _erroDaApi(http.Response r) {
    switch (r.statusCode) {
      case 503:
      case 500:
      case 502:
      case 504:
        return 'O Gemini está sobrecarregado agora. Tente de novo em alguns minutos.';
      case 429:
        return 'Limite de uso do Gemini atingido. Tente mais tarde.';
      case 404:
        return 'Nenhum modelo do Gemini disponível para esta chave.';
      case 400:
      case 403:
        return 'A chave do Gemini foi recusada. Confira GEMINI_API_KEY no build.';
    }
    try {
      final corpo = jsonDecode(r.body) as Map<String, dynamic>;
      final msg = (corpo['error'] as Map?)?['message']?.toString();
      if (msg != null && msg.isNotEmpty) return 'Gemini: $msg';
    } catch (_) {
      // Corpo não-JSON: cai na mensagem genérica abaixo.
    }
    return 'Gemini respondeu com erro ${r.statusCode}.';
  }

  /// Junta todos os `parts` de texto do primeiro candidato. Modelos recentes
  /// podem devolver partes extras (ex.: raciocínio), que são ignoradas aqui.
  static String? _extrairTexto(String corpo) {
    try {
      final json = jsonDecode(corpo) as Map<String, dynamic>;
      final candidatos = json['candidates'] as List<dynamic>?;
      if (candidatos == null || candidatos.isEmpty) return null;
      final partes = ((candidatos.first as Map)['content']
          as Map<String, dynamic>?)?['parts'] as List<dynamic>?;
      if (partes == null) return null;
      final buffer = StringBuffer();
      for (final parte in partes) {
        if (parte is Map && parte['thought'] != true && parte['text'] is String) {
          buffer.write(parte['text'] as String);
        }
      }
      final texto = buffer.toString().trim();
      return texto.isEmpty ? null : texto;
    } catch (_) {
      return null;
    }
  }

  static List<ProdutoNota> _parsearProdutos(String texto) {
    final limpo = _isolarJson(texto);
    final List<dynamic> lista;
    try {
      lista = jsonDecode(limpo) as List<dynamic>;
    } catch (_) {
      throw GeminiException(
        'Não consegui entender a resposta do Gemini. Tente uma foto mais nítida.',
      );
    }

    final produtos = <ProdutoNota>[];
    for (final bruto in lista) {
      if (bruto is! Map) continue;
      final nome = (bruto['nome'] ?? '').toString().trim();
      if (nome.isEmpty) continue;

      final categoria = _validar(
        bruto['categoria']?.toString(),
        AppConstants.categorias,
        'Grãos',
      );
      final unidade =
          _validar(bruto['unidade']?.toString(), AppConstants.unidades, 'un');

      var quantidade = 1.0;
      final q = bruto['quantidade'];
      if (q is num) {
        quantidade = q.toDouble();
      } else if (q != null) {
        quantidade = double.tryParse(q.toString().replaceAll(',', '.')) ?? 1.0;
      }
      if (quantidade <= 0) quantidade = 1.0;

      produtos.add(ProdutoNota(
        nome: nome,
        quantidade: quantidade,
        unidade: unidade,
        categoria: categoria,
        emoji: AppConstants.emojisDaCategoria(categoria).first,
        preco: _lerPreco(bruto['preco_unitario']),
      ));
    }
    return produtos;
  }

  /// Remove cercas de markdown e sobras de texto em volta do array.
  static String _isolarJson(String texto) {
    var t = texto.replaceAll('```json', '').replaceAll('```', '').trim();
    final ini = t.indexOf('[');
    final fim = t.lastIndexOf(']');
    if (ini >= 0 && fim > ini) t = t.substring(ini, fim + 1);
    return t;
  }

  /// Aceita número ou texto ("R$ 24,90"); descarta zero e negativo, que
  /// significam "não consegui ler", não "de graça".
  static double? _lerPreco(Object? bruto) {
    if (bruto == null) return null;
    double? v;
    if (bruto is num) {
      v = bruto.toDouble();
    } else {
      final limpo = bruto
          .toString()
          .replaceAll(RegExp(r'[^0-9,.]'), '')
          .replaceAll(',', '.');
      v = double.tryParse(limpo);
    }
    if (v == null || v <= 0) return null;
    return v;
  }

  static String _validar(String? valor, List<String> validos, String padrao) {
    if (valor == null) return padrao;
    for (final v in validos) {
      if (v.toLowerCase() == valor.trim().toLowerCase()) return v;
    }
    return padrao;
  }
}

/// Resultado de uma chamada: os produtos, ou o erro e se vale insistir.
class _Tentativa {
  final List<ProdutoNota>? produtos;
  final GeminiException? erro;
  final bool podeTentarDeNovo;

  _Tentativa.ok(List<ProdutoNota> this.produtos)
      : erro = null,
        podeTentarDeNovo = false;

  _Tentativa.falha(GeminiException this.erro, {required this.podeTentarDeNovo})
      : produtos = null;
}
