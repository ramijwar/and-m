import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/app_scope.dart';
import '../../../core/media/cached_media_image.dart';
import '../../../core/media/image_upload_policy.dart';
import '../../../core/network/api_exception.dart';
import 'admin_marketplace_settings_page.dart';
import 'admin_navigation.dart';

/// Dedicated moderation workspace. It is intentionally separate from catalog
/// settings so a paused/rejected ad is manageable without hunting through the
/// dashboard or a generic queue.
final class AdminMarketplaceListingsPage extends StatefulWidget {
  const AdminMarketplaceListingsPage({super.key});

  @override
  State<AdminMarketplaceListingsPage> createState() =>
      _AdminMarketplaceListingsPageState();
}

final class _AdminMarketplaceListingsPageState
    extends State<AdminMarketplaceListingsPage> {
  Future<List<Map<String, dynamic>>>? _future;
  String _status = '';
  String _search = '';
  String? _working;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reload();
  }

  void _reload() => setState(() => _future = AppScope.of(context)
      .loadAdminMarketplaceListings(status: _status, search: _search));

  Future<void> _run(
    String id,
    Future<void> Function() action,
    String success,
  ) async {
    setState(() => _working = id);
    try {
      await action();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(success)));
      _reload();
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _working = null);
    }
  }

  Future<void> _delete(Map<String, dynamic> item) async {
    final id = item['public_id'] as String? ?? '';
    if (id.isEmpty) return;
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('حذف الإعلان من العرض'),
            content: const Text(
              'الحذف منطقي: ستبقى الصفقة والسجل التدقيقي محفوظين، ولن يظهر الإعلان للناس.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('إلغاء'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('حذف منطقي'),
              ),
            ],
          ),
        ) ??
        false;
    if (confirmed) {
      await _run(
        'delete-$id',
        () => AppScope.of(context).adminDeleteListing(id),
        'تم حذف الإعلان من العرض.',
      );
    }
  }

  Future<void> _edit(Map<String, dynamic> item) async {
    final id = item['public_id'] as String? ?? '';
    if (id.isEmpty) return;
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => AdminMarketplaceListingEditorPage(listing: item),
      ),
    );
    if (saved == true && mounted) _reload();
  }

  void _details(Map<String, dynamic> item) {
    const labels = <String, String>{
      'title': 'العنوان',
      'description': 'الوصف',
      'seller_name': 'البائع',
      'category_name': 'القسم',
      'price_amount': 'السعر',
      'currency_code': 'العملة',
      'listing_status': 'الحالة',
      'item_condition': 'الحالة',
      'fulfillment_method': 'التسليم',
      'is_negotiable': 'قابل للتفاوض',
      'city': 'المدينة',
      'district': 'المنطقة',
      'address_text': 'العنوان',
      'phone': 'رقم التواصل',
      'public_id': 'المعرف',
      'created_at': 'تاريخ الإنشاء',
      'updated_at': 'آخر تحديث',
    };
    final rows = item.entries
        .where((entry) =>
            labels.containsKey(entry.key) && entry.value != null && '${entry.value}'.isNotEmpty)
        .map((entry) => ListTile(
              dense: true,
              title: Text(labels[entry.key]!),
              subtitle: Text('${entry.value}'),
            ))
        .toList(growable: false);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: .58,
          minChildSize: .3,
          maxChildSize: .9,
          builder: (_, controller) => ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
            children: [
              Text(item['title'] as String? ?? 'تفاصيل الإعلان',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              ...rows,
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('إعلانات الحراج'),
          actions: [
            IconButton(
              tooltip: 'سياسات الحراج والمواقع',
              icon: const Icon(Icons.tune_rounded),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => const AdminMarketplaceSettingsPage(),
              )),
            ),
            IconButton(
              tooltip: 'تحديث',
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _working == null ? _reload : null,
            ),
          ],
          bottom: adminControlBottom(context, 'marketplace'),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Column(children: [
                TextField(
                  onChanged: (value) => _search = value,
                  onSubmitted: (_) => _reload(),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search_rounded),
                    hintText: 'ابحث بالعنوان أو الوصف أو اسم البائع',
                    suffixIcon: IconButton(
                      tooltip: 'بحث',
                      icon: const Icon(Icons.arrow_forward_rounded),
                      onPressed: _reload,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _status,
                  decoration: const InputDecoration(labelText: 'الحالة'),
                  items: const [
                    DropdownMenuItem(value: '', child: Text('كل الحالات')),
                    DropdownMenuItem(value: 'pending_review', child: Text('قيد المراجعة')),
                    DropdownMenuItem(value: 'active', child: Text('نشط')),
                    DropdownMenuItem(value: 'paused', child: Text('موقوف')),
                    DropdownMenuItem(value: 'rejected', child: Text('مرفوض')),
                    DropdownMenuItem(value: 'sold', child: Text('تم البيع')),
                  ],
                  onChanged: (value) {
                    _status = value ?? '';
                    _reload();
                  },
                ),
              ]),
            ),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    final message = snapshot.error is ApiException
                        ? (snapshot.error as ApiException).message
                        : 'تعذر تحميل إعلانات الحراج.';
                    return Center(child: Text(message));
                  }
                  final items = snapshot.data ?? const <Map<String, dynamic>>[];
                  if (items.isEmpty) {
                    return RefreshIndicator(
                      onRefresh: () async => _reload(),
                      child: ListView(children: const [
                        SizedBox(height: 240, child: Center(child: Text('لا توجد إعلانات مطابقة.'))),
                      ]),
                    );
                  }
                  return RefreshIndicator(
                    onRefresh: () async => _reload(),
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) => _ListingCard(
                        item: items[index],
                        busy: _working?.contains(items[index]['public_id'] as String? ?? '--') ?? false,
                        onDetails: () => _details(items[index]),
                        onEdit: () => _edit(items[index]),
                        onDelete: () => _delete(items[index]),
                        onStatus: (status, label) => _run(
                          'status-${items[index]['public_id']}',
                          () => AppScope.of(context).updateListingReview(
                            items[index]['public_id'] as String,
                            status,
                          ),
                          label,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      );
}

final class _ListingCard extends StatelessWidget {
  const _ListingCard({
    required this.item,
    required this.busy,
    required this.onDetails,
    required this.onEdit,
    required this.onDelete,
    required this.onStatus,
  });
  final Map<String, dynamic> item;
  final bool busy;
  final VoidCallback onDetails;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final void Function(String status, String success) onStatus;

  String _status(String value) => switch (value) {
        'pending_review' => 'قيد المراجعة',
        'active' => 'نشط',
        'paused' => 'موقوف',
        'rejected' => 'مرفوض',
        'sold' => 'تم البيع',
        'reserved' => 'محجوز',
        _ => value,
      };

  @override
  Widget build(BuildContext context) {
    final status = item['listing_status'] as String? ?? '';
    final media = item['primary_media_public_id'] as String?;
    final actions = <Widget>[
      OutlinedButton.icon(
        onPressed: busy ? null : onDetails,
        icon: const Icon(Icons.visibility_outlined),
        label: const Text('تفاصيل'),
      ),
      OutlinedButton.icon(
        onPressed: busy ? null : onEdit,
        icon: const Icon(Icons.edit_outlined),
        label: const Text('تعديل'),
      ),
    ];
    if (status == 'pending_review') {
      actions.add(FilledButton(
        onPressed: busy ? null : () => onStatus('active', 'تم اعتماد الإعلان.'),
        child: const Text('اعتماد'),
      ));
      actions.add(TextButton(
        onPressed: busy ? null : () => onStatus('rejected', 'تم رفض الإعلان.'),
        child: const Text('رفض'),
      ));
    } else if (status == 'active') {
      actions.add(TextButton(
        onPressed: busy ? null : () => onStatus('paused', 'تم إيقاف الإعلان.'),
        child: const Text('إيقاف'),
      ));
    } else if (status == 'paused' || status == 'rejected') {
      actions.add(FilledButton.icon(
        onPressed: busy ? null : () => onStatus('active', 'تم تشغيل الإعلان.'),
        icon: const Icon(Icons.play_arrow_rounded),
        label: const Text('تشغيل'),
      ));
    }
    actions.add(TextButton(
      onPressed: busy ? null : onDelete,
      child: const Text('حذف'),
    ));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 62,
                height: 62,
                child: media == null || media.isEmpty
                    ? ColoredBox(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        child: const Icon(Icons.image_not_supported_outlined),
                      )
                    : CachedMediaImage(mediaPublicId: media, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(width: 11),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item['title'] as String? ?? 'إعلان حراج',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 3),
              Text('${item['seller_name'] ?? 'بائع'} · ${item['category_name'] ?? 'بدون قسم'}'),
              Text('${item['price_amount'] ?? '—'} ${item['currency_code'] ?? ''} · ${item['city'] ?? ''}',
                  style: Theme.of(context).textTheme.bodySmall),
            ])),
            Chip(label: Text(_status(status))),
          ]),
          const SizedBox(height: 10),
          if (busy) const LinearProgressIndicator() else Wrap(spacing: 7, runSpacing: 7, children: actions),
        ]),
      ),
    );
  }
}

final class AdminMarketplaceListingEditorPage extends StatefulWidget {
  const AdminMarketplaceListingEditorPage({super.key, required this.listing});
  final Map<String, dynamic> listing;

  @override
  State<AdminMarketplaceListingEditorPage> createState() =>
      _AdminMarketplaceListingEditorPageState();
}

final class _AdminMarketplaceListingEditorPageState
    extends State<AdminMarketplaceListingEditorPage> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _price;
  late final TextEditingController _city;
  late final TextEditingController _district;
  late final TextEditingController _address;
  late final TextEditingController _phone;
  late String _currency;
  late String _condition;
  late String _fulfillment;
  late bool _negotiable;
  bool _saving = false;
  XFile? _image;

  @override
  void initState() {
    super.initState();
    final item = widget.listing;
    _title = TextEditingController(text: item['title'] as String? ?? '');
    _description = TextEditingController(text: item['description'] as String? ?? '');
    _price = TextEditingController(text: '${item['price_amount'] ?? ''}');
    _city = TextEditingController(text: item['city'] as String? ?? '');
    _district = TextEditingController(text: item['district'] as String? ?? '');
    _address = TextEditingController(text: item['address_text'] as String? ?? '');
    _phone = TextEditingController(text: item['phone'] as String? ?? '');
    _currency = item['currency_code'] as String? ?? 'USD';
    _condition = const ['new', 'used', 'refurbished', 'not_applicable'].contains(item['item_condition'])
        ? item['item_condition'] as String
        : 'used';
    _fulfillment = const ['pickup', 'delivery', 'both'].contains(item['fulfillment_method'])
        ? item['fulfillment_method'] as String
        : 'both';
    _negotiable = item['is_negotiable'] == true || item['is_negotiable'] == 1;
  }

  @override
  void dispose() {
    for (final controller in [_title, _description, _price, _city, _district, _address, _phone]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !(_form.currentState?.validate() ?? false)) return;
    final id = widget.listing['public_id'] as String? ?? '';
    if (id.isEmpty) return;
    setState(() => _saving = true);
    try {
      await AppScope.of(context).updateAdminMarketplaceListing(
        listingId: id,
        values: {
          'title': _title.text.trim(),
          'description': _description.text.trim(),
          'price_amount': _price.text.trim().isEmpty ? null : _price.text.trim(),
          'currency_code': _currency,
          'city': _city.text.trim(),
          'district': _district.text.trim(),
          'address_text': _address.text.trim(),
          'phone': _phone.text.trim(),
          'item_condition': _condition,
          'fulfillment_method': _fulfillment,
          'is_negotiable': _negotiable,
        },
      );
      if (_image != null) {
        await AppScope.of(context)
            .attachAdminMarketplaceListingMedia(listingId: id, image: _image!);
      }
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    } on FormatException catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('تعديل إعلان الحراج')),
        body: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text('تُسجّل التعديلات باسم المدير، ولا تغيّر ملكية الإعلان أو سجل صفقتِه.'),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: () async {
                  final image = await ImageUploadPolicy.pick(ImageSource.gallery);
                  if (image != null && mounted) setState(() => _image = image);
                },
                icon: Icon(_image == null ? Icons.add_photo_alternate_outlined : Icons.check_circle_outline_rounded),
                label: Text(_image == null ? 'استبدال الصورة الرئيسية (اختياري)' : 'تم اختيار صورة جديدة'),
              ),
              const SizedBox(height: 10),
              TextFormField(controller: _title, maxLength: 180, decoration: const InputDecoration(labelText: 'العنوان *'), validator: (value) => (value?.trim().length ?? 0) < 4 ? 'أدخل عنواناً من 4 أحرف على الأقل.' : null),
              const SizedBox(height: 8),
              TextFormField(controller: _description, minLines: 4, maxLines: 8, maxLength: 5000, decoration: const InputDecoration(labelText: 'الوصف *'), validator: (value) => (value?.trim().length ?? 0) < 10 ? 'أدخل وصفاً واضحاً.' : null),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: TextFormField(controller: _price, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'السعر'), validator: (value) => value == null || value.trim().isEmpty || num.tryParse(value.trim()) != null ? null : 'سعر غير صحيح.')),
                const SizedBox(width: 10),
                Expanded(child: DropdownButtonFormField<String>(value: _currency, decoration: const InputDecoration(labelText: 'العملة'), items: const [DropdownMenuItem(value: 'USD', child: Text('USD')), DropdownMenuItem(value: 'SYP', child: Text('ل.س'))], onChanged: (value) => setState(() => _currency = value ?? _currency))),
              ]),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(value: _condition, decoration: const InputDecoration(labelText: 'حالة السلعة'), items: const [DropdownMenuItem(value: 'new', child: Text('جديد')), DropdownMenuItem(value: 'used', child: Text('مستعمل')), DropdownMenuItem(value: 'refurbished', child: Text('مجدّد')), DropdownMenuItem(value: 'not_applicable', child: Text('لا تنطبق'))], onChanged: (value) => setState(() => _condition = value ?? _condition)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(value: _fulfillment, decoration: const InputDecoration(labelText: 'طريقة التسليم'), items: const [DropdownMenuItem(value: 'pickup', child: Text('استلام مباشر')), DropdownMenuItem(value: 'delivery', child: Text('توصيل')), DropdownMenuItem(value: 'both', child: Text('توصيل أو استلام'))], onChanged: (value) => setState(() => _fulfillment = value ?? _fulfillment)),
              SwitchListTile.adaptive(contentPadding: EdgeInsets.zero, title: const Text('السعر قابل للتفاوض'), value: _negotiable, onChanged: (value) => setState(() => _negotiable = value)),
              TextFormField(controller: _city, maxLength: 120, decoration: const InputDecoration(labelText: 'المدينة')),
              const SizedBox(height: 8),
              if (_city.text.trim().isNotEmpty) TextFormField(controller: _district, maxLength: 120, decoration: const InputDecoration(labelText: 'المنطقة / الحي')),
              if (_fulfillment != 'pickup') ...[
                const SizedBox(height: 8),
                TextFormField(controller: _address, maxLength: 255, decoration: const InputDecoration(labelText: 'العنوان التفصيلي')),
              ],
              const SizedBox(height: 8),
              TextFormField(controller: _phone, keyboardType: TextInputType.phone, maxLength: 24, decoration: const InputDecoration(labelText: 'رقم التواصل')),
              const SizedBox(height: 20),
              FilledButton.icon(onPressed: _saving ? null : _save, icon: const Icon(Icons.save_outlined), label: Text(_saving ? 'جارٍ الحفظ…' : 'حفظ التعديلات')),
            ],
          ),
        ),
      );
}
