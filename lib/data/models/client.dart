/// A client (buyer company) from the clients directory.
class Client {
  const Client({
    required this.id,
    required this.name,
    this.contactPerson = '',
    this.phone = '',
    this.email = '',
    this.address = '',
    this.notes = '',
    required this.createdAt,
  });

  final String id;

  /// Company name.
  final String name;
  final String contactPerson;
  final String phone;
  final String email;
  final String address;
  final String notes;
  final DateTime createdAt;

  Client copyWith({
    String? name,
    String? contactPerson,
    String? phone,
    String? email,
    String? address,
    String? notes,
  }) => Client(
    id: id,
    name: name ?? this.name,
    contactPerson: contactPerson ?? this.contactPerson,
    phone: phone ?? this.phone,
    email: email ?? this.email,
    address: address ?? this.address,
    notes: notes ?? this.notes,
    createdAt: createdAt,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'contactPerson': contactPerson,
    'phone': phone,
    'email': email,
    'address': address,
    'notes': notes,
    'createdAt': createdAt.toIso8601String(),
  };

  factory Client.fromJson(Map<dynamic, dynamic> j) => Client(
    id: j['id'] as String,
    name: j['name'] as String? ?? '',
    contactPerson: j['contactPerson'] as String? ?? '',
    phone: j['phone'] as String? ?? '',
    email: j['email'] as String? ?? '',
    address: j['address'] as String? ?? '',
    notes: j['notes'] as String? ?? '',
    createdAt:
        DateTime.tryParse(j['createdAt'] as String? ?? '') ?? DateTime.now(),
  );

  /// Normalised name used to match deals to clients.
  static String key(String name) =>
      name.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}
