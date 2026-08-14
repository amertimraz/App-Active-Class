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
class ContactPickerService {
  static Future<String?> pickPhoneNumber(BuildContext context) async {
    try {
      final granted = await FlutterContacts.requestPermission(readonly: true);
      if (!granted) return null;
      if (!context.mounted) return null;

      final selected = await showModalBottomSheet<Contact>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => const _ContactPickerSheet(),
      );

      if (selected == null || selected.phones.isEmpty) return null;
      return _normalize(selected.phones.first.number);
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

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    final contacts = await FlutterContacts.getContacts(withProperties: true);
    final withPhones = contacts.where((c) => c.phones.isNotEmpty).toList()
      ..sort((a, b) =>
          a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));

    if (!mounted) return;
    setState(() {
      _contacts = withPhones;
      _filtered = withPhones;
      _loading = false;
    });
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
                        return ListTile(
                          leading: CircleAvatar(
                            child: Text(c.displayName.isNotEmpty
                                ? c.displayName[0]
                                : '؟'),
                          ),
                          title: Text(c.displayName),
                          subtitle: Text(c.phones.first.number),
                          onTap: () => Navigator.of(context).pop(c),
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
