/// Execution stages of a deal, in strict order (since v3.0):
///   1. signed      — Подписание
///   2. prepayment  — Предоплата
///   3. loading     — Загрузка
///   4. payment     — Оплата (100 % payment received from the buyer)
///   5. closed      — Закрыт
///
/// Stage names used by v1–v2.1 are mapped on read (see [fromName]); the
/// original name is preserved in [StageEvent.legacyName] so the deal history
/// still shows what was recorded at the time.
enum ContractStage {
  signed,
  prepayment,
  loading,
  payment,
  closed;

  /// Old (v1–v2.1) stage names → new stage.
  ///   factoryPaymentCny («Оплата заводу в CNY») → prepayment
  ///   inTransit         («В пути»)              → loading
  static const legacyMap = {
    'factoryPaymentCny': ContractStage.prepayment,
    'inTransit': ContractStage.loading,
  };

  static ContractStage fromName(String? name) =>
      legacyMap[name] ??
      ContractStage.values.firstWhere(
        (s) => s.name == name,
        orElse: () => ContractStage.signed,
      );

  static bool isLegacyName(String? name) => legacyMap.containsKey(name);

  bool get isClosed => this == ContractStage.closed;

  ContractStage? get next => index + 1 < ContractStage.values.length
      ? ContractStage.values[index + 1]
      : null;
}

/// One entry of the stage history: which stage was reached, when and by whom.
class StageEvent {
  const StageEvent({
    required this.stage,
    required this.at,
    this.legacyName,
    this.by = '',
  });

  final ContractStage stage;
  final DateTime at;

  /// Original stage name for events recorded before v3.0
  /// (`factoryPaymentCny`, `inTransit`); null for new events.
  final String? legacyName;

  /// Display name of the user who changed the stage.
  final String by;

  Map<String, dynamic> toJson() => {
    'stage': stage.name,
    'at': at.toIso8601String(),
    if (legacyName != null) 'legacy': legacyName,
    if (by.isNotEmpty) 'by': by,
  };

  static StageEvent? fromJson(Map<dynamic, dynamic> j) {
    final at = DateTime.tryParse(j['at'] as String? ?? '');
    if (at == null) return null;
    return StageEvent(
      stage: ContractStage.fromName(j['stage'] as String?),
      at: at,
      legacyName: j['legacy'] as String?,
      by: j['by'] as String? ?? '',
    );
  }
}
