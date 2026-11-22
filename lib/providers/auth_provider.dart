import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/remote/json_rpc_client.dart';
import '../data/remote/odoo_auth_service.dart';

/// State representation for authentication and current POS session context.
class AuthSessionState {
  final bool isAuthenticated;
  final String? sessionId;
  final int? userId;
  final String? userName;
  final int? activeConfigId;
  final int? activeSessionId;
  final String? sessionState;
  final bool isOfflineMode;
  final String? errorMessage;
  final bool isLoading;

  const AuthSessionState({
    this.isAuthenticated = false,
    this.sessionId,
    this.userId,
    this.userName,
    this.activeConfigId,
    this.activeSessionId,
    this.sessionState,
    this.isOfflineMode = false,
    this.errorMessage,
    this.isLoading = false,
  });

  AuthSessionState copyWith({
    bool? isAuthenticated,
    String? sessionId,
    int? userId,
    String? userName,
    int? activeConfigId,
    int? activeSessionId,
    String? sessionState,
    bool? isOfflineMode,
    String? errorMessage,
    bool? isLoading,
  }) {
    return AuthSessionState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      sessionId: sessionId ?? this.sessionId,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      activeConfigId: activeConfigId ?? this.activeConfigId,
      activeSessionId: activeSessionId ?? this.activeSessionId,
      sessionState: sessionState ?? this.sessionState,
      isOfflineMode: isOfflineMode ?? this.isOfflineMode,
      errorMessage: errorMessage,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

/// Provider for shared Odoo JSON-RPC client.
final jsonRpcClientProvider = Provider<OdooJsonRpcClient>((ref) {
  return OdooJsonRpcClient(baseUrl: 'https://demostore.metaposbd.com');
});

/// Provider for Odoo authentication remote service.
final authServiceProvider = Provider<OdooAuthService>((ref) {
  final client = ref.watch(jsonRpcClientProvider);
  return OdooAuthService(client: client);
});

/// State notifier managing user authentication and active register session.
class AuthSessionNotifier extends StateNotifier<AuthSessionState> {
  final OdooAuthService authService;

  AuthSessionNotifier({required this.authService})
      : super(const AuthSessionState());

  /// Authenticates user against Odoo 19 backend.
  Future<bool> login({
    required String baseUrl,
    required String db,
    required String login,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final info = await authService.authenticate(
        baseUrl: baseUrl,
        db: db,
        login: login,
        password: password,
      );

      final uid = (info['uid'] as num?)?.toInt();
      final name = (info['name'] ?? info['username']) as String?;
      final sessionCookie = authService.client.sessionId;

      state = state.copyWith(
        isAuthenticated: true,
        sessionId: sessionCookie,
        userId: uid,
        userName: name,
        isLoading: false,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isAuthenticated: false,
        isLoading: false,
        errorMessage: e.toString(),
      );
      return false;
    }
  }

  /// Logs out of session and clears credentials.
  Future<void> logout() async {
    state = state.copyWith(isLoading: true);
    try {
      await authService.destroySession();
    } catch (_) {}
    state = const AuthSessionState();
  }

  /// Sets the active POS register config ID.
  void setActiveConfig(int configId) {
    state = state.copyWith(activeConfigId: configId);
  }

  /// Sets active session ID and state ('opened', 'opening_control', etc.).
  void setActiveSession(int? sessionId, String? sessionState) {
    state = state.copyWith(
      activeSessionId: sessionId,
      sessionState: sessionState,
    );
  }

  /// Toggles offline selling mode.
  void toggleOfflineMode([bool? forceValue]) {
    final newValue = forceValue ?? !state.isOfflineMode;
    state = state.copyWith(isOfflineMode: newValue);
  }

  /// Validates session cookie via `/web/session/get_session_info`.
  Future<bool> checkSession() async {
    try {
      final info = await authService.getSessionInfo();
      final uid = (info['uid'] as num?)?.toInt();
      if (uid != null) {
        state = state.copyWith(
          isAuthenticated: true,
          userId: uid,
          userName: (info['name'] ?? info['username']) as String?,
        );
        return true;
      }
      return false;
    } catch (_) {
      state = state.copyWith(isAuthenticated: false);
      return false;
    }
  }
}

/// Global provider for AuthSession state and actions.
final authSessionProvider =
    StateNotifierProvider<AuthSessionNotifier, AuthSessionState>((ref) {
  final authService = ref.watch(authServiceProvider);
  return AuthSessionNotifier(authService: authService);
});
