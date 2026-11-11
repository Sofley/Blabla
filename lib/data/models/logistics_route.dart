/// Transport mode of a logistics route.
enum TransportMode {
  sea,
  rail,
  road,
  air,
  multimodal;

  static TransportMode fromName(String? n) =>
      TransportMode.values.firstWhere((m) => m.name == n, orElse: () => sea);
}

/// One line of the logistics tariff grid (prices in USD).
class LogisticsRoute {
  const LogisticsRoute({
    required this.id,
    required this.origin,
    required this.destination,
    this.mode = TransportMode.sea,
    this.cargo = '40ft',
    this.priceMin = 0,
    this.priceMax = 0,
    this.daysMin = 0,
    this.daysMax = 0,
    this.notes = '',
    required this.updatedAt,
  });

  final String id;
  final String origin;
  final String destination;
  final TransportMode mode;

  /// Container / cargo type: 20ft, 40ft, 40HC, LCL, truck…
  final String cargo;
  final double priceMin;
  final double priceMax;
  final int daysMin;
  final int daysMax;
  final String notes;
  final DateTime updatedAt;

  /// Average of min and max (or the single given value).
  double get priceAvg {
    if (priceMin > 0 && priceMax > 0) return (priceMin + priceMax) / 2;
    return priceMax > 0 ? priceMax : priceMin;
  }

  LogisticsRoute copyWith({
    String? origin,
    String? destination,
    TransportMode? mode,
    String? cargo,
    double? priceMin,
    double? priceMax,
    int? daysMin,
    int? daysMax,
    String? notes,
    DateTime? updatedAt,
  }) => LogisticsRoute(
    id: id,
    origin: origin ?? this.origin,
    destination: destination ?? this.destination,
    mode: mode ?? this.mode,
    cargo: cargo ?? this.cargo,
    priceMin: priceMin ?? this.priceMin,
    priceMax: priceMax ?? this.priceMax,
    daysMin: daysMin ?? this.daysMin,
    daysMax: daysMax ?? this.daysMax,
    notes: notes ?? this.notes,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'origin': origin,
    'destination': destination,
    'mode': mode.name,
    'cargo': cargo,
    'priceMin': priceMin,
    'priceMax': priceMax,
    'daysMin': daysMin,
    'daysMax': daysMax,
    'notes': notes,
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory LogisticsRoute.fromJson(Map<dynamic, dynamic> j) => LogisticsRoute(
    id: j['id'] as String,
    origin: j['origin'] as String? ?? '',
    destination: j['destination'] as String? ?? '',
    mode: TransportMode.fromName(j['mode'] as String?),
    cargo: j['cargo'] as String? ?? '',
    priceMin: (j['priceMin'] as num?)?.toDouble() ?? 0,
    priceMax: (j['priceMax'] as num?)?.toDouble() ?? 0,
    daysMin: (j['daysMin'] as num?)?.toInt() ?? 0,
    daysMax: (j['daysMax'] as num?)?.toInt() ?? 0,
    notes: j['notes'] as String? ?? '',
    updatedAt:
        DateTime.tryParse(j['updatedAt'] as String? ?? '') ?? DateTime.now(),
  );
}
