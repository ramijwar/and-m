import 'package:flutter/material.dart';

import '../../../app/app_scope.dart';
import '../../../core/network/api_exception.dart';

/// Merchant-only operational queue. The server owns eligibility for each action
/// and returns [allowed_actions], preventing a stale client from skipping a
/// fulfilment stage.
final class MerchantOrdersPage extends StatefulWidget {
  const MerchantOrdersPage({super.key});

  @override
  State<MerchantOrdersPage> createState() => _MerchantOrdersPageState();
}

final class _MerchantOrdersPageState extends State<MerchantOrdersPage> {
  late Future<List<Map<String, dynamic>>> _future;
  bool _loaded = false;
  String? _workingOrderId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loaded) {
      _loaded = true;
      _future = AppScope.of(context).loadMerchantOrders();
    }
  }

  void _reload() =>
      setState(() => _future = AppScope.of(context).loadMerchantOrders());

  Future<void> _transition(Map<String, dynamic> order, String action) async {
    final orderId = order['public_id'] as String? ?? '';
    if (orderId.isEmpty || _workingOrderId != null) return;
    setState(() => _workingOrderId = orderId);
    try {
      await AppScope.of(context)
          .transitionMerchantOrder(orderId: orderId, action: action);
      if (!mounted) return;
      _reload();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_actionSuccess(action, order['fulfillment_type'])),
        ),
      );
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _workingOrderId = null);
    }
  }

  Future<void> _cancel(Map<String, dynamic> order) async {
    final orderId = order['public_id'] as String? ?? '';
    if (orderId.isEmpty || _workingOrderId != null) return;
    final reasonController = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('إلغاء الطلب'),
        content: TextField(
          controller: reasonController,
          autofocus: true,
          minLines: 2,
          maxLines: 4,
          maxLength: 1000,
          decoration: const InputDecoration(
            labelText: 'سبب الإلغاء',
            hintText: 'اكتب سبباً واضحاً للعميل.',
            alignLabelWithHint: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('تراجع'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(reasonController.text.trim()),
            child: const Text('تأكيد الإلغاء'),
          ),
        ],
      ),
    );
    reasonController.dispose();
    if (!mounted || reason == null) return;
    if (reason.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اكتب سبب الإلغاء من حرفين على الأقل.')),
      );
      return;
    }

    setState(() => _workingOrderId = orderId);
    try {
      await AppScope.of(context)
          .cancelMerchantOrder(orderId: orderId, reason: reason);
      if (!mounted) return;
      _reload();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إلغاء الطلب وإعادة المخزون المؤهل.')),
      );
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _workingOrderId = null);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('طلبات متجري'),
      actions: [
        IconButton(
          tooltip: 'تحديث',
          onPressed: _workingOrderId == null ? _reload : null,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
    ),
    body: FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          final message = snapshot.error is ApiException
              ? (snapshot.error as ApiException).message
              : 'تعذر تحميل طلبات المتجر.';
          return _MerchantOrdersState(
            icon: Icons.cloud_off_rounded,
            message: message,
            action: _reload,
            actionLabel: 'إعادة المحاولة',
          );
        }
        final orders = snapshot.data ?? const <Map<String, dynamic>>[];
        if (orders.isEmpty) {
          return _MerchantOrdersState(
            icon: Icons.receipt_long_outlined,
            message: 'لا توجد طلبات لهذا المتجر بعد.',
            action: _reload,
            actionLabel: 'تحديث',
          );
        }
        return RefreshIndicator(
          onRefresh: () async => _reload(),
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 30),
            itemCount: orders.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (_, index) => _MerchantOrderCard(
              order: orders[index],
              working: _workingOrderId == orders[index]['public_id'],
              onTransition: (action) => _transition(orders[index], action),
              onCancel: () => _cancel(orders[index]),
            ),
          ),
        );
      },
    ),
  );

  String _actionSuccess(String action, Object? fulfillmentType) =>
      switch (action) {
        'accept' => 'تم قبول الطلب وبدأت دورة التجهيز.',
        'prepare' => 'تم تحديث الطلب إلى قيد التجهيز.',
        'ready' =>
          fulfillmentType == 'delivery'
              ? 'أصبح الطلب جاهزاً وتمت إتاحته لعمال التوصيل.'
              : 'أصبح الطلب جاهزاً لاستلام العميل.',
        _ => 'تم تحديث الطلب.',
      };
}

final class _MerchantOrderCard extends StatelessWidget {
  const _MerchantOrderCard({
    required this.order,
    required this.working,
    required this.onTransition,
    required this.onCancel,
  });

  final Map<String, dynamic> order;
  final bool working;
  final ValueChanged<String> onTransition;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final status = order['order_status'] as String? ?? '';
    final paymentStatus = order['payment_status'] as String? ?? '';
    final fulfillment = order['fulfillment_type'] as String? ?? 'delivery';
    final actions = ((order['allowed_actions'] as List?) ?? const <Object>[])
        .whereType<String>()
        .toList(growable: false);
    final address = order['delivery_address'] is Map
        ? Map<String, dynamic>.from(order['delivery_address'] as Map)
        : const <String, dynamic>{};
    final addressText = [
      address['city'],
      address['district'],
      address['address_line1'],
      address['address_line2'],
    ].whereType<String>().where((value) => value.trim().isNotEmpty).join('، ');
    final statusMeta = _statusMeta(status);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.receipt_long_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    order['order_number'] as String? ?? 'طلب متجر',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                Chip(label: Text(statusMeta.$1)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${order['customer_name'] ?? 'عميل'} · ${order['item_count'] ?? 0} عناصر · ${order['total_amount'] ?? 0} ${order['currency_code'] ?? ''}',
            ),
            const SizedBox(height: 4),
            Text(
              '${fulfillment == 'delivery' ? 'توصيل' : 'استلام مباشر'} · ${paymentStatus == 'paid'
                  ? 'مدفوع'
                  : paymentStatus == 'under_review'
                  ? 'الدفع قيد المراجعة'
                  : 'الدفع عند الاستلام'}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (addressText.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 7),
                child: Text('عنوان التوصيل: $addressText'),
              ),
            if ((order['customer_note'] as String?)?.trim().isNotEmpty == true)
              Padding(
                padding: const EdgeInsets.only(top: 7),
                child: Text('ملاحظة العميل: ${order['customer_note']}'),
              ),
            if (working)
              const Padding(
                padding: EdgeInsets.only(top: 14),
                child: Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: SizedBox.square(
                    dimension: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else if (actions.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ...actions
                        .where((action) => action != 'cancel')
                        .map(
                          (action) => FilledButton(
                            onPressed: () => onTransition(action),
                            child: Text(_actionTitle(action)),
                          ),
                        ),
                    if (actions.contains('cancel'))
                      OutlinedButton(
                        onPressed: onCancel,
                        child: const Text('إلغاء الطلب'),
                      ),
                  ],
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(top: 11),
                child: Text(
                  statusMeta.$2,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
          ],
        ),
      ),
    );
  }

  (String, String) _statusMeta(String status) => switch (status) {
    'awaiting_payment' => ('بانتظار الدفع', 'ينتظر العميل إرسال إشعار الدفع.'),
    'payment_review' => (
      'الدفع قيد المراجعة',
      'راجع إشعار الدفع من صفحة الدفعات.',
    ),
    'payment_rejected' => ('إشعار مرفوض', 'ينتظر العميل إرسال إشعار جديد.'),
    'payment_verified' => ('جاهز للقبول', 'اقبل الطلب لبدء التجهيز.'),
    'merchant_accepted' => ('مقبول', 'ابدأ تجهيز الطلب.'),
    'preparing' => ('قيد التجهيز', 'أكد الجاهزية بعد إتمام التحضير.'),
    'ready_for_delivery' => (
      'بانتظار عامل توصيل',
      'أُتيحت المهمة لعمال التوصيل.',
    ),
    'ready_for_pickup' => ('جاهز للاستلام', 'ينتظر تأكيد العميل للاستلام.'),
    'assigned_to_courier' => ('مع عامل التوصيل', 'تم قبول مهمة التوصيل.'),
    'picked_up' => ('تم الاستلام', 'عامل التوصيل يتابع التسليم.'),
    'out_for_delivery' ||
    'en_route_delivery' => ('في الطريق للعميل', 'عامل التوصيل في الطريق.'),
    'delivered' => ('تم التسليم', 'ينتظر تأكيد العميل للاستلام.'),
    'completed' => ('مكتمل', 'اكتملت دورة الطلب.'),
    'cancelled' => ('ملغى', 'تم إلغاء الطلب.'),
    'disputed' => ('نزاع', 'الطلب قيد معالجة الإدارة.'),
    _ => ('تحديث طلب', 'لا يوجد إجراء متاح في هذه المرحلة.'),
  };

  String _actionTitle(String action) => switch (action) {
    'accept' => 'قبول الطلب',
    'prepare' => 'بدء التجهيز',
    'ready' => 'تأكيد الجاهزية',
    _ => 'تحديث',
  };
}

final class _MerchantOrdersState extends StatelessWidget {
  const _MerchantOrdersState({
    required this.icon,
    required this.message,
    required this.action,
    required this.actionLabel,
  });

  final IconData icon;
  final String message;
  final VoidCallback action;
  final String actionLabel;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 52, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 14),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: action,
            icon: const Icon(Icons.refresh_rounded),
            label: Text(actionLabel),
          ),
        ],
      ),
    ),
  );
}
