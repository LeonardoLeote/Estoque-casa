/// Configuração do app.
///
/// As chaves NÃO ficam no código: são injetadas no build com
/// `--dart-define-from-file=env.json` (veja `env.example.json`).
/// Este repositório é público — nunca faça commit de `env.json`.
class AppConstants {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const geminiApiKey = String.fromEnvironment('GEMINI_API_KEY');

  /// Modelo do Gemini usado na leitura da nota fiscal.
  /// `gemini-1.5-flash` foi descontinuado; `gemini-flash-latest` aponta
  /// sempre para o flash estável mais recente.
  static const geminiModel = String.fromEnvironment(
    'GEMINI_MODEL',
    defaultValue: 'gemini-flash-latest',
  );

  static bool get supabaseConfigurado =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  static bool get geminiConfigurado => geminiApiKey.isNotEmpty;

  /// Categorias reais dos itens (sem o pseudo-filtro "Todos").
  static const categorias = [
    'Hortifruti',
    'Carnes',
    'Laticínios',
    'Grãos',
    'Bebidas',
    'Limpeza',
  ];

  /// Categorias exibidas na barra de filtro da home.
  static const categoriasFiltro = ['Todos', ...categorias];

  static const unidades = ['kg', 'g', 'ml', 'L', 'un', 'cx'];

  static const categoriaEmojis = <String, List<String>>{
    'Hortifruti': ['🥬', '🥕', '🍅', '🥑', '🍌', '🍎', '🥦', '🧅', '🌽', '🍇', '🍊', '🥒'],
    'Carnes': ['🥩', '🍗', '🐟', '🥚', '🦐', '🥓'],
    'Laticínios': ['🥛', '🧀', '🧈', '🍦'],
    'Grãos': ['🌾', '🫘', '🍚', '🌰', '🥜'],
    'Bebidas': ['💧', '🧃', '☕', '🍵', '🥤'],
    'Limpeza': ['🧴', '🧹', '🧽', '🪣', '🧼', '🫧'],
  };

  static List<String> emojisDaCategoria(String categoria) =>
      categoriaEmojis[categoria] ?? const ['📦'];

  static const corVerde = 0xFF2D9E6B;
  static const corAmarelo = 0xFFF5A623;
  static const corVermelho = 0xFFE74C3C;
  static const corAzul = 0xFF3B82F6;
}

/// Ações registradas no histórico.
class Acoes {
  static const criou = 'criou';
  static const editou = 'editou';
  static const removeu = 'removeu';
  static const ajustou = 'ajustou';
  static const importou = 'importou';
}
