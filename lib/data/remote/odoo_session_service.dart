import '../models/pos_config_model.dart';
import '../models/session_model.dart';
import 'json_rpc_client.dart';

/// Remote service managing Odoo 19 POS register configurations and session lifecycles.
class OdooSessionService {
  final OdooJsonRpcClient client;

  OdooSessionService({required this.client});

  /// Queries all available POS registers (`pos.config`) and active session states.
  Future<List<PosConfigModel>> searchConfigs({List<dynamic> domain = const []}) async {
    final fields = [
      'id',
      'name',
      'book_fair_mode',
      'cash_control',
      'current_session_id',
      'current_session_state',
      'payment_method_ids',
      'currency_id',
      'discount_pc',
    ];

    final result = await client.executeCall(
      'pos.config',
      'search_read',
      [domain],
      {'fields': fields},
    );

    if (result is List) {
      return result
          .whereType<Map<String, dynamic>>()
          .map((json) => PosConfigModel.fromJson(json))
          .toList();
    }
    return [];
  }

  /// Instantiates a new POS session for register [configId] via `pos.config.open_ui`.
  ///
  /// Transitions or creates the session in `opening_control` state.
  Future<dynamic> openUi(int configId) async {
    return await client.executeCall(
      'pos.config',
      'open_ui',
      [[configId]],
      {},
    );
  }

  /// Sets the opening cash float balance and transitions session from `opening_control` to `opened`.
  Future<dynamic> setOpeningControl(
    int sessionId,
    double floatAmount, {
    String notes = '',
  }) async {
    return await client.executeCall(
      'pos.session',
      'set_opening_control',
      [
        [sessionId],
        floatAmount,
        notes,
      ],
      {},
    );
  }

  /// Posts physical closing cash count for register [sessionId].
  Future<dynamic> postClosingCashDetails(
    int sessionId,
    double countedCash,
  ) async {
    return await client.executeCall(
      'pos.session',
      'post_closing_cash_details',
      [[sessionId]],
      {'counted_cash': countedCash},
    );
  }

  /// Closes the session and transitions state to `closed`.
  ///
  /// Under `book_fair_mode`, accounting differences are automatically logged
  /// to chatter rather than throwing blocking cash variance errors.
  Future<Map<String, dynamic>> closeSessionFromUi(
    int sessionId, {
    List<dynamic> bankPaymentMethodDiffPairs = const [],
  }) async {
    final result = await client.executeCall(
      'pos.session',
      'close_session_from_ui',
      [
        [sessionId],
        bankPaymentMethodDiffPairs,
      ],
      {},
    );

    if (result is Map<String, dynamic>) {
      return result;
    }
    return {'successful': true};
  }

  /// Queries session details for [sessionId].
  Future<SessionModel?> getSession(int sessionId) async {
    final fields = [
      'id',
      'name',
      'state',
      'config_id',
      'cash_register_balance_start',
      'cash_register_balance_end_real',
    ];

    final result = await client.executeCall(
      'pos.session',
      'search_read',
      [
        [
          ['id', '=', sessionId]
        ]
      ],
      {'fields': fields},
    );

    if (result is List && result.isNotEmpty) {
      return SessionModel.fromJson(result.first as Map<String, dynamic>);
    }
    return null;
  }
}
