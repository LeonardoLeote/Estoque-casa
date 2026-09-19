import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../constants.dart';
import '../models/item_model.dart';
import '../services/categoria_service.dart';
import '../services/local_cache.dart';
import '../services/user_service.dart';

/// Versão do app, estado da sincronização e o que está configurado.
class SobreScreen extends StatefulWidget {
  final List<ItemModel> itens;
  const SobreScreen({super.key, required this.itens});

  @override
  State<SobreScreen> createState() => _SobreScreenState();
}

class _SobreScreenState extends State<SobreScreen> {
  PackageInfo? _info;
  DateTime? _sincronizadoEm;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    // A versão vem do APK instalado, não de uma constante no código: assim
    // ela não mente quando alguém esquece de atualizar os dois lugares.
    final info = await PackageInfo.fromPlatform();
    final sync = await LocalCache.atualizadoEm();
    if (mounted) {
      setState(() {
        _info = info;
        _sincronizadoEm = sync;
      });
    }
  }

  String _dataHora(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year} às '
      '${d.hour.toString().padLeft(2, '0')}:'
      '${d.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final info = _info;
    final valorTotal = widget.itens
        .where((i) => i.valorEmEstoque != null)
        .fold(0.0, (soma, i) => soma + i.valorEmEstoque!);
    final semPreco = widget.itens.where((i) => i.preco == null).length;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(AppConstants.corVerde),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'ℹ️ Sobre',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 19),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        children: [
          Center(
            child: Column(
              children: [
                const Text('🏠', style: TextStyle(fontSize: 56)),
                const SizedBox(height: 10),
                const Text(
                  'Estoque Casa',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  info == null
                      ? 'carregando versão...'
                      : 'versão ${info.version} (build ${info.buildNumber})',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.black.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          _Secao('Este aparelho', [
            _Linha('Usuário', UserService.nome),
            _Linha(
              'Sincronizado',
              _sincronizadoEm == null
                  ? 'ainda não'
                  : _dataHora(_sincronizadoEm!),
            ),
          ]),

          _Secao('Estoque', [
            _Linha('Itens cadastrados', '${widget.itens.length}'),
            _Linha('Categorias', '${CategoriaService.categorias.length}'),
            _Linha(
              'Valor em casa',
              valorTotal > 0
                  ? ItemModel.formatarDinheiro(valorTotal)
                  : 'sem preços informados',
            ),
            if (semPreco > 0)
              _Linha('Itens sem preço', '$semPreco'),
          ]),

          _Secao('Build', [
            if (info != null) _Linha('Pacote', info.packageName),
            _Linha(
              'Commit',
              AppConstants.buildCommit.isEmpty
                  ? 'build local'
                  : AppConstants.buildCommit,
            ),
            _Linha('Modelo do Gemini', AppConstants.geminiModel),
            _Linha(
              'Leitura de nota',
              AppConstants.geminiConfigurado ? 'ativa' : 'sem chave',
            ),
          ]),

          const SizedBox(height: 20),
          Text(
            'Os dados ficam no seu projeto Supabase e são compartilhados por '
            'todos os celulares da casa.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              height: 1.5,
              color: Colors.black.withValues(alpha: 0.45),
            ),
          ),
        ],
      ),
    );
  }
}

class _Secao extends StatelessWidget {
  final String titulo;
  final List<Widget> linhas;
  const _Secao(this.titulo, this.linhas);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              titulo.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
                color: Colors.black.withValues(alpha: 0.4),
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(children: linhas),
          ),
        ],
      ),
    );
  }
}

class _Linha extends StatelessWidget {
  final String rotulo;
  final String valor;
  const _Linha(this.rotulo, this.valor);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            rotulo,
            style: TextStyle(
              fontSize: 13.5,
              color: Colors.black.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SelectableText(
              valor,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
