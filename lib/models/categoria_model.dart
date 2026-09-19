import '../constants.dart';

/// Categoria com seu próprio conjunto de ícones, editável pelo app.
///
/// Vive no Supabase, não no aparelho: categoria criada num celular precisa
/// aparecer no outro.
class CategoriaModel {
  final String nome;
  final String emoji;
  final List<String> emojis;
  final int ordem;

  const CategoriaModel({
    required this.nome,
    required this.emoji,
    required this.emojis,
    this.ordem = 100,
  });

  factory CategoriaModel.fromJson(Map<String, dynamic> json) {
    final brutos = json['emojis'];
    final lista = brutos is List
        ? brutos.map((e) => e.toString()).where((e) => e.isNotEmpty).toList()
        : <String>[];
    return CategoriaModel(
      nome: (json['nome'] ?? '') as String,
      emoji: (json['emoji'] ?? '📦') as String,
      emojis: lista.isEmpty ? ['📦'] : lista,
      ordem: (json['ordem'] as num?)?.toInt() ?? 100,
    );
  }

  Map<String, dynamic> toSupabase() => {
        'nome': nome,
        'emoji': emoji,
        'emojis': emojis,
        'ordem': ordem,
      };

  CategoriaModel copyWith({
    String? nome,
    String? emoji,
    List<String>? emojis,
    int? ordem,
  }) =>
      CategoriaModel(
        nome: nome ?? this.nome,
        emoji: emoji ?? this.emoji,
        emojis: emojis ?? this.emojis,
        ordem: ordem ?? this.ordem,
      );

  /// Usadas quando a tabela `categorias` ainda não existe no banco — o app
  /// precisa abrir e funcionar mesmo sem a migração 002.
  static List<CategoriaModel> get padrao => [
        for (final entrada in AppConstants.categoriaEmojis.entries)
          CategoriaModel(
            nome: entrada.key,
            emoji: entrada.value.first,
            emojis: entrada.value,
          ),
      ];
}
