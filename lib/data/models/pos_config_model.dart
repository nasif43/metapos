/// POS Register configuration representing Odoo 19 `pos.config`.
class PosConfigModel {
  final int id;
  final String name;
  final bool bookFairMode;
  final bool cashControl;
  final int? currentSessionId;
  final String? currentSessionState;
  final List<int> paymentMethodIds;
  final int? currencyId;
  final double discountPc;

  const PosConfigModel({
    required this.id,
    required this.name,
    this.bookFairMode = false,
    this.cashControl = false,
    this.currentSessionId,
    this.currentSessionState,
    this.paymentMethodIds = const [],
    this.currencyId,
    this.discountPc = 0.0,
  });

  /// Factory constructor from Odoo 19 JSON-RPC `search_read` record.
  factory PosConfigModel.fromJson(Map<String, dynamic> json) {
    int? parsedSessionId;
    final session = json['current_session_id'];
    if (session is List && session.isNotEmpty) {
      parsedSessionId = (session[0] as num).toInt();
    } else if (session is num) {
      parsedSessionId = session.toInt();
    }

    String? parsedSessionState;
    final state = json['current_session_state'];
    if (state is String && state.isNotEmpty) {
      parsedSessionState = state;
    }

    List<int> parsedPaymentMethodIds = [];
    final methods = json['payment_method_ids'];
    if (methods is List) {
      parsedPaymentMethodIds = methods.whereType<int>().toList();
    }

    int? parsedCurrencyId;
    final currency = json['currency_id'];
    if (currency is List && currency.isNotEmpty) {
      parsedCurrencyId = (currency[0] as num).toInt();
    } else if (currency is num) {
      parsedCurrencyId = currency.toInt();
    }

    final discount = (json['discount_pc'] as num?)?.toDouble() ?? 0.0;

    return PosConfigModel(
      id: json['id'] as int,
      name: (json['name'] ?? '') as String,
      bookFairMode: json['book_fair_mode'] == true,
      cashControl: json['cash_control'] == true,
      currentSessionId: parsedSessionId,
      currentSessionState: parsedSessionState,
      paymentMethodIds: parsedPaymentMethodIds,
      currencyId: parsedCurrencyId,
      discountPc: discount,
    );
  }

  /// Converts model to standard JSON map.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'book_fair_mode': bookFairMode,
      'cash_control': cashControl,
      'current_session_id': currentSessionId,
      'current_session_state': currentSessionState,
      'payment_method_ids': paymentMethodIds,
      'currency_id': currencyId,
      'discount_pc': discountPc,
    };
  }

  PosConfigModel copyWith({
    int? id,
    String? name,
    bool? bookFairMode,
    bool? cashControl,
    int? currentSessionId,
    String? currentSessionState,
    List<int>? paymentMethodIds,
    int? currencyId,
    double? discountPc,
  }) {
    return PosConfigModel(
      id: id ?? this.id,
      name: name ?? this.name,
      bookFairMode: bookFairMode ?? this.bookFairMode,
      cashControl: cashControl ?? this.cashControl,
      currentSessionId: currentSessionId ?? this.currentSessionId,
      currentSessionState: currentSessionState ?? this.currentSessionState,
      paymentMethodIds: paymentMethodIds ?? this.paymentMethodIds,
      currencyId: currencyId ?? this.currencyId,
      discountPc: discountPc ?? this.discountPc,
    );
  }

  bool get hasActiveSession =>
      currentSessionId != null && currentSessionState == 'opened';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PosConfigModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          currentSessionId == other.currentSessionId &&
          currentSessionState == other.currentSessionState;

  @override
  int get hashCode =>
      id.hashCode ^
      name.hashCode ^
      (currentSessionId?.hashCode ?? 0) ^
      (currentSessionState?.hashCode ?? 0);

  @override
  String toString() =>
      'PosConfigModel(id: $id, name: $name, currentSessionId: $currentSessionId, state: $currentSessionState)';
}
