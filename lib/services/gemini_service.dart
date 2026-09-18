import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../constants.dart';

/// Produto identificado pelo Gemini numa foto de nota fiscal.
class ProdutoNota {
  final String nome;
  final double quantidade;
  final String unidade;
  final String categoria;
  final String emoji;

  /// Marcado pelo usuário na tela de revisão antes de importar.
  bool selecionado;

  ProdutoNota({
    required this.nome,
    required this.quantidade,
    required this.unidade,
    required this.categoria,
    required this.emoji,
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
  {"nome": "Arroz Tipo 1", "quantidade": 5.0, "unidade": "kg", "categoria": "Grãos"},
  {"nome": "Leite Integral", "quantidade": 1.0, "unidade": "L", "categoria": "Laticínios"}
]

Regras:
- "nome": nome limpo e legível do produto, sem códigos e sem abreviações do cupom.
- "categoria": exatamente uma de Hortifruti, Carnes, Laticínios, Grãos, Bebidas, Limpeza.
- "unidade": exatamente uma de kg, g, ml, L, un, cx.
- Se não identificar a quantidade, use 1.0 e unidade "un".
- Se não houver nenhum produto válido, responda [].
''';

  static Future<List<ProdutoNota>> lerNotaFiscal(File imagem) async {
    if (!AppConstants.geminiConfigurado) {
      throw GeminiException(
        'Leitura de nota indisponível: GEMINI_API_KEY não foi configurada no build.',
      );
    }

    final bytes = await imagem.readAsBytes();
    final uri = Uri.parse(
      '$_endpointBase/${AppConstants.geminiModel}:generateContent',
    );

    late final http.Response resposta;
    try {
      resposta = await http
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
                        'mime_type': _mimeType(imagem.path),
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
      throw GeminiException('Sem internet para ler a nota fiscal.');
    } catch (_) {
      throw GeminiException('A leitura da nota demorou demais. Tente de novo.');
    }

    if (resposta.statusCode != 200) {
      throw GeminiException(_erroDaApi(resposta));
    }

    final texto = _extrairTexto(resposta.body);
    if (texto == null) {
      throw GeminiException('O Gemini não retornou nada legível.');
    }
    return _parsearProdutos(texto);
  }

  static String _mimeType(String caminho) {
    final p = caminho.toLowerCase();
    if (p.endsWith('.png')) return 'image/png';
    if (p.endsWith('.webp')) return 'image/webp';
    if (p.endsWith('.heic')) return 'image/heic';
    return 'image/jpeg';
  }

  static String _erroDaApi(http.Response r) {
    try {
      final corpo = jsonDecode(r.body) as Map<String, dynamic>;
      final msg = (corpo['error'] as Map?)?['message']?.toString();
      if (msg != null && msg.isNotEmpty) {
        if (r.statusCode == 404) {
          return 'Modelo "${AppConstants.geminiModel}" indisponível. '
              'Troque GEMINI_MODEL no build.';
        }
        if (r.statusCode == 429) {
          return 'Limite de uso do Gemini atingido. Tente mais tarde.';
        }
        return 'Gemini: $msg';
      }
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

  static String _validar(String? valor, List<String> validos, String padrao) {
    if (valor == null) return padrao;
    for (final v in validos) {
      if (v.toLowerCase() == valor.trim().toLowerCase()) return v;
    }
    return padrao;
  }
}
