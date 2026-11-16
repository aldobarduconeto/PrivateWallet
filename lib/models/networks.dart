import 'package:bitcoin_base/bitcoin_base.dart';

enum Network {
  sepolia(
    'Sepolia · teste',
    11155111,
    'ethereum-sepolia-rpc.publicnode.com',
    'sepolia.etherscan.io',
    'eth-sepolia.blockscout.com',
    String.fromEnvironment('ETHEREUM_SEPOLIA_RPC_URL'),
  ),
  mainnet(
    'Ethereum · rede principal',
    1,
    'ethereum-rpc.publicnode.com',
    'etherscan.io',
    'eth.blockscout.com',
    String.fromEnvironment('ETHEREUM_MAINNET_RPC_URL'),
  );

  /// Inicializa a configuração de networks.
  const Network(
    this.label,
    this.chainId,
    this.rpc,
    this.explorer,
    this.indexer,
    this._customRpc,
  );
  final String label;
  final int chainId;
  final String rpc;
  final String explorer;

  /// Indexador público (API compatível com Etherscan) usado no extrato.
  final String indexer;
  final String _customRpc;

  /// Endpoint JSON-RPC efetivo: `--dart-define` quando informado.
  Uri get rpcUri =>
      _customRpc.isEmpty ? Uri.https(rpc, '') : Uri.parse(_customRpc);

  /// URL base do explorador de blocos.
  String get explorerUrl => 'https://$explorer';
}

enum BitcoinChain {
  testnet4(
    'Bitcoin · Testnet4',
    BitcoinNetwork.testnet4,
    '/testnet4',
    '00000000da84f2bafbbc53dee25a72ae507ff4914b867c565be350b0da8bf043',
    String.fromEnvironment('BITCOIN_TESTNET4_ESPLORA_URL'),
  ),
  mainnet(
    'Bitcoin · rede principal',
    BitcoinNetwork.mainnet,
    '',
    '000000000019d6689c085ae165831e934ff763ae46a2a6c172b3f1b60a8ce26f',
    String.fromEnvironment('BITCOIN_MAINNET_ESPLORA_URL'),
  );

  /// Inicializa a configuração de networks.
  const BitcoinChain(
    this.label,
    this.network,
    this.path,
    this.genesis,
    this._customEsplora,
  );
  final String label;
  final BitcoinNetwork network;
  final String path;

  /// Hash do bloco gênese, usado para validar endpoints próprios.
  final String genesis;
  final String _customEsplora;

  /// Monta a URI da transação no explorador da rede Bitcoin.
  Uri explorer(String txid) => Uri.https('blockstream.info', '$path/tx/$txid');

  /// URL base do explorador de blocos.
  String get explorerUrl => 'https://blockstream.info$path';

  /// Endpoint Esplora próprio definido na compilação, se houver.
  Uri? get customEsplora =>
      _customEsplora.isEmpty ? null : Uri.parse(_customEsplora);

  /// Serviços Esplora públicos, em ordem de preferência. O segundo é usado
  /// como alternativa quando o primeiro falha ou demora a responder.
  List<Uri> get publicEsplora => [
    Uri.https('blockstream.info', '$path/api/'),
    Uri.https('mempool.space', '$path/api/'),
  ];
}
