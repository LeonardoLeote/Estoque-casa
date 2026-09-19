import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/categoria_model.dart';
import 'supabase_service.dart';

/// Carrega e edita as categorias, com cache local para o app abrir offline.
class CategoriaService {
  static const _kCache = 'cache_categorias_v1';

  static List<CategoriaModel> _categorias = CategoriaModel.padrao;

  /// Categorias em memória, já ordenadas. Nunca fica vazio.
  static List<CategoriaModel> get categorias => _categorias;

  static List<String> get nomes => _categorias.map((c) => c.nome).toList();

  /// Ícones da categoria, ou um genérico se ela sumiu.
  static List<String> emojisDe(String nome) {
    for (final c in _categorias) {
      if (c.nome == nome) return c.emojis;
    }
    return const ['📦'];
  }

  static bool existe(String nome) => _categorias.any((c) => c.nome == nome);

  /// Lê do servidor; cai no cache e depois no embutido se falhar.
  ///
  /// Nunca lança: sem categorias o app inteiro para de funcionar, e as
  /// padrão são um plano B melhor do que uma tela de erro.
  static Future<List<CategoriaModel>> carregar() async {
    try {
      final res = await Supabase.instance.client
          .from('categorias')
          .select()
          .order('ordem')
          .order('nome');
      final lista = res
          .map((e) => CategoriaModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      if (lista.isNotEmpty) {
        _categorias = lista;
        await _salvarCache(lista);
      }
    } catch (_) {
      final cache = await _lerCache();
      if (cache.isNotEmpty) _categorias = cache;
    }
    return _categorias;
  }

  static Future<void> salvar(CategoriaModel categoria) async {
    try {
      await Supabase.instance.client
          .from('categorias')
          .upsert(categoria.toSupabase());
      await carregar();
    } on PostgrestException catch (e) {
      throw EstoqueException(_traduzir(e));
    } catch (_) {
      throw EstoqueException('Sem conexão para salvar a categoria.');
    }
  }

  static Future<void> renomear(String de, String para) async {
    final client = Supabase.instance.client;
    try {
      final antiga = _categorias.firstWhere((c) => c.nome == de);
      // Cria a nova antes de mover os itens: `items.categoria` é texto
      // livre, mas deixar itens apontando para uma categoria inexistente
      // faria eles sumirem do filtro.
      await client.from('categorias').upsert(
            antiga.copyWith(nome: para).toSupabase(),
          );
      await client.from('items').update({'categoria': para}).eq('categoria', de);
      await client.from('categorias').delete().eq('nome', de);
      await carregar();
    } on PostgrestException catch (e) {
      throw EstoqueException(_traduzir(e));
    } catch (_) {
      throw EstoqueException('Sem conexão para renomear a categoria.');
    }
  }

  /// Quantos itens usam esta categoria — a tela avisa antes de excluir.
  static Future<int> contarItens(String nome) async {
    try {
      final res = await Supabase.instance.client
          .from('items')
          .select('id')
          .eq('categoria', nome);
      return res.length;
    } catch (_) {
      return 0;
    }
  }

  static Future<void> excluir(String nome) async {
    try {
      await Supabase.instance.client
          .from('categorias')
          .delete()
          .eq('nome', nome);
      await carregar();
    } catch (_) {
      throw EstoqueException('Sem conexão para excluir a categoria.');
    }
  }

  static String _traduzir(PostgrestException e) {
    final msg = e.message.toLowerCase();
    if (msg.contains('categorias') && msg.contains('does not exist')) {
      return 'Tabela "categorias" não existe. Rode a migração 002 no Supabase.';
    }
    if (e.code == '23505') return 'Já existe uma categoria com esse nome.';
    return 'Erro do banco: ${e.message}';
  }

  static Future<void> _salvarCache(List<CategoriaModel> lista) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kCache,
      jsonEncode(lista.map((c) => c.toSupabase()).toList()),
    );
  }

  static Future<List<CategoriaModel>> _lerCache() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kCache);
    if (raw == null || raw.isEmpty) return [];
    try {
      return (jsonDecode(raw) as List<dynamic>)
          .map((e) => CategoriaModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }
}
