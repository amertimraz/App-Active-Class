// lib/services/contact_picker_service.dart
import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

/// يطلب إذن جهات الاتصال ويعرض قائمة بحث داخل التطبيق نفسه لاختيار
/// جهة اتصال، ويرجّع رقم الهاتف بصيغة محلية مصرية (01xxxxxxxxx).
///
/// كنا بنستخدم منتقي جهات الاتصال الخارجي بتاع أندرويد (openExternalPick)،
/// لكنه سبب كراش فوري على بعض الأجهزة (كراش أصلي/native بيتخطى أي
/// try/catch في Dart). القائمة الداخلية دي أبطأ شوية في تحميل جهات
/// الاتصال أول مرة لكنها مستقرة وموثوقة أكتر، فالشيت بيتفتح فورًا
/// بمؤشر تحميل بدل ما نستنى قبل ما نوري أي حاجة للمستخدم.
///
/// التحميل الأولي بيجيب الأسماء بس (من غير أرقام/صور) عشان يبقى سريع
/// حتى مع آلاف جهات الاتصال — رقم الهاتف بيتجاب بس وقت ما المستخدم
/// يدوس على جهة اتصال معيّنة (lookup واحد بسيط بدل تحميل كل التفاصيل
/// لكل جهات الاتصال مقدمًا).
class ContactPickerService {
  static Future<String?> pickPhoneNumber(BuildContext context) async {
    try {
      final granted = await FlutterContacts.requestPermission(readonly: true);
      if (!granted) return null;
      if (!context.mounted) return null;

      return await showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => const _ContactPickerSheet(),
      );
    } catch (_) {
      return null;
    }
  }

  static String _normalize(String raw) {
    var digits = raw.replaceAll(RegExp(r'[^0-9+]'), '');

    if (digits.startsWith('+20')) {
      digits = '0${digits.substring(3)}';
    } else if (digits.startsWith('0020')) {
      digits = '0${digits.substring(4)}';
    } else if (digits.startsWith('20') && digits.length == 12) {
      digits = '0${digits.substring(2)}';
    }

    return digits;
  }
}

class _ContactPickerSheet extends StatefulWidget {
  const _ContactPickerSheet();

  @override
  State<_ContactPickerSheet> createState() => _ContactPickerSheetState();
}

class _ContactPickerSheetState extends State<_ContactPickerSheet> {
  final _searchCtrl = TextEditingController();
  List<Contact> _contacts = [];
  List<Contact> _filtered = [];
  bool _loading = true;
  String? _resolvingId; // id الجهة اللي بنجيب رقمها دلوقتي

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    // من غير withProperties عشان التحميل يبقى فوري — الأرقام بتتجاب
    // بس وقت الاختيار (في _selectContact).
    final contacts = await FlutterContacts.getContacts();
    contacts.sort((a, b) =>
        a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));

    if (!mounted) return;
    setState(() {
      _contacts = contacts;
      _filtered = contacts;
      _loading = false;
    });
  }

  Future<void> _selectContact(Contact c) async {
    if (_resolvingId != null) return;
    setState(() => _resolvingId = c.id);
    final full = await FlutterContacts.getContact(
      c.id,
      withPhoto: false,
      withThumbnail: false,
    );
    if (!mounted) return;
    setState(() => _resolvingId = null);

    if (full == null || full.phones.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يوجد رقم هاتف محفوظ لجهة الاتصال دي')),
      );
      return;
    }
    Navigator.of(context)
        .pop(ContactPickerService._normalize(full.phones.first.number));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearch(String q) {
    final query = q.trim().toLowerCase();
    setState(() {
      _filtered = query.isEmpty
          ? _contacts
          : _contacts
              .where((c) => c.displayName.toLowerCase().contains(query))
              .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.92,
      minChildSize: 0.4,
      expand: false,
      builder: (_, scrollController) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF131D31) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Row(children: [
                const Icon(Icons.contacts_rounded),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text('اختر جهة اتصال',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchCtrl,
                onChanged: _onSearch,
                decoration: InputDecoration(
                  hintText: 'ابحث بالاسم...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _filtered.isEmpty
                  ? const Center(child: Text('مفيش نتائج'))
                  : ListView.builder(
                      controller: scrollController,
                      itemCount: _filtered.length,
                      itemBuilder: (_, i) {
                        final c = _filtered[i];
                        final resolving = _resolvingId == c.id;
                        return ListTile(
                          leading: CircleAvatar(
                            child: Text(c.displayName.isNotEmpty
                                ? c.displayName[0]
                                : '؟'),
                          ),
                          title: Text(c.displayName),
                          trailing: resolving
                              ? const SizedBox(
                                  width: 18, height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2))
                              : null,
                          onTap: () => _selectContact(c),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
