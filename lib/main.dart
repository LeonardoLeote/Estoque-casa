import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'constants.dart';
import 'screens/config_ausente_screen.dart';
import 'screens/home_screen.dart';
import 'screens/setup_screen.dart';
import 'services/notification_service.dart';
import 'services/user_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Datas em pt-BR no histórico.
  await initializeDateFormatting('pt_BR');

  // Sem as chaves o app não tem o que fazer: mostra uma tela explicando,
  // em vez de crashar no Supabase.initialize.
  if (!AppConstants.supabaseConfigurado) {
    runApp(const EstoqueCasaApp(destino: ConfigAusenteScreen()));
    return;
  }

  await Supabase.initialize(
    url: AppConstants.supabaseUrl,
    // O pacote renomeou `anonKey` para `publishableKey`; o valor é o mesmo.
    publishableKey: AppConstants.supabaseAnonKey,
  );

  await NotificationService.init();
  await UserService.carregar();
  final configurado = await UserService.configurado();

  runApp(EstoqueCasaApp(
    destino: configurado ? const HomeScreen() : const SetupScreen(),
  ));
}

class EstoqueCasaApp extends StatelessWidget {
  final Widget destino;
  const EstoqueCasaApp({super.key, required this.destino});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Estoque Casa',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(AppConstants.corVerde),
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF6F7F5),
        snackBarTheme: const SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
        ),
      ),
      home: destino,
    );
  }
}

/// SnackBars padronizados — usados por todas as telas.
extension AvisosContext on BuildContext {
  void avisoErro(String mensagem) => _mostrar(
        mensagem,
        const Color(AppConstants.corVermelho),
        Icons.error_outline,
      );

  void avisoSucesso(String mensagem) => _mostrar(
        mensagem,
        const Color(AppConstants.corVerde),
        Icons.check_circle_outline,
      );

  void avisoInfo(String mensagem) => _mostrar(
        mensagem,
        const Color(AppConstants.corAzul),
        Icons.info_outline,
      );

  void _mostrar(String mensagem, Color cor, IconData icone) {
    final messenger = ScaffoldMessenger.maybeOf(this);
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: cor,
          duration: const Duration(seconds: 3),
          content: Row(
            children: [
              Icon(icone, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  mensagem,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
  }
}
