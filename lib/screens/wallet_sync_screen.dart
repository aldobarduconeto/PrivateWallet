import 'dart:ui' as ui;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../models/wallet_account.dart';
import '../services/system/device_info_service.dart';
import '../services/wallet_sync_service.dart';
import '../widgets/qr_reader.dart';

class WalletExportDialog extends StatefulWidget {
  /// Inicializa [WalletExportDialog] com os dados recebidos.
  const WalletExportDialog({
    super.key,
    required this.account,
    this.accounts = const [],
    this.initialIsMirror = false,
    this.initialTargetDevice,
  });

  final WalletAccount account;
  final List<WalletAccount> accounts;
  final bool initialIsMirror;
  final ImportRequestData? initialTargetDevice;

  /// Cria o estado local associado ao widget.
  @override
  State<WalletExportDialog> createState() => _WalletExportDialogState();
}

class _WalletExportDialogState extends State<WalletExportDialog> {
  final _imageKey = GlobalKey();
  bool _showCode = false;
  bool _saving = false;
  bool _generating = true;
  int _packageGeneration = 0;
  String? _notice;
  ImportRequestData? _targetDevice;

  late bool _isMirror;
  late bool _exportAll;

  String _qr = '';
  String _code = '';

  /// Prepara o estado e inicia o carregamento necessário ao montar o widget.
  @override
  void initState() {
    super.initState();
    _targetDevice = widget.initialTargetDevice;
    _isMirror = widget.initialTargetDevice?.isMirror ?? widget.initialIsMirror;
    _exportAll = false;
    _generatePackage();
  }

  /// Gera o pacote de transferência para exibir ou compartilhar.
  Future<void> _generatePackage() async {
    final generation = ++_packageGeneration;
    setState(() {
      _generating = true;
      _qr = '';
      _code = '';
      _showCode = false;
      _notice = null;
    });
    try {
      final list = _isMirror && _exportAll && widget.accounts.isNotEmpty
          ? widget.accounts
          : [widget.account];
      final res = await exportWallets(accounts: list, isMirror: _isMirror);
      if (mounted && generation == _packageGeneration) {
        setState(() {
          _qr = res.qr;
          _code = res.code;
          _generating = false;
        });
      }
    } on Exception catch (error) {
      if (mounted && generation == _packageGeneration) {
        setState(() {
          _notice = error is FormatException
              ? error.message
              : 'Erro ao gerar dados de transferência.';
          _generating = false;
        });
      }
    }
  }

  /// Salva o código QR.
  Future<void> _saveQr() async {
    setState(() => _saving = true);
    try {
      final location = await getSaveLocation(
        suggestedName: _isMirror
            ? 'private-wallet-mirror-qr.png'
            : 'private-wallet-import-qr.png',
        acceptedTypeGroups: const [
          XTypeGroup(label: 'PNG', extensions: ['png']),
        ],
      );
      if (location == null || !mounted) return;
      final boundary =
          _imageKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      final rendered = await boundary.toImage(pixelRatio: 3);
      try {
        final bytes = await rendered.toByteData(format: ui.ImageByteFormat.png);
        if (bytes == null) throw const FormatException();
        await XFile.fromData(
          bytes.buffer.asUint8List(),
          mimeType: 'image/png',
        ).saveTo(location.path);
        if (mounted) setState(() => _notice = 'Imagem criptografada salva.');
      } finally {
        rendered.dispose();
      }
    } on Exception {
      if (mounted) {
        setState(() => _notice = 'Não foi possível salvar a imagem.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Escaneia do destinatário.
  Future<void> _scanReceiver() async {
    final qr = await scanQr(
      context,
      title: 'Escanear dispositivo receptor',
      accepts: (value) => value.startsWith(importRequestPrefix),
    );
    if (qr != null && mounted) {
      await _processReceiverQr(qr);
    }
  }

  /// Abre a seleção de `receiver image` no fluxo de transferência por QR.
  Future<void> _chooseReceiverImage() async {
    try {
      final qr = await readQrImage();
      if (qr != null && mounted) {
        await _processReceiverQr(qr);
      }
    } on FormatException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível ler a imagem do QR.')),
        );
      }
    }
  }

  /// Processa o QR do destinatário.
  Future<void> _processReceiverQr(String qr) async {
    final data = ImportRequestData.tryParse(qr);
    if (data == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Este QR code não é uma solicitação válida de importação/espelhamento.',
            ),
          ),
        );
      }
      return;
    }

    final isMobile =
        data.platform.toLowerCase().contains('android') ||
        data.platform.toLowerCase().contains('ios');

    final receiverRequestsMirror = data.isMirror;

    final approved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(
          isMobile ? Icons.smartphone : Icons.computer,
          size: 48,
          color: Theme.of(ctx).colorScheme.primary,
        ),
        title: const Text('Confirmar dispositivo que vai receber'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'O seguinte dispositivo solicitou conexão com este Host:',
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(ctx).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(ctx).colorScheme.outlineVariant,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isMobile ? Icons.devices : Icons.laptop_mac,
                    size: 32,
                    color: Theme.of(ctx).colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data.deviceName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Sistema: ${data.platform}${data.model != null ? ' (${data.model})' : ''}',
                          style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: receiverRequestsMirror
                                ? Colors.blue.withValues(alpha: 0.15)
                                : Colors.amber.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            receiverRequestsMirror
                                ? 'Modo Solicitado: Espelhar Contas (Watch-Only)'
                                : 'Modo Solicitado: Importar Carteira (Chave Completa)',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: receiverRequestsMirror
                                  ? Colors.blue.shade700
                                  : Colors.amber.shade900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              receiverRequestsMirror
                  ? 'Você autoriza espelhar suas contas para ${data.deviceName} em modo observador (sem chaves)?'
                  : 'Você autoriza transferir a chave privada da carteira "${widget.account.name}" para este dispositivo?',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Recusar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirmar Dispositivo'),
          ),
        ],
      ),
    );

    if (approved == true && mounted) {
      setState(() {
        _targetDevice = data;
        _isMirror = receiverRequestsMirror;
        _exportAll = false;
        _notice = 'Transferência autorizada para ${data.deviceName}.';
      });
      await _generatePackage();
    }
  }

  /// Monta a interface a partir do estado atual e do tema do contexto.
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return AlertDialog(
      title: Text(
        _showCode
            ? 'Código de transferência'
            : (_isMirror ? 'Espelhar contas' : 'Importar carteira'),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ==========================================
            // SELETOR: IMPORTAR vs ESPELHAR
            // ==========================================
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: false,
                  label: Text('Hot (com chaves)'),
                  icon: Icon(Icons.download_rounded, size: 18),
                ),
                ButtonSegment(
                  value: true,
                  label: Text('Cold (observação)'),
                  icon: Icon(Icons.copy_all_rounded, size: 18),
                ),
              ],
              selected: {_isMirror},
              onSelectionChanged: (selected) {
                setState(() {
                  _isMirror = selected.first;
                  _exportAll = false;
                });
                _generatePackage();
              },
            ),
            const SizedBox(height: 12),

            if (_isMirror && widget.accounts.length > 1) ...[
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(
                  'Espelhar todas as contas (${widget.accounts.length})',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: const Text(
                  'Transfere a lista completa de contas para o outro aparelho.',
                  style: TextStyle(fontSize: 11),
                ),
                value: _exportAll,
                onChanged: (val) {
                  setState(() => _exportAll = val);
                  _generatePackage();
                },
              ),
              const SizedBox(height: 8),
            ],

            if (_targetDevice case final target?) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.green.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Destino: ${target.deviceName} (${target.platform})',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: OutlinedButton.icon(
                  onPressed: _saving
                      ? null
                      : (hasMobileScanner
                            ? _scanReceiver
                            : _chooseReceiverImage),
                  icon: const Icon(Icons.qr_code_scanner, size: 18),
                  label: const Text('Escanear QR do dispositivo receptor'),
                ),
              ),
            ],

            if (_showCode) ...[
              Text(
                _isMirror
                    ? 'Digite este código no dispositivo receptor para concluir o espelhamento das contas.'
                    : 'Digite este código no dispositivo receptor para importar a carteira.',
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(
                  _code,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
            ] else ...[
              Text(
                _isMirror
                    ? 'Modo Espelho: As contas serão enviadas em modo observador (watch-only). Sem chaves privadas no receptor, garantindo segurança total.'
                    : 'Modo Importar: A carteira "${widget.account.name}" será enviada com sua chave privada para permitir envio de transações.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
              ),
              const SizedBox(height: 14),

              if (_generating)
                const SizedBox(
                  height: 240,
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                Center(
                  child: RepaintBoundary(
                    key: _imageKey,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: QrImageView(
                        data: _qr,
                        size: 230,
                        backgroundColor: Colors.white,
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                ),

              const SizedBox(height: 8),
              if (!hasMobileScanner)
                Center(
                  child: TextButton.icon(
                    onPressed: _saving ? null : _saveQr,
                    icon: const Icon(Icons.save_alt, size: 18),
                    label: const Text('Salvar imagem do QR'),
                  ),
                ),
              if (_notice case final notice?)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    notice,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: colors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Fechar'),
        ),
        FilledButton(
          onPressed: (_saving || _generating)
              ? null
              : () => setState(() => _showCode = !_showCode),
          child: Text(_showCode ? 'Voltar ao QR' : 'Mostrar código'),
        ),
      ],
    );
  }
}

class WalletImportPage extends StatefulWidget {
  /// Inicializa [WalletImportPage] com os dados recebidos.
  const WalletImportPage({super.key, this.initialMirror = false});

  final bool initialMirror;

  /// Cria o estado local associado ao widget.
  @override
  State<WalletImportPage> createState() => _WalletImportPageState();
}

class _WalletImportPageState extends State<WalletImportPage> {
  final _code = TextEditingController();
  final _qrKey = GlobalKey();

  DeviceInfoData? _deviceInfo;
  String? _receiveQr;
  bool _loadingDevice = true;
  late bool _isMirror;

  String? _qr;
  String? _error;
  bool _working = false;

  /// Prepara o estado e inicia o carregamento necessário ao montar o widget.
  @override
  void initState() {
    super.initState();
    _isMirror = widget.initialMirror;
    _initReceiverInfo();
  }

  /// Libera os recursos mantidos pela instância.
  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  /// Inicializa os dados do destinatário.
  Future<void> _initReceiverInfo() async {
    try {
      final info = await DeviceInfoService.getDevice();
      if (!mounted) return;
      _deviceInfo = info;
      _loadingDevice = false;
      _updateReceiverQr();
    } catch (_) {
      if (mounted) {
        setState(() => _loadingDevice = false);
      }
    }
  }

  /// Atualiza o QR com os dados atuais do destinatário.
  void _updateReceiverQr() {
    if (_deviceInfo == null) return;
    final payload = ImportRequestData(
      deviceName: _deviceInfo!.name,
      platform: _deviceInfo!.platform,
      model: _deviceInfo!.model,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      mode: _isMirror ? 'mirror' : 'import',
    );
    setState(() {
      _receiveQr = payload.toQrString();
    });
  }

  /// Abre a seleção de a imagem.
  Future<void> _chooseImage() async {
    await _perform(() async {
      final qr = await readQrImage();
      if (mounted && qr != null) _setQr(qr);
    });
  }

  /// Abre o leitor de códigos QR.
  Future<void> _scan() async {
    final qr = await scanQr(
      context,
      title: 'Ler QR gerado pelo Host',
      accepts: (value) => value.startsWith(syncPrefix),
    );
    if (mounted && qr != null) _setQr(qr);
  }

  /// Define o código QR.
  void _setQr(String qr) => setState(() {
    _qr = qr.startsWith(syncPrefix) && qr.length <= maxSyncQrLength ? qr : null;
    _error = _qr == null
        ? 'Este QR code não é uma transferência válida de carteira.'
        : null;
    _code.clear();
  });

  /// Executa a operação de transferência e apresenta o resultado.
  Future<void> _perform(Future<void> Function() action) async {
    if (_working) return;
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      await action();
    } on FormatException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } on Exception {
      if (mounted) {
        setState(() => _error = 'Não foi possível concluir a operação.');
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  /// Abre o fluxo de restauração.
  Future<void> _restore() => _perform(() async {
    final result = await importWalletsSync(
      _qr!,
      _code.text,
      expectedMirror: _isMirror,
    );
    if (!mounted) return;

    final isMirror = result.isMirror;
    final accounts = result.accounts;

    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(
          isMirror ? Icons.copy_all_rounded : Icons.account_balance_wallet,
          size: 40,
          color: Theme.of(context).colorScheme.primary,
        ),
        title: Text(
          isMirror
              ? 'Confirmar Espelhamento de Contas'
              : 'Confirmar Carteira Importada',
        ),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isMirror
                    ? 'As seguintes ${accounts.length} contas serão espelhadas em modo observador (watch-only):'
                    : 'A seguinte carteira será importada com chaves privadas:',
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 220),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: accounts.length,
                  separatorBuilder: (_, _) => const Divider(height: 12),
                  itemBuilder: (context, i) {
                    final acc = accounts[i];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      leading: CircleAvatar(
                        radius: 16,
                        child: Text(
                          acc.symbol.substring(0, 1),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(
                        acc.name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        acc.publicAddress,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              if (isMirror)
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, size: 18, color: Colors.blue),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Modo Espelho: Não possui chaves privadas neste aparelho (somente leitura seguro).',
                          style: TextStyle(fontSize: 11, color: Colors.blue),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(isMirror ? 'Espelhar Contas' : 'Importar Carteira'),
          ),
        ],
      ),
    );

    if (mounted && approved == true) {
      Navigator.pop(context, result);
    }
  });

  /// Monta a interface a partir do estado atual e do tema do contexto.
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isMobile =
        _deviceInfo?.platform.toLowerCase().contains('android') == true ||
        _deviceInfo?.platform.toLowerCase().contains('ios') == true;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isMirror ? 'Espelhar Contas' : 'Importar Carteira'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ==========================================
                // SELETOR: IMPORTAR vs ESPELHAR
                // ==========================================
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(
                      value: false,
                      label: Text('Hot (com chaves)'),
                      icon: Icon(Icons.download_rounded),
                    ),
                    ButtonSegment(
                      value: true,
                      label: Text('Cold (observação)'),
                      icon: Icon(Icons.copy_all_rounded),
                    ),
                  ],
                  selected: {_isMirror},
                  onSelectionChanged: (selected) {
                    setState(() {
                      _isMirror = selected.first;
                    });
                    _updateReceiverQr();
                  },
                ),
                const SizedBox(height: 20),

                if (_loadingDevice)
                  const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_receiveQr != null) ...[
                  // ==========================================
                  // QR CODE CENTRALIZADO COM DADOS DO DISPOSITIVO
                  // ==========================================
                  Text(
                    _isMirror
                        ? 'QR de Espelhamento do Dispositivo'
                        : 'QR de Importação do Dispositivo',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: colors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _isMirror
                        ? 'No dispositivo cold, abra Sincronizar por QR e selecione Cold (observação). Neste dispositivo você poderá receber e acompanhar os fundos.'
                        : 'Aponte o dispositivo Host para transferir a carteira com chaves de envio.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 18),

                  Center(
                    child: RepaintBoundary(
                      key: _qrKey,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.grey.shade300,
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 18,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: QrImageView(
                          data: _receiveQr!,
                          size: 220,
                          backgroundColor: Colors.white,
                          padding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Informações do Dispositivo Receptor
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerHighest.withValues(
                        alpha: 0.6,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: colors.outlineVariant.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isMobile ? Icons.smartphone : Icons.computer,
                          size: 28,
                          color: colors.primary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Dispositivo receptor: ${_deviceInfo?.name ?? "Este aparelho"}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Sistema: ${_deviceInfo?.platform ?? "Desconhecido"}${_deviceInfo?.model != null ? ' (${_deviceInfo!.model})' : ''}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _isMirror
                                    ? 'Modo: Espelhamento (sem chaves privadas)'
                                    : 'Modo: Importação completa (com chaves)',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: _isMirror
                                      ? Colors.blue.shade700
                                      : Colors.amber.shade900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 14),

                // ==========================================
                // ETAPA SEGUINTE: LER O QR GERADO PELO HOST
                // ==========================================
                Text(
                  'Após autorizar no Host:',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: colors.primary,
                  ),
                ),
                const SizedBox(height: 10),

                if (hasMobileScanner)
                  FilledButton.icon(
                    onPressed: _working ? null : _scan,
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text('Ler QR gerado pelo Host'),
                  ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _working ? null : _chooseImage,
                  icon: const Icon(Icons.image_outlined),
                  label: const Text('Carregar imagem do QR do Host'),
                ),

                if (_qr != null) ...[
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Colors.green.withValues(alpha: 0.3),
                      ),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green, size: 20),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'QR do Host lido! Digite o código exibido no Host:',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _code,
                    obscureText: true,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: const InputDecoration(
                      labelText: 'Código de transferência',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _working ? null : _restore,
                    icon: const Icon(Icons.download_done),
                    label: Text(
                      _isMirror
                          ? 'Verificar e Espelhar Contas'
                          : 'Verificar e Importar Carteira',
                    ),
                  ),
                ],

                if (_working) ...[
                  const SizedBox(height: 16),
                  const LinearProgressIndicator(),
                ],

                if (_error case final message?) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colors.errorContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      message,
                      style: TextStyle(color: colors.onErrorContainer),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
