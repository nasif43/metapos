import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/pos_config_model.dart';
import '../data/models/session_model.dart';
import '../data/remote/odoo_session_service.dart';
import 'auth_provider.dart';

/// State representation for POS register configurations and active session lifecycle.
class PosSessionState {
  final List<PosConfigModel> configs;
  final PosConfigModel? selectedConfig;
  final SessionModel? activeSession;
  final bool isLoading;
  final String? errorMessage;

  const PosSessionState({
    this.configs = const [],
    this.selectedConfig,
    this.activeSession,
    this.isLoading = false,
    this.errorMessage,
  });

  PosSessionState copyWith({
    List<PosConfigModel>? configs,
    PosConfigModel? selectedConfig,
    SessionModel? activeSession,
    bool? isLoading,
    String? errorMessage,
  }) {
    return PosSessionState(
      configs: configs ?? this.configs,
      selectedConfig: selectedConfig ?? this.selectedConfig,
      activeSession: activeSession ?? this.activeSession,
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

  /// Loads available POS registers from Odoo `pos.config`.
  Future<void> loadConfigs() async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final configs = await sessionService.searchConfigs();
      PosConfigModel? defaultSelection = state.selectedConfig;

      if (defaultSelection == null && configs.isNotEmpty) {
        // Prefer Book Fair config (ID 1) by default
        defaultSelection = configs.firstWhere(
          (c) => c.bookFairMode,
          orElse: () => configs.first,
        );
      }

      state = state.copyWith(
        configs: configs,
        selectedConfig: defaultSelection,
        isLoading: false,
      );

      // If selected register has an active session, load its details
      if (defaultSelection != null && defaultSelection.currentSessionId != null) {
        await refreshSession(defaultSelection.currentSessionId!);
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
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
        state = state.copyWith(activeSession: null);
      }
    } catch (_) {}
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
        errorMessage: e.toString(),
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
        errorMessage: e.toString(),
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
        errorMessage: e.toString(),
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
