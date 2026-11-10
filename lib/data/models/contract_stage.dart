/// Execution stages of a back-to-back deal, in strict order.
enum ContractStage {
  signed,
  prepayment,
  factoryPaymentCny,
  inTransit,
  closed;

  static ContractStage fromName(String? name) => ContractStage.values
      .firstWhere((s) => s.name == name, orElse: () => ContractStage.signed);

  bool get isClosed => this == ContractStage.closed;

  ContractStage? get next => index + 1 < ContractStage.values.length
      ? ContractStage.values[index + 1]
      : null;
}
