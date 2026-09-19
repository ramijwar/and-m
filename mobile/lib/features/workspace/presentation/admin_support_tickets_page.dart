import 'package:flutter/material.dart';

import '../../../app/app_scope.dart';
import '../../../core/network/api_exception.dart';
import 'admin_navigation.dart';

/// Manager-only support queue. Unlike the customer support screen it never
/// creates tickets; every control is a reply, a status transition, or closing.
final class AdminSupportTicketsPage extends StatefulWidget {
  const AdminSupportTicketsPage({super.key});

  @override
  State<AdminSupportTicketsPage> createState() =>
      _AdminSupportTicketsPageState();
}

final class _AdminSupportTicketsPageState
    extends State<AdminSupportTicketsPage> {
  Future<List<Map<String, dynamic>>>? _future;
  bool _ready = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_ready) {
      _ready = true;
      _reload();
    }
  }

  void _reload() =>
      setState(() => _future = AppScope.of(context).loadAdminSupportTickets());

  String _status(String status) => switch (status) {
    'open' => 'مفتوحة',
    'in_progress' => 'قيد المعالجة',
    'resolved' => 'تم الحل',
    'closed' => 'مغلقة',
    _ => status,
  };

  @override
  Widget build(BuildContext context) => AdminWorkspaceScaffold(
    active: AdminDestination.support,
    appBar: AppBar(
      title: const Text('طابور دعم العملاء'),
      actions: [
        IconButton(
          tooltip: 'تحديث الطابور',
          onPressed: _reload,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      bottom: adminControlBottom(context, 'support'),
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
              : 'تعذر تحميل طابور الدعم.';
          return Center(child: Text(message));
        }
        final tickets = snapshot.data ?? const <Map<String, dynamic>>[];
        final open = tickets
            .where(
              (ticket) =>
                  !['resolved', 'closed'].contains(ticket['ticket_status']),
            )
            .length;
        return RefreshIndicator(
          onRefresh: () async => _reload(),
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            itemCount: tickets.length + 1,
            separatorBuilder: (_, _) => const SizedBox(height: 9),
            itemBuilder: (context, index) {
              if (index == 0) {
                return Card(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(15),
                    child: Row(
                      children: [
                        const Icon(Icons.support_agent_rounded),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'متابعة التذاكر',
                                style: TextStyle(fontWeight: FontWeight.w900),
                              ),
                              Text(
                                '$open تذكرة تحتاج متابعة. تُنشأ إشعارات المدير تلقائياً عند وصول تذكرة أو رد جديد.',
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
              final ticket = tickets[index - 1];
              final id = ticket['public_id'] as String? ?? '';
              return Card(
                child: ListTile(
                  leading: Icon(
                    Icons.forum_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  title: Text(
                    ticket['subject'] as String? ?? 'تذكرة دعم',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  subtitle: Text(
                    '${ticket['requester_name'] ?? 'عميل'} · ${_status(ticket['ticket_status'] as String? ?? '')}\n${ticket['message_count'] ?? 0} رسالة',
                  ),
                  isThreeLine: true,
                  trailing: const Icon(Icons.chevron_left_rounded),
                  onTap: id.isEmpty
                      ? null
                      : () async {
                          final changed = await Navigator.of(context)
                              .push<bool>(
                                MaterialPageRoute<bool>(
                                  builder: (_) => AdminSupportTicketDetailPage(
                                    ticketId: id,
                                    subject:
                                        ticket['subject'] as String? ??
                                        'تذكرة دعم',
                                  ),
                                ),
                              );
                          if (changed == true && mounted) _reload();
                        },
                ),
              );
            },
          ),
        );
      },
    ),
  );
}

final class AdminSupportTicketDetailPage extends StatefulWidget {
  const AdminSupportTicketDetailPage({
    super.key,
    required this.ticketId,
    required this.subject,
  });
  final String ticketId;
  final String subject;

  @override
  State<AdminSupportTicketDetailPage> createState() =>
      _AdminSupportTicketDetailPageState();
}

final class _AdminSupportTicketDetailPageState
    extends State<AdminSupportTicketDetailPage> {
  Future<Map<String, dynamic>>? _future;
  final _reply = TextEditingController();
  String _status = 'open';
  bool _statusInitialized = false;
  bool _saving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= AppScope.of(context).loadAdminSupportTicket(widget.ticketId);
  }

  @override
  void dispose() {
    _reply.dispose();
    super.dispose();
  }

  void _reload() => setState(
    () =>
        _future = AppScope.of(context).loadAdminSupportTicket(widget.ticketId),
  );

  Future<void> _save({bool sendReply = false}) async {
    final reply = _reply.text.trim();
    if (sendReply && reply.isEmpty) return;
    if (_saving) return;
    setState(() => _saving = true);
    try {
      if (reply.isNotEmpty) {
        await AppScope.of(context)
            .replyAdminSupportTicket(ticketId: widget.ticketId, body: reply);
      }
      await AppScope.of(context)
          .updateAdminSupportTicket(ticketId: widget.ticketId, status: _status);
      _reply.clear();
      _reload();
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حفظ متابعة التذكرة وإشعار العميل.')),
        );
    } on ApiException catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.subject),
      actions: [
        IconButton(onPressed: _reload, icon: const Icon(Icons.refresh_rounded)),
      ],
    ),
    body: Column(
      children: [
        Expanded(
          child: FutureBuilder<Map<String, dynamic>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done)
                return const Center(child: CircularProgressIndicator());
              if (!snapshot.hasData)
                return const Center(child: Text('تعذر تحميل المحادثة.'));
              final ticket = snapshot.data!;
              if (!_statusInitialized) {
                _status = ticket['ticket_status'] as String? ?? _status;
                _statusInitialized = true;
              }
              final messages = (ticket['messages'] as List? ?? const [])
                  .whereType<Map>()
                  .map((item) => Map<String, dynamic>.from(item))
                  .toList();
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(13),
                      child: DropdownButtonFormField<String>(
                        value: _status,
                        decoration: const InputDecoration(
                          labelText: 'حالة التذكرة',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'open',
                            child: Text('مفتوحة'),
                          ),
                          DropdownMenuItem(
                            value: 'in_progress',
                            child: Text('قيد المعالجة'),
                          ),
                          DropdownMenuItem(
                            value: 'resolved',
                            child: Text('تم الحل'),
                          ),
                          DropdownMenuItem(
                            value: 'closed',
                            child: Text('مغلقة'),
                          ),
                        ],
                        onChanged: (value) =>
                            setState(() => _status = value ?? _status),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...messages.map((message) {
                    final admin =
                        message['sender_is_admin'] == true ||
                        message['sender_is_admin'] == 1;
                    return Align(
                      alignment: admin
                          ? AlignmentDirectional.centerStart
                          : AlignmentDirectional.centerEnd,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        constraints: const BoxConstraints(maxWidth: 480),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: admin
                              ? Theme.of(context).colorScheme.primaryContainer
                              : Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              admin
                                  ? 'فريق الدعم'
                                  : (message['sender_name'] as String? ??
                                        'العميل'),
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(message['body'] as String? ?? ''),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              );
            },
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Column(
              children: [
                TextField(
                  controller: _reply,
                  minLines: 2,
                  maxLines: 5,
                  maxLength: 5000,
                  decoration: const InputDecoration(
                    hintText: 'اكتب رد الإدارة إلى العميل…',
                  ),
                ),
                const SizedBox(height: 7),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _saving ? null : () => _save(),
                        child: const Text('حفظ الحالة'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _saving
                            ? null
                            : () => _save(sendReply: true),
                        icon: const Icon(Icons.send_rounded),
                        label: Text(_saving ? 'جارٍ الحفظ…' : 'إرسال الرد'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
