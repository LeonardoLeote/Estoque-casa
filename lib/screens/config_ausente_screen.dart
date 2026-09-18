import 'package:flutter/material.dart';
import '../constants.dart';

/// Mostrada quando o APK foi compilado sem as chaves do Supabase.
class ConfigAusenteScreen extends StatelessWidget {
  const ConfigAusenteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(AppConstants.corVermelho),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🔑', style: TextStyle(fontSize: 64)),
                const SizedBox(height: 20),
                const Text(
                  'Configuração faltando',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Este APK foi compilado sem SUPABASE_URL e SUPABASE_ANON_KEY.\n\n'
                  'Gere o APK com:\n'
                  'flutter build apk --release \\\n'
                  '  --dart-define-from-file=env.json',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
