// lib/widgets/custom_dialogs.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:active_class/config/theme.dart';
import 'package:active_class/config/constants.dart';
import 'package:active_class/widgets/custom_widgets.dart';
import 'package:active_class/utils/helpers.dart';

/// حوار تأكيد الحذف
class ConfirmDeleteDialog {
  static void show(
    BuildContext context, {
    required String title,
    required String message,
    required VoidCallback onConfirm,
    String confirmText = 'حذف',
    String cancelText = 'إلغاء',
  }) {
    Get.defaultDialog(
      title: title,
      titleStyle: Theme.of(context).textTheme.titleLarge!,
      content: Padding(
        padding: const EdgeInsets.symmetric(vertical: PADDING_NORMAL),
        child: Text(
          message,
          style: Theme.of(context).textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
      ),
      onConfirm: () {
        Get.back(); // يغلق الـ dialog نفسه
        onConfirm();
      },
      textConfirm: confirmText,
      confirmTextColor: Colors.white,
      buttonColor: Colors.red,
      cancelTextColor: Colors.grey,
      textCancel: cancelText,
    );
  }
}

/// حوار اختيار التاريخ
class DatePickerDialog {
  static Future<DateTime?> show(
    BuildContext context, {
    DateTime? initialDate,
    required String title,
  }) async {
    return await showDatePicker(
      context: context,
      initialDate: initialDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      locale: const Locale('ar'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppTheme.primaryColor,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
  }
}

/// حوار تأكيد عام
class ConfirmDialog {
  static void show(
    BuildContext context, {
    required String title,
    required String message,
    required VoidCallback onConfirm,
    String confirmText = 'موافق',
    String cancelText = 'إلغاء',
    IconData? icon,
    Color? iconColor,
  }) {
    Get.defaultDialog(
      title: title,
      titleStyle: Theme.of(context).textTheme.titleLarge!,
      content: Column(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 60, color: iconColor ?? AppTheme.primaryColor),
            const SizedBox(height: 16),
          ],
          Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
      onConfirm: () {
        Get.back();
        onConfirm();
      },
      textConfirm: confirmText,
      confirmTextColor: Colors.white,
      buttonColor: AppTheme.primaryColor,
      cancelTextColor: AppTheme.primaryColor,
      textCancel: cancelText,
    );
  }
}

/// حوار رسالة نجاح
class SuccessDialog {
  static void show(
    BuildContext context, {
    required String title,
    required String message,
    VoidCallback? onDismiss,
  }) {
    Get.defaultDialog(
      title: title,
      titleStyle: Theme.of(context).textTheme.titleLarge?.copyWith(
        color: Colors.green,
      ),
      content: Column(
        children: [
          Icon(Icons.check_circle, size: 60, color: Colors.green[400]),
          const SizedBox(height: 16),
          Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
      onConfirm: () {
        Get.back();
        onDismiss?.call();
      },
      textConfirm: 'موافق',
      confirmTextColor: Colors.white,
      buttonColor: Colors.green,
    );
  }
}

/// حوار رسالة خطأ
class ErrorDialog {
  static void show(
    BuildContext context, {
    required String title,
    required String message,
    VoidCallback? onDismiss,
  }) {
    Get.defaultDialog(
      title: title,
      titleStyle: Theme.of(context).textTheme.titleLarge?.copyWith(
        color: Colors.red,
      ),
      content: Column(
        children: [
          Icon(Icons.error_outline, size: 60, color: Colors.red[400]),
          const SizedBox(height: 16),
          Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
      onConfirm: () {
        Get.back();
        onDismiss?.call();
      },
      textConfirm: 'موافق',
      confirmTextColor: Colors.white,
      buttonColor: Colors.red,
    );
  }
}

/// حوار اختيار متعدد الخيارات
class ChoiceDialog {
  static void show(
    BuildContext context, {
    required String title,
    required List<String> options,
    required Function(int) onSelected,
  }) {
    Get.defaultDialog(
      title: title,
      titleStyle: Theme.of(context).textTheme.titleLarge!,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(
          options.length,
          (index) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: CustomButton(
              label: options[index],
              onPressed: () {
                Get.back();
                onSelected(index);
              },
              width: double.infinity,
            ),
          ),
        ),
      ),
    );
  }
}

/// حوار إدخال نص
class InputDialog {
  static void show(
    BuildContext context, {
    required String title,
    required String label,
    required Function(String) onConfirm,
    String initialValue = '',
    String? hint,
    TextInputType keyboardType = TextInputType.text,
    String confirmText = 'حفظ',
    String cancelText = 'إلغاء',
  }) {
    final TextEditingController controller = TextEditingController(
      text: initialValue,
    );

    Get.defaultDialog(
      title: title,
      titleStyle: Theme.of(context).textTheme.titleLarge!,
      content: Padding(
        padding: const EdgeInsets.symmetric(vertical: PADDING_NORMAL),
        child: CustomTextField(
          controller: controller,
          label: label,
          hint: hint,
          keyboardType: keyboardType,
        ),
      ),
      onConfirm: () {
        if (controller.text.isNotEmpty) {
          Get.back();
          onConfirm(controller.text);
        } else {
          ToastHelper.info('يرجى إدخال ');
        }
      },
      textConfirm: confirmText,
      confirmTextColor: Colors.white,
      buttonColor: AppTheme.primaryColor,
      cancelTextColor: AppTheme.primaryColor,
      textCancel: cancelText,
    );
  }
}

/// حوار اختيار من قائمة
class SelectDialog {
  static void show(
    BuildContext context, {
    required String title,
    required List<Map<String, dynamic>> items,
    required Function(Map<String, dynamic>) onSelected,
    String displayField = 'name',
  }) {
    Get.defaultDialog(
      title: title,
      titleStyle: Theme.of(context).textTheme.titleLarge!,
      content: SizedBox(
        height: 300,
        width: double.maxFinite,
        child: ListView.builder(
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return ListTile(
              title: Text(item[displayField].toString()),
              onTap: () {
                Get.back();
                onSelected(item);
              },
            );
          },
        ),
      ),
    );
  }
}

/// حوار تحميل
class LoadingDialog {
  static void show(
    BuildContext context, {
    String message = 'جاري التحميل...',
  }) {
    Get.defaultDialog(
      title: '',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(message),
        ],
      ),
      barrierDismissible: false,
    );
  }

  static void hide() {
    if (Get.isDialogOpen ?? false) {
      Get.back();
    }
  }
}

/// حوار معلومات
class InfoDialog {
  static void show(
    BuildContext context, {
    required String title,
    required String message,
    VoidCallback? onDismiss,
    IconData icon = Icons.info,
  }) {
    Get.defaultDialog(
      title: title,
      titleStyle: Theme.of(context).textTheme.titleLarge!,
      content: Column(
        children: [
          Icon(icon, size: 60, color: AppTheme.primaryColor),
          const SizedBox(height: 16),
          Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
      onConfirm: () {
        Get.back();
        onDismiss?.call();
      },
      textConfirm: 'موافق',
      confirmTextColor: Colors.white,
      buttonColor: AppTheme.primaryColor,
    );
  }
}
