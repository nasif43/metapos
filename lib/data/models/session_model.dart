/// Session model representing Odoo 19 `pos.session`.
class SessionModel {
  final int id;
  final String name;
  final String state; // 'opening_control', 'opened', 'closing_control', 'closed'
  final int configId;
  final double cashRegisterBalanceStart;
  final double? cashRegisterBalanceEndReal;

  const SessionModel({
    required this.id,
    required this.name,
    required this.state,
    required this.configId,
    this.cashRegisterBalanceStart = 0.0,
    this.cashRegisterBalanceEndReal,
  });

  /// Factory constructor from Odoo 19 JSON-RPC response.
  factory SessionModel.fromJson(Map<String, dynamic> json) {
    int parsedConfigId = 0;
    final config = json['config_id'];
    if (config is List && config.isNotEmpty) {
      parsedConfigId = (config[0] as num).toInt();
    } else if (config is num) {
      parsedConfigId = config.toInt();
    }

    return SessionModel(
      id: json['id'] as int,
      name: (json['name'] ?? '') as String,
      state: (json['state'] ?? 'closed') as String,
      configId: parsedConfigId,
      cashRegisterBalanceStart:
          (json['cash_register_balance_start'] as num?)?.toDouble() ?? 0.0,
      cashRegisterBalanceEndReal:
          (json['cash_register_balance_end_real'] as num?)?.toDouble(),
    );
  }

  /// Converts model to standard JSON map.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'state': state,
      'config_id': configId,
      'cash_register_balance_start': cashRegisterBalanceStart,
      'cash_register_balance_end_real': cashRegisterBalanceEndReal,
    };
  }

  SessionModel copyWith({
    int? id,
    String? name,
    String? state,
    int? configId,
    double? cashRegisterBalanceStart,
    double? cashRegisterBalanceEndReal,
  }) {
    return SessionModel(
      id: id ?? this.id,
      name: name ?? this.name,
      state: state ?? this.state,
      configId: configId ?? this.configId,
      cashRegisterBalanceStart:
          cashRegisterBalanceStart ?? this.cashRegisterBalanceStart,
      cashRegisterBalanceEndReal:
          cashRegisterBalanceEndReal ?? this.cashRegisterBalanceEndReal,
    );
  }

  bool get isOpen => state == 'opened';
  bool get isOpeningControl => state == 'opening_control';
  bool get isClosed => state == 'closed';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SessionModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          state == other.state &&
          configId == other.configId;

  @override
  int get hashCode => id.hashCode ^ state.hashCode ^ configId.hashCode;

  @override
  String toString() =>
      'SessionModel(id: $id, name: $name, state: $state, configId: $configId)';
}
