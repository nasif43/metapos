/// Partner model representing Odoo 19 `res.partner`.
///
/// Note: In Odoo 19, `res.partner` does NOT have a `mobile` field.
/// Contact numbers are consolidated under `phone`.
class PartnerModel {
  final int id;
  final String name;
  final String? phone;
  final String? email;
  final String? street;
  final String? city;
  final String? barcode;

  const PartnerModel({
    required this.id,
    required this.name,
    this.phone,
    this.email,
    this.street,
    this.city,
    this.barcode,
  });

  /// Factory constructor from Odoo 19 JSON-RPC `search_read` record.
  factory PartnerModel.fromJson(Map<String, dynamic> json) {
    return PartnerModel(
      id: json['id'] as int,
      name: (json['name'] ?? '') as String,
      phone: json['phone'] is String ? json['phone'] as String : null,
      email: json['email'] is String ? json['email'] as String : null,
      street: json['street'] is String ? json['street'] as String : null,
      city: json['city'] is String ? json['city'] as String : null,
      barcode: json['barcode'] is String ? json['barcode'] as String : null,
    );
  }

  /// Converts model to standard JSON map.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'email': email,
      'street': street,
      'city': city,
      'barcode': barcode,
    };
  }

  /// Factory constructor from SQLite `cached_partners` table row.
  factory PartnerModel.fromMap(Map<String, dynamic> map) {
    return PartnerModel(
      id: map['id'] as int,
      name: (map['name'] ?? '') as String,
      phone: map['phone'] as String?,
      email: map['email'] as String?,
      street: map['street'] as String?,
      city: map['city'] as String?,
      barcode: map['barcode'] as String?,
    );
  }

  /// Converts model to SQLite `cached_partners` table row.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'email': email,
      'street': street,
      'city': city,
      'barcode': barcode,
    };
  }

  PartnerModel copyWith({
    int? id,
    String? name,
    String? phone,
    String? email,
    String? street,
    String? city,
    String? barcode,
  }) {
    return PartnerModel(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      street: street ?? this.street,
      city: city ?? this.city,
      barcode: barcode ?? this.barcode,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PartnerModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          phone == other.phone &&
          barcode == other.barcode;

  @override
  int get hashCode =>
      id.hashCode ^ name.hashCode ^ (phone?.hashCode ?? 0) ^ (barcode?.hashCode ?? 0);

  @override
  String toString() =>
      'PartnerModel(id: $id, name: $name, phone: $phone, email: $email)';
}
