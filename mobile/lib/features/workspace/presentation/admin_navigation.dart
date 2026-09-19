import 'package:flutter/material.dart';

import 'admin_activity_page.dart';
import 'admin_alerts_page.dart';
import 'admin_catalog_page.dart';
import 'admin_commerce_page.dart';
import 'admin_dashboard_page.dart';
import 'admin_delivery_page.dart';
import 'admin_finance_page.dart';
import 'admin_marketplace_listings_page.dart';
import 'admin_notification_campaign_page.dart';
import 'admin_operations_page.dart';
import 'admin_queues_page.dart';
import 'admin_support_tickets_page.dart';
import 'admin_users_page.dart';

/// All top-level administration areas. Every entry is reachable from the
/// adaptive control menu, rather than being hidden in a long horizontal strip.
enum AdminDestination {
  dashboard,
  users,
  queues,
  commerce,
  catalog,
  marketplace,
  support,
  delivery,
  finance,
  notifications,
  campaigns,
  activity,
  operations,
}

void openAdminDestination(BuildContext context, AdminDestination destination) {
  final Widget page = switch (destination) {
    AdminDestination.dashboard => const AdminDashboardPage(),
    AdminDestination.users => const AdminUsersPage(),
    AdminDestination.queues => const AdminQueuesPage(),
    AdminDestination.commerce => const AdminCommercePage(),
    AdminDestination.catalog => const AdminCatalogPage(),
    AdminDestination.marketplace => const AdminMarketplaceListingsPage(),
    AdminDestination.support => const AdminSupportTicketsPage(),
    AdminDestination.delivery => const AdminDeliveryPage(),
    AdminDestination.finance => const AdminFinancePage(),
    AdminDestination.notifications => const AdminAlertsPage(),
    AdminDestination.campaigns => const AdminNotificationCampaignPage(),
    AdminDestination.activity => const AdminActivityPage(),
    AdminDestination.operations => const AdminOperationsPage(),
  };
  Navigator.of(context)
      .pushReplacement(MaterialPageRoute<void>(builder: (_) => page));
}

/// A responsive administration frame inspired by an operations console:
/// an always-visible grouped sidebar on wide screens and a full drawer on
/// phones. Individual areas remain independent, so their privileged API
/// checks and refresh flows are not weakened by the visual redesign.
final class AdminWorkspaceScaffold extends StatelessWidget {
  const AdminWorkspaceScaffold({
    super.key,
    required this.active,
    required this.appBar,
    required this.body,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
  });

  final AdminDestination active;
  final PreferredSizeWidget appBar;
  final Widget body;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 1040;
    final theme = Theme.of(context);
    return Theme(
      data: theme.copyWith(
        scaffoldBackgroundColor: const Color(0xFFF8FBFF),
        appBarTheme: theme.appBarTheme.copyWith(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF17384E),
          surfaceTintColor: Colors.white,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: const TextStyle(
            color: Color(0xFF17384E),
            fontSize: 19,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      child: Scaffold(
        appBar: appBar,
        drawer: wide
            ? null
            : Drawer(child: _AdminSideNavigation(active: active)),
        floatingActionButton: floatingActionButton,
        floatingActionButtonLocation: floatingActionButtonLocation,
        body: Row(
          children: [
            if (wide) ...[
              SizedBox(width: 278, child: _AdminSideNavigation(active: active)),
              const VerticalDivider(width: 1),
            ],
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}

/// Kept as compatibility helpers for legacy area app bars. The old crowded
/// cross-area strip is intentionally removed; the adaptive control menu owns
/// that navigation while local TabBars keep their page-specific controls.
PreferredSizeWidget adminControlBottom(BuildContext context, String active) =>
    const PreferredSize(preferredSize: Size.zero, child: SizedBox.shrink());

PreferredSizeWidget adminTabbedBottom(
  BuildContext context,
  String active,
  TabBar tabs,
) => PreferredSize(preferredSize: tabs.preferredSize, child: tabs);

final class _AdminSideNavigation extends StatelessWidget {
  const _AdminSideNavigation({required this.active});

  final AdminDestination active;

  void _open(BuildContext context, AdminDestination destination) {
    if (destination == active) {
      if (Scaffold.maybeOf(context)?.isDrawerOpen == true)
        Navigator.of(context).pop();
      return;
    }
    final navigator = Navigator.of(context);
    if (Scaffold.maybeOf(context)?.isDrawerOpen == true) navigator.pop();
    openAdminDestination(context, destination);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: const Color(0xFFF8FBFF),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 24),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                gradient: const LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: [Color(0xFF0A396A), Color(0xFF126DC0)],
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x331366B2),
                    blurRadius: 18,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .18),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: .28),
                      ),
                    ),
                    child: const Icon(
                      Icons.admin_panel_settings_rounded,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 11),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'تجارتي',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'مركز التحكم الإداري',
                          style: TextStyle(
                            color: Color(0xFFDCEEFF),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 17),
            _NavGroup(
              title: 'نظرة عامة',
              children: [
                _NavEntry(
                  destination: AdminDestination.dashboard,
                  label: 'الرئيسية',
                  description: 'المؤشرات والمهام العاجلة',
                  icon: Icons.grid_view_rounded,
                ),
                _NavEntry(
                  destination: AdminDestination.queues,
                  label: 'الطوابير والقرارات',
                  description: 'طلبات تحتاج مراجعة',
                  icon: Icons.rule_folder_outlined,
                ),
              ],
            ),
            _NavGroup(
              title: 'التجارة والمحتوى',
              children: [
                _NavEntry(
                  destination: AdminDestination.users,
                  label: 'المستخدمون',
                  description: 'الحسابات والأدوار',
                  icon: Icons.manage_accounts_outlined,
                ),
                _NavEntry(
                  destination: AdminDestination.commerce,
                  label: 'المتاجر والطلبات',
                  description: 'المتاجر والمنتجات والبيع',
                  icon: Icons.storefront_outlined,
                ),
                _NavEntry(
                  destination: AdminDestination.catalog,
                  label: 'الكتالوج والتصنيفات',
                  description: 'بنية المتاجر والمنتجات',
                  icon: Icons.category_outlined,
                ),
                _NavEntry(
                  destination: AdminDestination.marketplace,
                  label: 'الحراج والمواقع',
                  description: 'الإعلانات والمراجعة',
                  icon: Icons.view_quilt_outlined,
                ),
              ],
            ),
            _NavGroup(
              title: 'التشغيل والمالية',
              children: [
                _NavEntry(
                  destination: AdminDestination.delivery,
                  label: 'التوصيل والمهام',
                  description: 'المناديب وحركة التسليم',
                  icon: Icons.local_shipping_outlined,
                ),
                _NavEntry(
                  destination: AdminDestination.finance,
                  label: 'المالية والمدفوعات',
                  description: 'السجل والمحافظ والفواتير',
                  icon: Icons.account_balance_wallet_outlined,
                ),
                _NavEntry(
                  destination: AdminDestination.support,
                  label: 'الدعم',
                  description: 'تذاكر العملاء والمتابعة',
                  icon: Icons.support_agent_outlined,
                ),
              ],
            ),
            _NavGroup(
              title: 'التواصل والضبط',
              children: [
                _NavEntry(
                  destination: AdminDestination.notifications,
                  label: 'تنبيهات الإدارة',
                  description: 'صندوقك الشخصي والقرارات العاجلة',
                  icon: Icons.notifications_active_outlined,
                  emphasis: true,
                ),
                _NavEntry(
                  destination: AdminDestination.campaigns,
                  label: 'الحملات والإشعارات',
                  description: 'إنشاء حملات المدير',
                  icon: Icons.campaign_outlined,
                  emphasis: true,
                ),
                _NavEntry(
                  destination: AdminDestination.activity,
                  label: 'السجل والمراجعات',
                  description: 'النشاط وحملات التجار',
                  icon: Icons.history_rounded,
                ),
                _NavEntry(
                  destination: AdminDestination.operations,
                  label: 'السياسات والرسوم',
                  description: 'إعدادات المنصة والتشغيل',
                  icon: Icons.tune_rounded,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(
                  alpha: .42,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                children: [
                  Icon(Icons.verified_user_outlined, size: 19),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'كل القرارات والإرسال تسجّل في سجل التدقيق.',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final class _NavGroup extends StatelessWidget {
  const _NavGroup({required this.title, required this.children});

  final String title;
  final List<_NavEntry> children;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(9, 0, 9, 7),
          child: Text(
            title,
            style: const TextStyle(
              color: Color(0xFF66798A),
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        ...children,
      ],
    ),
  );
}

final class _NavEntry extends StatelessWidget {
  const _NavEntry({
    required this.destination,
    required this.label,
    required this.description,
    required this.icon,
    this.emphasis = false,
  });

  final AdminDestination destination;
  final String label;
  final String description;
  final IconData icon;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    final parent = context
        .findAncestorWidgetOfExactType<_AdminSideNavigation>();
    final active = parent?.active == destination;
    final accent = const Color(0xFF1673D1);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: active
            ? const Color(0xFFDCEEFF)
            : emphasis
            ? const Color(0xFFF0F7FF)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(15),
        child: InkWell(
          onTap: () => parent?._open(context, destination),
          borderRadius: BorderRadius.circular(15),
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(10, 9, 9, 9),
            child: Row(
              children: [
                Container(
                  width: 35,
                  height: 35,
                  decoration: BoxDecoration(
                    color: active
                        ? accent
                        : emphasis
                        ? const Color(0xFFDCEEFF)
                        : const Color(0xFFEFF3F6),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(
                    icon,
                    size: 19,
                    color: active ? Colors.white : const Color(0xFF3F6179),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          color: active
                              ? const Color(0xFF075CA9)
                              : const Color(0xFF20394B),
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF748796),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                if (active)
                  const Icon(
                    Icons.chevron_left_rounded,
                    color: Color(0xFF1673D1),
                    size: 19,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
