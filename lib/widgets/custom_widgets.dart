// lib/widgets/custom_widgets.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:active_class/config/theme.dart';
import 'package:active_class/config/constants.dart';
import 'package:active_class/controllers/settings_controller.dart';
import 'package:active_class/utils/helpers.dart';

/// يعرض مبلغاً مالياً بعملة المستخدم ويتحدث تلقائياً عند تغيير العملة.
class CurrencyText extends StatelessWidget {
  final double? amount;
  final TextStyle? style;
  final TextAlign? textAlign;
  // لو true، بيفصل الرقم عن رمز العملة على سطرين منفصلين بدل ما يتزنقوا
  // في سطر واحد — مفيد في الكروت الضيقة زي إحصائيات المجموعات بالتقارير.
  final bool stacked;

  const CurrencyText(this.amount,
      {super.key, this.style, this.textAlign, this.stacked = false});

  Widget _buildText(String formatted) {
    if (!stacked) {
      return Text(formatted, style: style, textAlign: textAlign);
    }
    final parts = formatted.trim().split(RegExp(r'\s+'));
    final currencyPart = parts.length > 1 ? parts.removeLast() : '';
    final numberPart = parts.join(' ');
    final crossAlign = textAlign == TextAlign.center
        ? CrossAxisAlignment.center
        : CrossAxisAlignment.start;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: crossAlign,
      children: [
        Text(numberPart, style: style, textAlign: textAlign),
        if (currencyPart.isNotEmpty)
          Text(currencyPart,
              style: style?.copyWith(
                  fontSize: (style?.fontSize ?? 13) * 0.8,
                  fontWeight: FontWeight.normal),
              textAlign: textAlign),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    try {
      final settings = Get.find<SettingsController>();
      return Obx(() {
        // قراءة currencyCode.value تجعل GetX يتابع التغييرات
        settings.currencyCode.value;
        return _buildText(FormatHelper.formatCurrency(amount));
      });
    } catch (_) {
      return _buildText(FormatHelper.formatCurrency(amount));
    }
  }
}

/// بطاقة إحصائية مخصصة
class StatsCard extends StatefulWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const StatsCard({
    Key? key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.onTap,
  }) : super(key: key);

  @override
  State<StatsCard> createState() => _StatsCardState();
}

class _StatsCardState extends State<StatsCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: widget.color.withValues(alpha: _isHovered ? 0.4 : 0.15),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: _isHovered ? 0.08 : 0.03),
                blurRadius: _isHovered ? 16 : 10,
                offset: Offset(0, _isHovered ? 6 : 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: widget.color.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(widget.icon, color: widget.color, size: 20),
                  ),
                  Container(
                    width: 24,
                    height: 4,
                    decoration: BoxDecoration(
                      color: widget.color.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.value,
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                      color: isDark ? Colors.white : widget.color,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// حقل إدخال مخصص مع تحقق
class CustomTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final IconData? prefixIcon;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;
  final int maxLines;
  final int minLines;
  final bool obscureText;
  final bool enabled; // تمكين/تعطيل الحقل
  final VoidCallback? onClear;
  final FocusNode? focusNode;
  // spec 033 — اختيارية، صفر تأثير على الاستخدامات القائمة.
  final TextDirection? textDirection;
  final TextAlign textAlign;
  final List<TextInputFormatter>? inputFormatters;

  const CustomTextField({
    Key? key,
    required this.controller,
    required this.label,
    this.hint,
    this.prefixIcon,
    this.keyboardType = TextInputType.text,
    this.validator,
    this.maxLines = 1,
    this.minLines = 1,
    this.obscureText = false,
    this.enabled = true,
    this.onClear,
    this.focusNode,
    this.textDirection,
    this.textAlign = TextAlign.start,
    this.inputFormatters,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      enabled: enabled,
      keyboardType: keyboardType,
      maxLines: maxLines,
      minLines: minLines,
      obscureText: obscureText,
      validator: validator,
      textDirection: textDirection,
      textAlign: textAlign,
      inputFormatters: inputFormatters,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
        suffixIcon: controller.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: onClear ?? () => controller.clear(),
              )
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(BORDER_RADIUS_NORMAL),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: PADDING_NORMAL,
          vertical: 16,
        ),
      ),
    );
  }
}

/// زر مخصص بتأثيرات
class CustomButton extends StatefulWidget {
  final String label;
  final VoidCallback onPressed;
  final bool isLoading;
  final bool isEnabled;
  final IconData? icon;
  final Color? backgroundColor;
  final Color? textColor;
  final double? width;

  const CustomButton({
    Key? key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.isEnabled = true,
    this.icon,
    this.backgroundColor,
    this.textColor,
    this.width,
  }) : super(key: key);

  @override
  State<CustomButton> createState() => _CustomButtonState();
}

class _CustomButtonState extends State<CustomButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final themeColor = widget.backgroundColor ?? AppTheme.primaryColor;
    return AnimatedScale(
      scale: _isPressed ? 0.96 : 1.0,
      duration: const Duration(milliseconds: 100),
      child: SizedBox(
        width: widget.width,
        height: 48,
        child: GestureDetector(
          onTapDown: (_) => setState(() => _isPressed = true),
          onTapUp: (_) => setState(() => _isPressed = false),
          onTapCancel: () => setState(() => _isPressed = false),
          onTap:
              widget.isEnabled && !widget.isLoading ? widget.onPressed : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              gradient: widget.isEnabled
                  ? LinearGradient(
                      colors: [themeColor, themeColor.withValues(alpha: 0.85)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              color: widget.isEnabled ? null : Colors.grey[300],
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                if (widget.isEnabled)
                  BoxShadow(
                    color: themeColor.withValues(alpha: _isPressed ? 0.2 : 0.3),
                    blurRadius: _isPressed ? 8 : 14,
                    offset: Offset(0, _isPressed ? 2 : 5),
                  ),
              ],
            ),
            child: Center(
              child: widget.isLoading
                  ? SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          widget.textColor ?? Colors.white,
                        ),
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.icon != null) ...[
                          Icon(widget.icon,
                              color: widget.textColor ?? Colors.white),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          widget.label,
                          style: TextStyle(
                            color: widget.textColor ?? Colors.white,
                            fontSize: FONT_SIZE_NORMAL,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// قائمة فارغة مع رسالة
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onActionPressed;
  final String? actionLabel;

  const EmptyState({
    Key? key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onActionPressed,
    this.actionLabel,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: PADDING_NORMAL),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 64, color: Colors.grey[400]),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.grey[800],
                    fontWeight: FontWeight.w600,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
              textAlign: TextAlign.center,
            ),
            if (onActionPressed != null && actionLabel != null) ...[
              const SizedBox(height: 32),
              CustomButton(
                label: actionLabel!,
                onPressed: onActionPressed!,
                width: 200,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// شريط البحث المخصص
class CustomSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String hintText;
  final VoidCallback? onClear;

  const CustomSearchBar({
    Key? key,
    required this.controller,
    required this.onChanged,
    this.hintText = 'ابحث...',
    this.onClear,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hintColor = isDark ? Colors.grey[400] : Colors.grey[500];
    return Container(
      constraints: const BoxConstraints(minHeight: 42),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          width: 1,
        ),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textAlignVertical: TextAlignVertical.center,
        style: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 13.5,
          color: isDark ? Colors.white : const Color(0xFF0F172A),
        ),
        decoration: InputDecoration(
          isDense: true,
          hintText: hintText,
          hintStyle: TextStyle(
              fontFamily: 'Cairo', fontSize: 13, color: hintColor),
          prefixIcon: Icon(Icons.search_rounded, size: 19, color: hintColor),
          prefixIconConstraints:
              const BoxConstraints(minWidth: 34, minHeight: 34),
          suffixIcon: controller.text.isEmpty
              ? null
              : InkWell(
                  onTap: onClear ?? () => controller.clear(),
                  child: Icon(Icons.close_rounded, size: 17, color: hintColor),
                ),
          suffixIconConstraints:
              const BoxConstraints(minWidth: 32, minHeight: 32),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        ),
      ),
    );
  }
}

/// بطاقة قائمة مخصصة
class ListCard extends StatefulWidget {
  final String title;
  final String? subtitle;
  final String? trailing;
  final IconData? icon;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final Color? backgroundColor;

  const ListCard({
    Key? key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.icon,
    this.onTap,
    this.onEdit,
    this.onDelete,
    this.backgroundColor,
  }) : super(key: key);

  @override
  State<ListCard> createState() => _ListCardState();
}

class _ListCardState extends State<ListCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: PADDING_NORMAL),
        decoration: BoxDecoration(
          color: widget.backgroundColor ??
              (isDark ? const Color(0xFF1E293B) : Colors.white),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: _isHovered ? 0.08 : 0.03),
              blurRadius: _isHovered ? 12 : 6,
              offset: Offset(0, _isHovered ? 4 : 2),
            ),
          ],
        ),
        child: ListTile(
          onTap: widget.onTap,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          leading: widget.icon != null
              ? Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child:
                      Icon(widget.icon, color: AppTheme.primaryColor, size: 22),
                )
              : null,
          title: Text(
            widget.title,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          subtitle: widget.subtitle != null
              ? Text(
                  widget.subtitle!,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 12,
                    color: isDark ? Colors.grey[400] : const Color(0xFF475569),
                  ),
                )
              : null,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.trailing != null) ...[
                Text(
                  widget.trailing!,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 12,
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              if (widget.onEdit != null || widget.onDelete != null)
                PopupMenuButton(
                  iconColor: isDark ? Colors.white : const Color(0xFF0F172A),
                  itemBuilder: (context) => [
                    if (widget.onEdit != null)
                      PopupMenuItem(
                        onTap: widget.onEdit,
                        child: const Row(
                          children: [
                            Icon(Icons.edit, size: 18),
                            SizedBox(width: 8),
                            Text('تعديل',
                                style: TextStyle(fontFamily: 'Cairo')),
                          ],
                        ),
                      ),
                    if (widget.onDelete != null)
                      PopupMenuItem(
                        onTap: widget.onDelete,
                        child: const Row(
                          children: [
                            Icon(Icons.delete, size: 18, color: Colors.red),
                            SizedBox(width: 8),
                            Text('حذف',
                                style: TextStyle(
                                    fontFamily: 'Cairo', color: Colors.red)),
                          ],
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// تصفيتة أفقية للتاريخ
class DateFilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onSelected;
  final VoidCallback? onRemove;

  const DateFilterChip({
    Key? key,
    required this.label,
    required this.isSelected,
    required this.onSelected,
    this.onRemove,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onSelected(),
      backgroundColor: Colors.grey[100],
      selectedColor: AppTheme.primaryColor.withValues(alpha: 0.2),
      side: BorderSide(
        color: isSelected ? AppTheme.primaryColor : Colors.grey[300]!,
      ),
    );
  }
}
