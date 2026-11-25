import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/locale_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/user_error_message.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/catalog_provider.dart';
import '../../../providers/connectivity_provider.dart';
import '../../../providers/dashboard_provider.dart';
import '../../../providers/session_provider.dart';
import '../../widgets/brand_logo.dart';
import '../../widgets/language_toggle_button.dart';

/// Screen 1: SessionLoginScreen (`/login`)
///
/// Authentication, Odoo 19 live connection, POS Config selector,
/// opening float cash input, and primary entry to Dashboard (`/dashboard`).
class SessionLoginScreen extends ConsumerStatefulWidget {
  const SessionLoginScreen({super.key});

  @override
  ConsumerState<SessionLoginScreen> createState() => _SessionLoginScreenState();
}

class _SessionLoginScreenState extends ConsumerState<SessionLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _serverController =
      TextEditingController(text: 'https://demostore.metaposbd.com');
  final _dbController = TextEditingController(text: 'demostore');
  final _usernameController = TextEditingController(text: 'admin');
  final _passwordController =
      TextEditingController(text: 'admin');
  final _openingFloatController = TextEditingController(text: '5000');

  bool _obscurePassword = true;
  bool _rememberLogin = true;
  int _selectedConfigId = 1; // 1: Book Fair, 2: nilkhet
  bool _isLoggingIn = false;

  @override
  void dispose() {
    _serverController.dispose();
    _dbController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _openingFloatController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (_isLoggingIn) return;

    final isBangla = ref.read(localeProvider).languageCode == 'bn';
    setState(() => _isLoggingIn = true);

    try {
      final isOnline = ref.read(connectivityProvider);
      if (!isOnline) {
        // Latent offline-first fallback when device has no internet connection
        ref.read(authSessionProvider.notifier).toggleOfflineMode(true);
        await ref.read(catalogProvider.notifier).loadCatalog(isOffline: true);
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/dashboard');
        return;
      }

      // Online authentication against backend
      final success = await ref.read(authSessionProvider.notifier).login(
            baseUrl: _serverController.text.trim(),
            db: _dbController.text.trim(),
            login: _usernameController.text.trim(),
            password: _passwordController.text.trim(),
          );

      if (!mounted) return;

      if (success) {
        ref.read(authSessionProvider.notifier).toggleOfflineMode(false);

        // Fetch configs & payment methods
        await ref.read(sessionProvider.notifier).loadConfigs();

        // Bind selected terminal config and ensure an open POS session exists
        final openingFloat =
            double.tryParse(_openingFloatController.text.trim()) ?? 0.0;
        await ref.read(sessionProvider.notifier).ensureActiveSession(
              _selectedConfigId,
              openingFloat: openingFloat,
            );

        // Pre-fetch live catalog and live dashboard telemetry
        await Future.wait([
          ref.read(catalogProvider.notifier).loadCatalog(forceRefresh: true),
          ref.read(dashboardProvider.notifier).fetchDashboard(forceRefresh: true),
        ]);

        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/dashboard');
      } else {
        final error = ref.read(authSessionProvider).errorMessage;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.surfaceDark,
            content: Text(
              error ??
                  (isBangla
                      ? 'লগইন করা যায়নি। অনুগ্রহ করে তথ্য যাচাই করুন।'
                      : 'Sign in failed. Please check your credentials.'),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.surfaceDark,
          content: Text(
            UserErrorMessage.format(e, isBangla: isBangla),
            style: const TextStyle(color: Colors.white),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoggingIn = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isBangla = ref.watch(localeProvider).languageCode == 'bn';
    final sessionState = ref.watch(sessionProvider);

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: const [
          LanguageToggleButton(),
          SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(
                      child: BrandLogo(size: 56.0, showText: true),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      isBangla ? 'পয়েন্ট অব সেল' : 'Point of Sale',
                      textAlign: TextAlign.center,
                      style: AppTypography.heading1,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      isBangla
                          ? 'অমর একুশে বইমেলা'
                          : 'Amar Ekushey Boi Mela',
                      textAlign: TextAlign.center,
                      style: AppTypography.bodyRegular.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // Server Status Pill
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.statusInStockBg,
                        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                        border: Border.all(color: AppColors.statusInStock),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.statusInStock,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Flexible(
                            child: Text(
                              isBangla
                                  ? 'সার্ভার অনলাইন • ক্লাউড কানেক্টেড'
                                  : 'Server Online • Connected',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.caption.copyWith(
                                color: AppColors.statusInStock,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // Connection Credentials Card
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isBangla ? 'সার্ভার সংযোগ' : 'Connection',
                              style: AppTypography.heading2.copyWith(fontSize: 16),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            TextFormField(
                              controller: _serverController,
                              decoration: InputDecoration(
                                labelText: isBangla ? 'সার্ভার ঠিকানা' : 'Server URL',
                                prefixIcon: const Icon(Icons.dns_rounded),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            TextFormField(
                              controller: _dbController,
                              decoration: InputDecoration(
                                labelText: isBangla ? 'ডেটাবেসের নাম' : 'Database Name',
                                prefixIcon: const Icon(Icons.storage_rounded),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            TextFormField(
                              controller: _usernameController,
                              decoration: InputDecoration(
                                labelText: isBangla ? 'ব্যবহারকারীর নাম' : 'Username',
                                prefixIcon: const Icon(Icons.person_outline_rounded),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              decoration: InputDecoration(
                                labelText: isBangla ? 'পাসওয়ার্ড' : 'Password',
                                prefixIcon: const Icon(Icons.lock_outline_rounded),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_off_rounded
                                        : Icons.visibility_rounded,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // POS Config Selector
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isBangla
                                  ? 'রেজিস্টার নির্বাচন'
                                  : 'Select Register',
                              style: AppTypography.heading2.copyWith(fontSize: 16),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            RadioGroup<int>(
                              groupValue: _selectedConfigId,
                              onChanged: (val) {
                                if (val != null) setState(() => _selectedConfigId = val);
                              },
                              child: Column(
                                children: sessionState.configs.isNotEmpty
                                    ? sessionState.configs.map((config) {
                                        final isOpened = config.currentSessionState == 'opened';
                                        final statusText = isBangla
                                            ? (isOpened ? 'সেশন চলছে' : 'সেশন বন্ধ')
                                            : (isOpened ? 'Session Open' : 'Session Closed');
                                        final subtitle = isBangla
                                            ? 'আইডি: ${config.id} • $statusText'
                                            : 'ID: ${config.id} • $statusText';
                                        return RadioListTile<int>(
                                          value: config.id,
                                          fillColor: WidgetStateProperty.resolveWith(
                                            (states) => states.contains(WidgetState.selected)
                                                ? AppColors.emerald
                                                : AppColors.textSecondary,
                                          ),
                                          title: Text(
                                            config.name,
                                            style: AppTypography.bodyMediumBengali,
                                          ),
                                          subtitle: Text(subtitle),
                                        );
                                      }).toList()
                                    : [
                                        RadioListTile<int>(
                                          value: 1,
                                          fillColor: WidgetStateProperty.resolveWith(
                                            (states) => states.contains(WidgetState.selected)
                                                ? AppColors.emerald
                                                : AppColors.textSecondary,
                                          ),
                                          title: Text(
                                            isBangla ? 'বইমেলা স্টল ১' : 'Book Fair Stall 1',
                                            style: AppTypography.bodyMediumBengali,
                                          ),
                                          subtitle: Text(
                                            isBangla
                                                ? 'আইডি: ১ • অমর একুশে বইমেলা'
                                                : 'ID: 1 • Active Session Opening Control',
                                          ),
                                        ),
                                        RadioListTile<int>(
                                          value: 2,
                                          fillColor: WidgetStateProperty.resolveWith(
                                            (states) => states.contains(WidgetState.selected)
                                                ? AppColors.emerald
                                                : AppColors.textSecondary,
                                          ),
                                          title: Text(
                                            isBangla ? 'নীলক্ষেত শাখা' : 'Nilkhet Branch',
                                            style: AppTypography.bodyMediumBengali,
                                          ),
                                          subtitle: Text(
                                            isBangla
                                                ? 'আইডি: ২ • স্থায়ী আউটলেট'
                                                : 'ID: 2 • Standard Branch Register',
                                          ),
                                        ),
                                      ],
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            TextFormField(
                              controller: _openingFloatController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(
                                labelText: isBangla
                                    ? 'প্রারম্ভিক নগদ'
                                    : 'Opening Float',
                                prefixText: '৳ ',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // Options
                    CheckboxListTile(
                      value: _rememberLogin,
                      activeColor: AppColors.emerald,
                      title: Text(
                        isBangla
                            ? 'লগইন তথ্য সংরক্ষণ করুন'
                            : 'Remember login credentials',
                      ),
                      controlAffinity: ListTileControlAffinity.leading,
                      onChanged: (val) => setState(() => _rememberLogin = val ?? true),
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // Action Button
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.emerald,
                        minimumSize: const Size(double.infinity, 54),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                        ),
                      ),
                      onPressed: _isLoggingIn ? null : _handleLogin,
                      child: _isLoggingIn
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            )
                          : Text(
                              isBangla
                                  ? 'টার্মিনাল খুলুন'
                                  : 'Open Terminal',
                              style: TextStyle(
                                fontFamily:
                                    isBangla ? 'HindSiliguri' : 'PlusJakartaSans',
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
