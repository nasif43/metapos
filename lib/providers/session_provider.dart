import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/user_error_message.dart';
import '../data/models/pos_config_model.dart';
import '../data/models/session_model.dart';
import '../data/remote/odoo_session_service.dart';
import 'auth_provider.dart';

/// State representation for POS register configurations and active session lifecycle.
class PosSessionState {
  final List<PosConfigModel> configs;
  final PosConfigModel? selectedConfig;
  final SessionModel? activeSession;
  final List<Map<String, dynamic>> paymentMethods;
  final bool isLoading;
  final String? errorMessage;

  const PosSessionState({
    this.configs = const [],
    this.selectedConfig,
    this.activeSession,
    this.paymentMethods = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  /// Resolves a valid Cash payment method ID enabled for the active counter.
  int resolveCashMethodId() {
    final allowed = selectedConfig?.paymentMethodIds ?? const [];
    for (final m in paymentMethods) {
      final id = m['id'] as int?;
      final isCash = m['is_cash_count'] == true;
      if (id != null && isCash && (allowed.isEmpty || allowed.contains(id))) {
        return id;
      }
    }
    return allowed.isNotEmpty ? allowed.first : 1;
  }

  /// Resolves a valid Card/MFS (non-cash) payment method ID enabled for the active counter.
  int resolveNonCashMethodId() {
    final allowed = selectedConfig?.paymentMethodIds ?? const [];
    for (final m in paymentMethods) {
      final id = m['id'] as int?;
      final isCash = m['is_cash_count'] == true;
      if (id != null && !isCash && (allowed.isEmpty || allowed.contains(id))) {
        return id;
      }
    }
    return allowed.isNotEmpty ? allowed.first : 2;
  }

  PosSessionState copyWith({
    List<PosConfigModel>? configs,
    PosConfigModel? selectedConfig,
    SessionModel? activeSession,
    bool clearActiveSession = false,
    List<Map<String, dynamic>>? paymentMethods,
    bool? isLoading,
    String? errorMessage,
  }) {
    return PosSessionState(
      configs: configs ?? this.configs,
      selectedConfig: selectedConfig ?? this.selectedConfig,
      activeSession:
          clearActiveSession ? null : (activeSession ?? this.activeSession),
      paymentMethods: paymentMethods ?? this.paymentMethods,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

/// Provider for Odoo POS session remote service.
final sessionServiceProvider = Provider<OdooSessionService>((ref) {
  final client = ref.watch(jsonRpcClientProvider);
  return OdooSessionService(client: client);
});

/// State notifier managing POS register configurations and session operations.
class PosSessionNotifier extends StateNotifier<PosSessionState> {
  final OdooSessionService sessionService;

  PosSessionNotifier({required this.sessionService})
      : super(const PosSessionState());

  /// Loads available POS registers and payment methods from Odoo.
  Future<void> loadConfigs() async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final results = await Future.wait([
        sessionService.searchConfigs(),
        sessionService.fetchPaymentMethods().catchError((_) => <Map<String, dynamic>>[]),
      ]);
      final configs = results[0] as List<PosConfigModel>;
      final methods = results[1] as List<Map<String, dynamic>>;

      PosConfigModel? defaultSelection = state.selectedConfig;

      if (defaultSelection == null && configs.isNotEmpty) {
        // Prefer an already-opened register first, otherwise Book Fair config
        defaultSelection = configs.firstWhere(
          (c) => c.hasActiveSession,
          orElse: () => configs.firstWhere(
            (c) => c.bookFairMode,
            orElse: () => configs.first,
          ),
        );
      }

      state = state.copyWith(
        configs: configs,
        selectedConfig: defaultSelection,
        paymentMethods: methods,
        isLoading: false,
      );

      // If selected register has an active session, load its details
      if (defaultSelection != null && defaultSelection.currentSessionId != null) {
        await refreshSession(defaultSelection.currentSessionId!);
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: UserErrorMessage.format(e),
      );
    }
  }

  /// Sets the actively selected POS register config.
  Future<void> selectConfig(int configId) async {
    try {
      final selected = state.configs.firstWhere((c) => c.id == configId);
      state = state.copyWith(selectedConfig: selected);

      if (selected.currentSessionId != null) {
        await refreshSession(selected.currentSessionId!);
      } else {
        state = state.copyWith(clearActiveSession: true);
      }
    } catch (_) {}
  }

  /// Ensures the selected POS register has an active `opened` session,
  /// opening one automatically if closed.
  Future<int?> ensureActiveSession(
    int configId, {
    double openingFloat = 0.0,
  }) async {
    try {
      await selectConfig(configId);
      var current = state.selectedConfig;

      // 1. If no session exists at all, open UI to create one
      if (current == null || current.currentSessionId == null) {
        await sessionService.openUi(configId);
        await loadConfigs();
        await selectConfig(configId);
        current = state.selectedConfig;
      }

      // 2. If session is in opening_control, submit opening cash to transition to 'opened'
      if (current != null &&
          current.currentSessionId != null &&
          current.currentSessionState == 'opening_control') {
        await sessionService.setOpeningControl(
          current.currentSessionId!,
          openingFloat,
        );
        await loadConfigs();
        await selectConfig(configId);
        current = state.selectedConfig;
      }

      if (state.activeSession != null && state.activeSession!.isOpen) {
        return state.activeSession!.id;
      }
      return current?.currentSessionId;
    } catch (e) {
      state = state.copyWith(errorMessage: UserErrorMessage.format(e));
      return state.activeSession?.id ?? state.selectedConfig?.currentSessionId;
    }
  }

  /// Refreshes session details for [sessionId].
  Future<void> refreshSession(int sessionId) async {
    try {
      final session = await sessionService.getSession(sessionId);
      state = state.copyWith(activeSession: session);
    } catch (_) {}
  }

  /// Instantiates a new session for register [configId] via `pos.config.open_ui`.
  Future<bool> openSession(int configId) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await sessionService.openUi(configId);
      await loadConfigs();
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: UserErrorMessage.format(e),
      );
      return false;
    }
  }

  /// Sets opening cash float and activates session to `opened` state.
  Future<bool> setOpeningFloat(
    int sessionId,
    double floatAmount, {
    String notes = '',
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await sessionService.setOpeningControl(sessionId, floatAmount, notes: notes);
      await refreshSession(sessionId);
      await loadConfigs();
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: UserErrorMessage.format(e),
      );
      return false;
    }
  }

  /// Posts closing cash count and transitions session to `closed`.
  Future<bool> closeSession(int sessionId, {double? countedCash}) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      if (countedCash != null) {
        await sessionService.postClosingCashDetails(sessionId, countedCash);
      }
      await sessionService.closeSessionFromUi(sessionId);
      await loadConfigs();
      state = state.copyWith(activeSession: null, isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: UserErrorMessage.format(e),
      );
      return false;
    }
  }
}

/// Global provider for POS session state and actions.
final sessionProvider =
    StateNotifierProvider<PosSessionNotifier, PosSessionState>((ref) {
  final sessionService = ref.watch(sessionServiceProvider);
  return PosSessionNotifier(sessionService: sessionService);
});
