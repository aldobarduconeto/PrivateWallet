enum TransactionState {
  unseen('Não localizada pelo nó'),
  pending('Pendente na rede'),
  included('Incluída em bloco'),
  reverted('Execução revertida');

  /// Inicializa a configuração de transaction state.
  const TransactionState(this.label);
  final String label;
}
