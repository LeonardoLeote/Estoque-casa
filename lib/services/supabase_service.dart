import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../constants.dart';
import '../models/historico_model.dart';
import '../models/item_model.dart';
import 'local_cache.dart';
import 'user_service.dart';

/// Erro de rede/servidor já traduzido para uma mensagem que cabe num SnackBar.
class EstoqueException implements Exception {
  final String mensagem;
  EstoqueException(this.mensagem);
  @override
  String toString() => mensagem;
}

class SupabaseService {
  static SupabaseClient get _client => Supabase.instance.client;

  static Never _traduzir(Object e) {
    if (e is PostgrestException) {
      throw EstoqueException('Erro do banco: ${e.message}');
    }
    if (e is AuthException) {
      throw EstoqueException('Erro de autenticação: ${e.message}');
    }
    throw EstoqueException(
      'Sem conexão com o servidor. Verifique sua internet.',
    );
  }

  // ── ITENS ───────────────────────────────────────────────────────────

  /// Busca os itens no servidor e atualiza o cache local.
  static Future<List<ItemModel>> getItems() async {
    try {
      final res = await _client.from('items').select().order('nome');
      final itens = res
          .map((e) => ItemModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      await LocalCache.salvarItens(itens);
      return itens;
    } catch (e) {
      _traduzir(e);
    }
  }

  static Future<ItemModel> addItem(ItemModel item) async {
    try {
      final res = await _client
          .from('items')
          .insert(item.toSupabase())
          .select()
          .single();
      final novo = ItemModel.fromJson(Map<String, dynamic>.from(res));
      await addHistorico(
        itemId: novo.id,
        itemNome: novo.nome,
        acao: Acoes.criou,
        quantidadeNova: novo.quantidade,
      );
      return novo;
    } catch (e) {
      if (e is EstoqueException) rethrow;
      _traduzir(e);
    }
  }

  /// Atualiza o item. [quantidadeAnterior] alimenta o histórico.
  static Future<void> updateItem(
    ItemModel item, {
    required double quantidadeAnterior,
    String acao = Acoes.editou,
  }) async {
    try {
      await _client.from('items').update(item.toSupabase()).eq('id', item.id);
      await addHistorico(
        itemId: item.id,
        itemNome: item.nome,
        acao: acao,
        quantidadeAnterior: quantidadeAnterior,
        quantidadeNova: item.quantidade,
      );
    } catch (e) {
      if (e is EstoqueException) rethrow;
      _traduzir(e);
    }
  }

  static Future<void> deleteItem(ItemModel item) async {
    try {
      // O histórico é gravado antes: `ON DELETE CASCADE` apaga as linhas
      // ligadas ao item, então o registro da remoção vai sem `item_id`.
      await addHistorico(
        itemId: null,
        itemNome: item.nome,
        acao: Acoes.removeu,
        quantidadeAnterior: item.quantidade,
      );
      await _client.from('items').delete().eq('id', item.id);
    } catch (e) {
      if (e is EstoqueException) rethrow;
      _traduzir(e);
    }
  }

  /// Insere vários itens de uma nota fiscal de uma vez.
  static Future<int> importarItens(List<ItemModel> itens) async {
    if (itens.isEmpty) return 0;
    try {
      final res = await _client
          .from('items')
          .insert(itens.map((e) => e.toSupabase()).toList())
          .select();
      for (final linha in res) {
        final novo = ItemModel.fromJson(Map<String, dynamic>.from(linha));
        await addHistorico(
          itemId: novo.id,
          itemNome: novo.nome,
          acao: Acoes.importou,
          quantidadeNova: novo.quantidade,
        );
      }
      return res.length;
    } catch (e) {
      if (e is EstoqueException) rethrow;
      _traduzir(e);
    }
  }

  /// Escuta mudanças na tabela `items` e devolve a lista já recarregada.
  ///
  /// Qualquer falha ao recarregar é silenciada de propósito: o realtime é
  /// um extra, e o `onErro` deixa a tela decidir se avisa o usuário.
  static RealtimeChannel subscribeItems(
    void Function(List<ItemModel>) onUpdate, {
    void Function(Object erro)? onErro,
  }) {
    return _client
        .channel('items_channel')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'items',
          callback: (_) async {
            try {
              onUpdate(await getItems());
            } catch (e) {
              onErro?.call(e);
            }
          },
        )
        .subscribe();
  }

  static Future<void> removerCanal(RealtimeChannel canal) async {
    try {
      await _client.removeChannel(canal);
    } catch (_) {
      // Desconectar no dispose nunca deve derrubar a tela.
    }
  }

  // ── HISTÓRICO ───────────────────────────────────────────────────────

  static Future<void> addHistorico({
    required String? itemId,
    required String itemNome,
    required String acao,
    double? quantidadeAnterior,
    double? quantidadeNova,
    String? usuario,
  }) async {
    try {
      await _client.from('historico').insert({
        'item_id': itemId,
        'item_nome': itemNome,
        'acao': acao,
        'quantidade_anterior': quantidadeAnterior,
        'quantidade_nova': quantidadeNova,
        'usuario': usuario ?? UserService.nome,
      });
    } catch (_) {
      // O histórico é secundário: falhar aqui não pode desfazer a operação
      // principal que o usuário acabou de ver dar certo.
    }
  }

  static Future<List<HistoricoModel>> getHistorico() async {
    try {
      final res = await _client
          .from('historico')
          .select()
          .order('created_at', ascending: false)
          .limit(100);
      return res
          .map((e) => HistoricoModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      _traduzir(e);
    }
  }
}
