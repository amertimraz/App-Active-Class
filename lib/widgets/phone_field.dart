// lib/widgets/phone_field.dart
//
// spec 033 — حقل رقم ولي الأمر: LTR (مايتعكسش)، تنظيف لحظي عند اللصق/الكتابة،
// ومعاينة «هيتبعت على: ‎+20 …» + تحذير غير معطِّل للرقم الناقص.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:active_class/utils/phone_helper.dart';
import 'package:active_class/widgets/custom_widgets.dart';
import 'package:active_class/config/theme.dart';
import 'package:active_class/config/constants.dart';

/// ينظّف نص الرقم لحظة الكتابة/اللصق عبر PhoneHelper.cleanForStorage.
class PhoneSanitizerFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final cleaned = PhoneHelper.cleanForStorage(newValue.text);
    if (cleaned == newValue.text) return newValue;
    return TextEditingValue(
      text: cleaned,
      selection: TextSelection.collapsed(offset: cleaned.length),
    );
  }
}

class PhoneField extends StatelessWidget {
  final TextEditingController controller;
  final String dialCode;
  final VoidCallback? onContactPick;
  final String label;

  const PhoneField({
    super.key,
    required this.controller,
    required this.dialCode,
    this.onContactPick,
    this.label = '01xxxxxxxxx',
  });

  @override
  Widget build(BuildContext context) {
    final field = CustomTextField(
      controller: controller,
      label: label,
      keyboardType: TextInputType.phone,
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.left,
      inputFormatters: [PhoneSanitizerFormatter()],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (onContactPick == null)
          field
        else
          Row(children: [
            Expanded(child: field),
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(BORDER_RADIUS_NORMAL),
              ),
              child: IconButton(
                tooltip: 'اختيار من جهات الاتصال',
                icon: Icon(Icons.contacts_rounded,
                    color: AppTheme.primaryColor),
                onPressed: onContactPick,
              ),
            ),
          ]),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, value, _) {
            final text = value.text.trim();
            if (text.isEmpty) return const SizedBox.shrink();
            final preview = PhoneHelper.displayIntl(text, dialCode);
            final valid = PhoneHelper.isLikelyValid(text, dialCode);
            return Padding(
              padding: const EdgeInsets.only(top: 6, right: 4, left: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (preview.isNotEmpty)
                    Text('هيتبعت على: $preview',
                        style: TextStyle(
                            fontSize: 11.5,
                            color: Colors.grey.shade500,
                            fontFamily: 'Cairo')),
                  if (!valid)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text('الرقم يبدو غير مكتمل',
                          style: const TextStyle(
                              fontSize: 11.5,
                              color: Color(0xFFF59E0B),
                              fontFamily: 'Cairo',
                              fontWeight: FontWeight.w700)),
                    ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
