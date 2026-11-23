import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/locale_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../providers/customer_provider.dart';
import '../../widgets/language_toggle_button.dart';

/// Screen 4: CustomerSelectorScreen (`/customer`)
///
/// Customer search, Walk-in guest quick option, partner list,
/// and quick-add modal bottom sheet connected to live Odoo 19 `res.partner` using `phone`.
class CustomerSelectorScreen extends ConsumerStatefulWidget {
  const CustomerSelectorScreen({super.key});

  @override
  ConsumerState<CustomerSelectorScreen> createState() =>
      _CustomerSelectorScreenState();
}

class _CustomerSelectorScreenState
    extends ConsumerState<CustomerSelectorScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(customerProvider.notifier).searchCustomers('');
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String val) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        ref.read(customerProvider.notifier).searchCustomers(val);
      }
    });
  }

  void _showAddCustomerSheet() {
    final isBangla = ref.read(localeProvider).languageCode == 'bn';
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController(text: '01');
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            top: AppSpacing.lg,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + AppSpacing.lg,
          ),
          child: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isBangla ? 'নতুন ক্রেতা' : 'New Customer',
                        style: AppTypography.heading2,
                      ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    labelText: isBangla ? 'পুরো নাম *' : 'Full Name *',
                    prefixIcon: const Icon(Icons.person_outline),
                  ),
                  validator: (val) =>
                      val == null || val.trim().isEmpty ? 'Name is required' : null,
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: isBangla ? 'মোবাইল নম্বর *' : 'Mobile Phone *',
                    prefixIcon: const Icon(Icons.phone_android_rounded),
                    helperText: isBangla
                        ? '১১ ডিজিটের মোবাইল নম্বর, যেমন ০১৭১XXXXXXX'
                        : '11 digits Bangladesh number, e.g. 017XXXXXXXX',
                  ),
                  validator: (val) {
                    if (val == null || val.trim().length < 11) {
                      return 'Enter valid 11-digit mobile number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.lg),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    backgroundColor: AppColors.emerald,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    if (formKey.currentState?.validate() ?? false) {
                      final name = nameCtrl.text.trim();
                      final phone = phoneCtrl.text.trim();
                      final newCustomer = await ref
                          .read(customerProvider.notifier)
                          .createCustomer(name: name, phone: phone);

                      if (newCustomer != null) {
                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                        }
                        if (mounted) {
                          Navigator.pop(context, newCustomer);
                        }
                      }
                    }
                  },
                  child: Text(
                    isBangla
                        ? 'সংরক্ষণ করুন'
                        : 'Save',
                    style: AppTypography.bodyMedium.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isBangla = ref.watch(localeProvider).languageCode == 'bn';
    final customerState = ref.watch(customerProvider);
    final partners = customerState.customers;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            isBangla ? 'ক্রেতা নির্বাচন' : 'Select Customer',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
        ),
        actions: const [
          LanguageToggleButton(),
          SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          // Search & Quick-Add Bar
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    decoration: InputDecoration(
                      hintText: isBangla
                          ? 'নাম বা মোবাইল নম্বর খুঁজুন...'
                          : 'Search Name or Phone...',
                      hintStyle: AppTypography.bodyRegularBengali.copyWith(
                        color: AppColors.textMuted,
                        fontSize: 13,
                      ),
                      prefixIcon: const Icon(Icons.search_rounded),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(48, 48),
                    backgroundColor: AppColors.emerald,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                  ),
                  onPressed: _showAddCustomerSheet,
                  icon: const Icon(Icons.person_add_alt_1_rounded, size: 20),
                  label: Text(isBangla ? 'যোগ' : 'Add'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Walk-in / Guest Mode Tile
          ListTile(
            tileColor: AppColors.mint,
            leading: const CircleAvatar(
              backgroundColor: AppColors.emerald,
              child: Icon(Icons.person_outline_rounded, color: Colors.white),
            ),
            title: Text(
              isBangla ? 'সাধারণ ক্রেতা' : 'Walk-in / Guest Customer',
              style: AppTypography.bodyMediumBengali.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            subtitle: Text(
              isBangla
                  ? 'সাধারণ গেস্ট'
                  : 'Guest / Walk-in',
            ),
            trailing: const Icon(Icons.check_circle_rounded,
                color: AppColors.emerald),
            onTap: () {
              Navigator.pop(context, null);
            },
          ),
          const Divider(height: 1),

          // Customer List
          Expanded(
            child: customerState.isLoading && partners.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : partners.isEmpty
                    ? Center(
                        child: Text(
                          isBangla
                              ? 'কোনো ক্রেতা পাওয়া যায়নি'
                              : 'No customers found',
                          style: AppTypography.caption,
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        itemCount: partners.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: AppSpacing.sm),
                        itemBuilder: (context, index) {
                          final partner = partners[index];
                          final initials = partner.name
                              .split(' ')
                              .take(2)
                              .map((s) => s.isNotEmpty ? s[0] : '')
                              .join();

                          return Card(
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: AppColors.mint,
                                child: Text(
                                  initials,
                                  style: AppTypography.bodyMedium.copyWith(
                                    color: AppColors.emeraldDark,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              title: Text(
                                partner.name,
                                style: AppTypography.bodyMedium.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                  '${partner.phone ?? ""} • ${partner.city ?? "Dhaka"}'),
                              trailing: const Icon(
                                Icons.arrow_forward_ios_rounded,
                                size: 14,
                                color: AppColors.textMuted,
                              ),
                              onTap: () {
                                Navigator.pop(context, partner);
                              },
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
