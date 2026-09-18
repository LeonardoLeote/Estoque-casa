import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/item_model.dart';

/// Notificações locais de estoque baixo/faltando.
///
/// O realtime do Supabase dispara a cada alteração de qualquer pessoa da casa.
/// Notificar em todas elas viraria spam, então só notificamos quando o
/// *conjunto* de itens em falta muda de verdade.
class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static const _kAssinatura = 'notif_ultima_assinatura';
  static bool _inicializado = false;

  static Future<void> init() async {
    if (_inicializado) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(
      settings: const InitializationSettings(android: android),
    );
    _inicializado = true;
  }

  /// Pede a permissão de notificação (obrigatório no Android 13+).
  /// Sem isso o `show()` é engolido em silêncio.
  static Future<bool> pedirPermissao() async {
    if (!Platform.isAndroid) return true;
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    return await android?.requestNotificationsPermission() ?? false;
  }

  static Future<void> checkAndNotify(List<ItemModel> itens) async {
    if (!_inicializado) return;

    final vazios = itens.where((i) => i.status == ItemStatus.vazio).toList()
      ..sort((a, b) => a.nome.compareTo(b.nome));
    final baixos = itens.where((i) => i.status == ItemStatus.baixo).toList()
      ..sort((a, b) => a.nome.compareTo(b.nome));

    final assinatura =
        'v:${vazios.map((e) => e.id).join(",")}|b:${baixos.map((e) => e.id).join(",")}';

    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(_kAssinatura) == assinatura) return;
    await prefs.setString(_kAssinatura, assinatura);

    if (vazios.isEmpty) {
      await _plugin.cancel(id: 1);
    } else {
      await _mostrar(
        id: 1,
        canalId: 'estoque_vazio',
        canalNome: 'Itens faltando',
        titulo: '🔴 Acabou em casa',
        corpo: _resumir(vazios),
        importancia: Importance.high,
        prioridade: Priority.high,
      );
    }

    if (baixos.isEmpty) {
      await _plugin.cancel(id: 2);
    } else {
      await _mostrar(
        id: 2,
        canalId: 'estoque_baixo',
        canalNome: 'Estoque baixo',
        titulo: '⚠️ Está acabando',
        corpo: _resumir(baixos),
        importancia: Importance.defaultImportance,
        prioridade: Priority.defaultPriority,
      );
    }
  }

  static Future<void> _mostrar({
    required int id,
    required String canalId,
    required String canalNome,
    required String titulo,
    required String corpo,
    required Importance importancia,
    required Priority prioridade,
  }) async {
    await _plugin.show(
      id: id,
      title: titulo,
      body: corpo,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          canalId,
          canalNome,
          importance: importancia,
          priority: prioridade,
          styleInformation: BigTextStyleInformation(corpo),
        ),
      ),
    );
  }

  /// Lista até 5 nomes e resume o resto, para a notificação não virar parede.
  static String _resumir(List<ItemModel> itens) {
    final nomes = itens.map((e) => e.nome).toList();
    if (nomes.length <= 5) return nomes.join(', ');
    final restantes = nomes.length - 5;
    return '${nomes.take(5).join(', ')} e mais $restantes';
  }
}
