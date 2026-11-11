/// A transport / loading type for logistics "per transport unit".
class TransportType {
  const TransportType({
    required this.id,
    required this.name,
    this.capacityTonnes,
  });

  final String id;
  final String name;

  /// Load per unit in tonnes; null = not set (the number of units is then
  /// entered by hand — no capacity is assumed).
  final double? capacityTonnes;

  /// Built-in types. Trucks carry the tonnage in their name; container
  /// capacity depends on the cargo, so it is left for the user to set.
  static const defaults = [
    TransportType(id: 'cont20', name: 'Контейнер 20 футов / 20 ft container'),
    TransportType(id: 'cont40', name: 'Контейнер 40 футов / 40 ft container'),
    TransportType(
      id: 'truck22',
      name: 'Авто / Фура 22 т / Truck 22 t',
      capacityTonnes: 22,
    ),
    TransportType(
      id: 'truck25',
      name: 'Авто / Фура 25 т / Truck 25 t',
      capacityTonnes: 25,
    ),
  ];

  /// Units needed for [tonnes] (rounded up); null when capacity or weight
  /// is unknown.
  int? unitsFor(double? tonnes) {
    final cap = capacityTonnes;
    if (cap == null || cap <= 0 || tonnes == null || tonnes <= 0) return null;
    return (tonnes / cap - 1e-9).ceil();
  }

  TransportType copyWith({String? name, Object? capacityTonnes = _keep}) =>
      TransportType(
        id: id,
        name: name ?? this.name,
        capacityTonnes: identical(capacityTonnes, _keep)
            ? this.capacityTonnes
            : (capacityTonnes as num?)?.toDouble(),
      );

  static const Object _keep = Object();

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'capacity': capacityTonnes,
  };

  static TransportType? fromJson(Map<dynamic, dynamic> j) {
    final id = j['id'] as String?;
    if (id == null) return null;
    return TransportType(
      id: id,
      name: j['name'] as String? ?? id,
      capacityTonnes: (j['capacity'] as num?)?.toDouble(),
    );
  }
}
