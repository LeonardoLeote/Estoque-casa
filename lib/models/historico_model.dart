import 'package:flutter/material.dart';
import '../constants.dart';
import 'item_model.dart';

class HistoricoModel {
  final String id;
  final String? itemId;
  final String itemNome;
  final String acao;
  final double? quantidadeAnterior;
  final double? quantidadeNova;
  final String usuario;
  final DateTime createdAt;

  const HistoricoModel({
    required this.id,
    required this.itemId,
    required this.itemNome,
    required this.acao,
    this.quantidadeAnterior,
    this.quantidadeNova,
    required this.usuario,
    required this.createdAt,
  });

  static double? _toDoubleOrNull(Object? v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  factory HistoricoModel.fromJson(Map<String, dynamic> json) => HistoricoModel(
        id: json['id'].toString(),
        itemId: json['item_id']?.toString(),
        itemNome: (json['item_nome'] ?? '') as String,
        acao: (json['acao'] ?? '') as String,
        quantidadeAnterior: _toDoubleOrNull(json['quantidade_anterior']),
        quantidadeNova: _toDoubleOrNull(json['quantidade_nova']),
        usuario: (json['usuario'] ?? '?') as String,
        createdAt:
            DateTime.tryParse(json['created_at']?.toString() ?? '')?.toLocal() ??
                DateTime.now(),
      );

  Color get cor => switch (acao) {
        Acoes.criou || Acoes.importou => const Color(AppConstants.corVerde),
        Acoes.removeu => const Color(AppConstants.corVermelho),
        Acoes.editou => const Color(AppConstants.corAzul),
        _ => const Color(AppConstants.corAmarelo),
      };

  String get emoji => switch (acao) {
        Acoes.criou => '➕',
        Acoes.importou => '🧾',
        Acoes.removeu => '🗑️',
        Acoes.editou => '✏️',
        _ => '🔄',
      };

  String get acaoTexto => switch (acao) {
        Acoes.criou => 'adicionou',
        Acoes.importou => 'importou da nota',
        Acoes.removeu => 'removeu',
        Acoes.editou => 'editou',
        Acoes.ajustou => 'ajustou',
        _ => acao,
      };

  /// "2 → 5 kg" quando houve mudança de quantidade.
  String? get detalheQuantidade {
    if (quantidadeNova == null) return null;
    final nova = ItemModel.formatarNumero(quantidadeNova!);
    if (quantidadeAnterior == null) return nova;
    final antes = ItemModel.formatarNumero(quantidadeAnterior!);
    if (antes == nova) return null;
    return '$antes → $nova';
  }
}
