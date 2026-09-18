import 'package:shared_preferences/shared_preferences.dart';

/// Nome de quem está usando o celular — usado para assinar o histórico.
class UserService {
  static const _kNome = 'usuario_nome';
  static String _nome = '?';

  /// Nome em memória, já carregado. Use depois de [carregar].
  static String get nome => _nome;

  static Future<String> carregar() async {
    final prefs = await SharedPreferences.getInstance();
    _nome = prefs.getString(_kNome) ?? '?';
    return _nome;
  }

  static Future<void> salvar(String nome) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kNome, nome);
    _nome = nome;
  }

  static Future<bool> configurado() async {
    final prefs = await SharedPreferences.getInstance();
    final n = prefs.getString(_kNome);
    return n != null && n.trim().isNotEmpty;
  }
}
