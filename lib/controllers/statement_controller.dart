// ignore_for_file: prefer_initializing_formals

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/chain_movement.dart';
import '../models/wallet_activity.dart';

/// Intervalo de datas (inclusivo, em horário local) usado no extrato.
class StatementPeriod {
  /// Inicializa [StatementPeriod] com os dados recebidos.
  const StatementPeriod(this.start, this.end, this.label);

  /// Inicializa [StatementPeriod] com os dados recebidos.
  factory StatementPeriod.day(DateTime day) {
    final start = DateTime(day.year, day.month, day.day);

    /// Formata um número com pelo menos dois dígitos.
    String two(int v) => v.toString().padLeft(2, '0');
    return StatementPeriod(
      start,
      start.add(const Duration(days: 1)),
      '${two(day.day)}/${two(day.month)}/${day.year}',
    );
  }

  /// Inicializa [StatementPeriod] com os dados recebidos.
  factory StatementPeriod.lastDays(int days, {DateTime? now}) {
    final today = now ?? DateTime.now();
    final end = DateTime(today.year, today.month, today.day + 1);
    return StatementPeriod(
      end.subtract(Duration(days: days)),
      end,
      days == 1 ? 'Hoje' : 'Últimos $days dias',
    );
  }

  /// Inicializa [StatementPeriod] com os dados recebidos.
  factory StatementPeriod.range(DateTime first, DateTime last) {
    /// Formata um número com pelo menos dois dígitos.
    String two(int v) => v.toString().padLeft(2, '0');
    final start = DateTime(first.year, first.month, first.day);
    final end = DateTime(last.year, last.month, last.day + 1);
    return StatementPeriod(
      start,
      end,
      '${two(first.day)}/${two(first.month)} – ${two(last.day)}/${two(last.month)}/${last.year}',
    );
  }

  /// Início inclusivo e fim exclusivo.
  final DateTime start;
  final DateTime end;
  final String label;

  /// Verifica se a data pertence ao intervalo do extrato.
  bool contains(DateTime time) {
    final local = time.toLocal();
    return !local.isBefore(start) && local.isBefore(end);
  }
}

typedef StatementSummary = ({
  BigInt incoming,
  BigInt outgoing,
  BigInt fees,
  int count,
});

/// Estado do extrato de uma carteira/rede. Mantido pelo [WalletController]
/// para que reabrir a tela mostre os dados anteriores enquanto atualiza.
class StatementController extends ChangeNotifier {
  /// Inicializa [StatementController] com os dados recebidos.
  StatementController({
    required Future<MovementPage> Function(String? cursor) fetch,
    required Future<List<WalletActivity>> Function() localSends,
  }) : _fetch = fetch,
       _localSends = localSends;

  final Future<MovementPage> Function(String? cursor) _fetch;
  final Future<List<WalletActivity>> Function() _localSends;

  /// Limite de páginas carregadas automaticamente para cobrir um período.
  static const maxAutoPages = 8;

  List<ChainMovement> _chain = const [];
  List<ChainMovement> _local = const [];
  String? _cursor;
  bool _loading = false;
  bool _loadingMore = false;
  bool _loadedOnce = false;
  String? _error;
  DateTime? _updated;
  bool _disposed = false;

  MovementType? _type;
  String? _customTypeFilter;
  StatementPeriod? _period;

  /// Retorna `loading` para consulta em extrato.
  bool get loading => _loading;

  /// Retorna `loadingMore` para consulta em extrato.
  bool get loadingMore => _loadingMore;

  /// Retorna `loadedOnce` para consulta em extrato.
  bool get loadedOnce => _loadedOnce;

  /// Indica a condição `hasMore` usada em extrato.
  bool get hasMore => _cursor != null;

  /// Retorna `error` para consulta em extrato.
  String? get error => _error;

  /// Retorna `updated` para consulta em extrato.
  DateTime? get updated => _updated;

  /// Retorna `type` para consulta em extrato.
  MovementType? get type => _type;

  /// Retorna `customTypeFilter` para consulta em extrato.
  String? get customTypeFilter => _customTypeFilter;

  /// Retorna `period` para consulta em extrato.
  StatementPeriod? get period => _period;

  /// Envios locais só contam como pendentes por [localWindow]; depois disso
  /// o indexador é a fonte de verdade.
  static const localWindow = Duration(hours: 48);

  List<ChainMovement>? _allCache;
  List<ChainMovement>? _visibleCache;

  /// Retorna `all` para consulta em extrato.
  List<ChainMovement> get all => _allCache ??= _merge();

  /// Consolida os itens locais e os recebidos da rede.
  List<ChainMovement> _merge() {
    final localTypes = <String, String>{};
    for (final item in _local) {
      if (item.paymentType != null && item.paymentType!.trim().isNotEmpty) {
        localTypes[item.hash.toLowerCase()] = item.paymentType!.trim();
      }
    }
    final known = {for (final item in _chain) item.hash.toLowerCase()};
    final now = DateTime.now();
    final since = now.subtract(localWindow);

    final enrichedChain = [
      for (final item in _chain)
        if (item.paymentType == null &&
            localTypes.containsKey(item.hash.toLowerCase()))
          item.copyWith(paymentType: localTypes[item.hash.toLowerCase()])
        else
          item,
    ];

    final merged = [
      ..._local.where(
        (item) =>
            !known.contains(item.hash.toLowerCase()) &&
            (item.time?.isAfter(since) ?? false),
      ),
      ...enrichedChain,
    ];
    merged.sort((a, b) {
      if (a.confirmed != b.confirmed) return a.confirmed ? 1 : -1;
      final at = a.time ?? now;
      final bt = b.time ?? now;
      return bt.compareTo(at);
    });
    return merged;
  }

  /// Retorna todos os tipos/categorias personalizados existentes no histórico.
  List<String> get availablePaymentTypes {
    final types = <String>{};
    for (final item in all) {
      final pType = item.paymentType?.trim();
      if (pType != null && pType.isNotEmpty) {
        types.add(pType);
      }
    }
    final sorted = types.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return sorted;
  }

  /// Retorna `visible` para consulta em extrato.
  List<ChainMovement> get visible =>
      _visibleCache ??= List.unmodifiable(all.where(_accepts));

  /// Aplica o critério de seleção ao item recebido.
  bool _accepts(ChainMovement item) {
    if (_type != null && item.type != _type) return false;
    if (_customTypeFilter != null) {
      final itemPType = item.paymentType?.trim().toLowerCase();
      final target = _customTypeFilter!.trim().toLowerCase();
      if (itemPType != target) return false;
    }
    final period = _period;
    if (period == null) return true;
    return period.contains(item.time ?? DateTime.now());
  }

  /// Retorna o resumo em uso.
  StatementSummary get summary {
    var incoming = BigInt.zero;
    var outgoing = BigInt.zero;
    var fees = BigInt.zero;
    var count = 0;
    for (final item in visible) {
      if (item.failed) continue;
      count++;
      if (item.type == MovementType.incoming) incoming += item.amount;
      if (item.type == MovementType.outgoing) outgoing += item.amount;
      fees += item.fee ?? BigInt.zero;
    }
    return (incoming: incoming, outgoing: outgoing, fees: fees, count: count);
  }

  /// Análise financeira: soma das saídas agrupadas por categoria/tipo de pagamento.
  Map<String, BigInt> get outgoingByCategory {
    final map = <String, BigInt>{};
    for (final item in visible) {
      if (item.type == MovementType.outgoing && !item.failed) {
        final category = item.paymentType?.trim().isNotEmpty == true
            ? item.paymentType!.trim()
            : 'Outros';
        map[category] = (map[category] ?? BigInt.zero) + item.amount;
      }
    }
    return map;
  }

  /// Define `type` no fluxo de extrato.
  void setType(MovementType? type) {
    _type = type;
    _visibleCache = null;
    _notify();
  }

  /// Define `custom type filter` no fluxo de extrato.
  void setCustomTypeFilter(String? customType) {
    _customTypeFilter = customType;
    _visibleCache = null;
    _notify();
  }

  /// Define `period` no fluxo de extrato.
  Future<void> setPeriod(StatementPeriod? period) async {
    _period = period;
    _visibleCache = null;
    _notify();
    if (period != null) await _cover(period.start);
  }

  /// Recarrega a primeira página. Os dados atuais permanecem visíveis até a
  /// resposta chegar.
  Future<void> refresh() async {
    if (_disposed || _loading || _loadingMore) return;
    _loading = true;
    _error = null;
    _notify();
    try {
      final (page, local) = await (_fetch(null), _loadLocal()).wait;
      _chain = page.items;
      _cursor = page.cursor;
      _local = local;
      _invalidateData();
      _loadedOnce = true;
      _updated = DateTime.now();
      final period = _period;
      if (period != null) {
        await _cover(period.start, duringRefresh: true);
      }
    } on ParallelWaitError<
      (MovementPage?, List<ChainMovement>?),
      (AsyncError?, AsyncError?)
    > catch (failure) {
      _error = _message(failure.errors.$1?.error ?? failure.errors.$2?.error);
      if (failure.values.$2 case final local?) _local = local;
    } finally {
      _loading = false;
      _notify(dataChanged: true);
    }
  }

  /// Solicita a próxima página sem descartar as movimentações já carregadas.
  Future<void> loadMore() => _loadMore();

  Future<void> _loadMore({bool duringRefresh = false}) async {
    final cursor = _cursor;
    if (_disposed ||
        cursor == null ||
        _loadingMore ||
        (_loading && !duringRefresh)) {
      return;
    }
    _loadingMore = true;
    _notify();
    try {
      final page = await _fetch(cursor);
      final known = {for (final item in _chain) item.hash};
      _chain = [..._chain, ...page.items.where((item) => known.add(item.hash))];
      _cursor = page.cursor == cursor ? null : page.cursor;
      _error = null;
    } on Object catch (failure) {
      _error = _message(failure);
    } finally {
      _loadingMore = false;
      _notify(dataChanged: true);
    }
  }

  /// Calcula o intervalo que cobre os dados disponíveis.
  Future<void> _cover(DateTime start, {bool duringRefresh = false}) async {
    if (_disposed || _loadingMore || (_loading && !duringRefresh)) return;
    for (var i = 0; i < maxAutoPages && hasMore && _error == null; i++) {
      final times = _chain.map((item) => item.time).whereType<DateTime>();
      if (times.isNotEmpty && times.last.toLocal().isBefore(start)) return;
      await _loadMore(duringRefresh: duringRefresh);
      if (_disposed || _period?.start != start) return;
    }
  }

  /// Lê os dados armazenados no dispositivo.
  Future<List<ChainMovement>> _loadLocal() async => [
    for (final entry in await _localSends())
      ChainMovement(
        hash: entry.hash,
        type: MovementType.outgoing,
        amount: entry.amount,
        bitcoin: entry.bitcoin,
        networkId: entry.networkId,
        fee: entry.fee,
        counterparty: entry.recipient,
        time: entry.created,
        confirmed: false,
        local: true,
        paymentType: entry.paymentType ?? entry.purchaseName,
      ),
  ];

  /// Exibe uma mensagem de retorno na interface.
  static String _message(Object? failure) => failure is FormatException
      ? failure.message
      : 'Não foi possível atualizar o extrato. Puxe para tentar novamente.';

  /// Publica a mudança para os observadores.
  void _invalidateData() {
    _allCache = null;
    _visibleCache = null;
  }

  void _notify({bool dataChanged = false}) {
    if (dataChanged) _invalidateData();
    if (!_disposed) notifyListeners();
  }

  /// Libera os recursos mantidos pela instância.
  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
