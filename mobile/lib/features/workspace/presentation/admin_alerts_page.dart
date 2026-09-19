import 'package:flutter/material.dart';

import '../../../app/app_scope.dart';
import '../../../core/network/api_exception.dart';
import '../../notifications/data/notification_repository.dart';
import '../../notifications/presentation/notification_preferences_page.dart';
import '../../notifications/presentation/notification_target_router.dart';
import 'admin_navigation.dart';

/// Personal inbox for administrative decisions. Operational delivery records
/// remain in AdminActivityPage; this page contains only the signed-in
/// administrator's actual notifications and routes each one safely.
final class AdminAlertsPage extends StatefulWidget {
  const AdminAlertsPage({super.key});

  @override
  State<AdminAlertsPage> createState() => _AdminAlertsPageState();
}

final class _AdminAlertsPageState extends State<AdminAlertsPage> {
  late Future<NotificationFeed> _future;
  int? _revision;
  String _filter = 'all';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = AppScope.of(context);
    if (_revision != controller.notificationRevision) {
      _revision = controller.notificationRevision;
      _future = controller.loadNotifications();
    }
  }

  void _reload() => setState(() {
    _revision = AppScope.of(context).notificationRevision;
    _future = AppScope.of(context).loadNotifications();
  });

  Future<void> _markAllRead() async {
    try {
      await AppScope.of(context).markAllNotificationsRead();
      _reload();
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  Future<void> _open(AppNotification item) async {
    try {
      if (!item.isRead) {
        await AppScope.of(context).markNotificationRead(item.publicId);
      }
      if (!mounted) return;
      final opened = await openNotificationTarget(
        context,
        entityType: item.entityType,
        entityPublicId: item.entityPublicId,
        category: item.category,
      );
      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('لا توجد وجهة مباشرة؛ راجع تفاصيل التنبيه هنا.'),
          ),
        );
      }
      if (mounted) _reload();
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  List<AppNotification> _items(NotificationFeed feed) => feed.items
      .where((item) {
        return switch (_filter) {
          'unread' => !item.isRead,
          'mandatory' => item.isMandatoryInApp,
          _ => true,
        };
      })
      .toList(growable: false);

  @override
  Widget build(BuildContext context) => AdminWorkspaceScaffold(
    active: AdminDestination.notifications,
    appBar: AppBar(
      title: const Text('تنبيهات الإدارة'),
      actions: [
        IconButton(
          tooltip: 'إعدادات إشعاراتي',
          icon: const Icon(Icons.tune_rounded),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const NotificationPreferencesPage(),
            ),
          ),
        ),
        TextButton(onPressed: _markAllRead, child: const Text('تعليم الكل')),
      ],
    ),
    body: FutureBuilder<NotificationFeed>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          final error = snapshot.error is ApiException
              ? snapshot.error as ApiException
              : null;
          return _FailureState(
            message: error?.message ?? 'تعذر تحميل تنبيهات الإدارة.',
            requestId: error?.requestId,
            onRetry: _reload,
          );
        }
        final items = _items(
          snapshot.data ?? const NotificationFeed(items: [], unreadCount: 0),
        );
        return RefreshIndicator(
          onRefresh: () async => _reload(),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 30),
            children: [
              Card(
                color: Theme.of(context).colorScheme.primaryContainer
                    .withValues(alpha: .5),
                child: const Padding(
                  padding: EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Icon(Icons.admin_panel_settings_outlined),
                      SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          'التنبيهات الحرجة تبقى ظاهرة داخل التطبيق لجميع المديرين النشطين. يمكنك ضبط Push والتنبيهات غير الحرجة من الإعدادات.',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 13),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _filterChip('all', 'الكل'),
                  _filterChip('unread', 'غير مقروءة'),
                  _filterChip('mandatory', 'قرارات عاجلة'),
                ],
              ),
              const SizedBox(height: 13),
              if (items.isEmpty)
                const _EmptyAlerts()
              else
                ...items.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 9),
                    child: _AdminAlertCard(
                      item: item,
                      onTap: () => _open(item),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    ),
  );

  Widget _filterChip(String value, String label) => ChoiceChip(
    label: Text(label),
    selected: _filter == value,
    onSelected: (_) => setState(() => _filter = value),
  );
}

final class _AdminAlertCard extends StatelessWidget {
  const _AdminAlertCard({required this.item, required this.onTap});

  final AppNotification item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    color: item.isRead
        ? null
        : Theme.of(context).colorScheme.primaryContainer.withValues(alpha: .34),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: item.isMandatoryInApp
                  ? Theme.of(context).colorScheme.errorContainer
                  : Theme.of(context).colorScheme.secondaryContainer,
              child: Icon(
                _icon(item.category),
                color: item.isMandatoryInApp
                    ? Theme.of(context).colorScheme.error
                    : Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                      if (!item.isRead)
                        const Icon(
                          Icons.circle,
                          size: 9,
                          color: Color(0xFF1976D2),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(item.body),
                  if (item.isMandatoryInApp) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'قرار إداري مهم',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onErrorContainer,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_left_rounded),
          ],
        ),
      ),
    ),
  );
}

IconData _icon(String category) => switch (category) {
  'payments' => Icons.payments_outlined,
  'wallet' => Icons.account_balance_wallet_outlined,
  'marketplace' => Icons.gavel_outlined,
  'store' => Icons.storefront_outlined,
  'support' => Icons.support_agent_outlined,
  'delivery' => Icons.local_shipping_outlined,
  _ => Icons.notifications_active_outlined,
};

final class _EmptyAlerts extends StatelessWidget {
  const _EmptyAlerts();

  @override
  Widget build(BuildContext context) => const Card(
    child: Padding(
      padding: EdgeInsets.all(30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.notifications_none_rounded, size: 48),
          SizedBox(height: 10),
          Text('لا توجد تنبيهات مطابقة'),
          SizedBox(height: 4),
          Text(
            'ستظهر هنا طلبات التوثيق والدفعات والسحب وحملات التجار والقرارات الأخرى.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}

final class _FailureState extends StatelessWidget {
  const _FailureState({
    required this.message,
    required this.requestId,
    required this.onRetry,
  });

  final String message;
  final String? requestId;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded, size: 42),
              const SizedBox(height: 10),
              Text(message, textAlign: TextAlign.center),
              if (requestId?.isNotEmpty == true) ...[
                const SizedBox(height: 6),
                Text('رمز المتابعة: $requestId'),
              ],
              const SizedBox(height: 13),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
