import 'package:flutter/material.dart';
import '../constants.dart';

enum ItemStatus { ok, baixo, vazio }

class ItemModel {
  final String id;
  final String nome;
  final String categoria;
  final double quantidade;
  final String unidade;
  final double minimo;
  final String emoji;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ItemModel({
    required this.id,
    required this.nome,
    required this.categoria,
    required this.quantidade,
    required this.unidade,
    required this.minimo,
    required this.emoji,
    required this.createdAt,
    required this.updatedAt,
  });

  static double _toDouble(Object? v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0;
    return 0;
  }

  static DateTime _toDate(Object? v) =>
      DateTime.tryParse(v?.toString() ?? '')?.toLocal() ?? DateTime.now();

  factory ItemModel.fromJson(Map<String, dynamic> json) => ItemModel(
        id: json['id'].toString(),
        nome: (json['nome'] ?? '') as String,
        categoria: (json['categoria'] ?? 'Grãos') as String,
        quantidade: _toDouble(json['quantidade']),
        unidade: (json['unidade'] ?? 'un') as String,
        minimo: _toDouble(json['minimo']),
        emoji: (json['emoji'] ?? '📦') as String,
        createdAt: _toDate(json['created_at']),
        updatedAt: _toDate(json['updated_at']),
      );

  /// Payload para insert/update no Supabase (sem `id`, sem `created_at`).
  Map<String, dynamic> toSupabase() => {
        'nome': nome,
        'categoria': categoria,
        'quantidade': quantidade,
        'unidade': unidade,
        'minimo': minimo,
        'emoji': emoji,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };

  /// Payload completo para o cache local.
  Map<String, dynamic> toCache() => {
        'id': id,
        'nome': nome,
        'categoria': categoria,
        'quantidade': quantidade,
        'unidade': unidade,
        'minimo': minimo,
        'emoji': emoji,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  ItemModel copyWith({
    String? nome,
    String? categoria,
    double? quantidade,
    String? unidade,
    double? minimo,
    String? emoji,
  }) =>
      ItemModel(
        id: id,
        nome: nome ?? this.nome,
        categoria: categoria ?? this.categoria,
        quantidade: quantidade ?? this.quantidade,
        unidade: unidade ?? this.unidade,
        minimo: minimo ?? this.minimo,
        emoji: emoji ?? this.emoji,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
      );

  ItemStatus get status {
    if (quantidade <= 0) return ItemStatus.vazio;
    if (minimo > 0 && quantidade <= minimo) return ItemStatus.baixo;
    return ItemStatus.ok;
  }

  /// Rótulo cru, mantido por compatibilidade com a lista de compras.
  String get statusLabel => switch (status) {
        ItemStatus.vazio => 'empty',
        ItemStatus.baixo => 'low',
        ItemStatus.ok => 'ok',
      };

  String get statusTexto => switch (status) {
        ItemStatus.vazio => 'Faltando',
        ItemStatus.baixo => 'Baixo',
        ItemStatus.ok => 'OK',
      };

  Color get statusCor => switch (status) {
        ItemStatus.vazio => const Color(AppConstants.corVermelho),
        ItemStatus.baixo => const Color(AppConstants.corAmarelo),
        ItemStatus.ok => const Color(AppConstants.corVerde),
      };

  bool get precisaComprar => status != ItemStatus.ok;

  /// "1,5 kg" — sem casa decimal quando o número é inteiro.
  String get quantidadeFormatada => '${formatarNumero(quantidade)} $unidade';

  static String formatarNumero(double v) {
    if (v == v.roundToDouble()) return v.round().toString();
    return v.toStringAsFixed(2).replaceAll('.', ',');
  }
}
