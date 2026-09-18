import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/item_model.dart';

/// Cache local dos itens para o app abrir e funcionar (em leitura) sem internet.
///
/// Limitação conhecida: escritas exigem conexão. Quando offline, as telas
/// avisam o usuário em vez de fingir que salvaram.
class LocalCache {
  static const _kItens = 'cache_itens_v1';
  static const _kAtualizadoEm = 'cache_itens_atualizado_em';

  static Future<void> salvarItens(List<ItemModel> itens) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kItens,
      jsonEncode(itens.map((e) => e.toCache()).toList()),
    );
    await prefs.setString(_kAtualizadoEm, DateTime.now().toIso8601String());
  }

  static Future<List<ItemModel>> lerItens() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kItens);
    if (raw == null || raw.isEmpty) return [];
    try {
      final lista = jsonDecode(raw) as List<dynamic>;
      return lista
          .map((e) => ItemModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<DateTime?> atualizadoEm() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kAtualizadoEm);
    return raw == null ? null : DateTime.tryParse(raw);
  }
}
