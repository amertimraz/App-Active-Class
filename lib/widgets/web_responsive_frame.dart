// lib/widgets/web_responsive_frame.dart
//
// spec 055 (T055) — إطار عام للشاشات العريضة: بيوسّط التطبيق بعرض أقصى
// مريح بدل ما يتمط، ويكبّر الخط والأيقونات شوية. بيتحط مرة واحدة فوق الـNavigator
// (main.dart builder) فبتتأثر بيه كل الشاشات والنوافذ والـ bottom sheets.
// على الموبايل/أندرويد ([enabled] = false) بيرجّع الـchild زي ما هو.
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'package:active_class/utils/responsive.dart';

class WebResponsiveFrame extends StatelessWidget {
  const WebResponsiveFrame({super.key, required this.child, bool? enabled})
      : enabled = enabled ?? kIsWeb;

  final Widget child;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    return LayoutBuilder(builder: (context, box) {
      final viewport = box.maxWidth;
      if (viewport < kDesktopBreakpoint) return child;

      final media = MediaQuery.of(context);
      final width = framedWidth(viewport);
      final scale = desktopTextScale(viewport);
      final theme = Theme.of(context);
      final dark = theme.brightness == Brightness.dark;
      final band = dark ? const Color(0xFF0B1220) : const Color(0xFFEEF0F7);
      final edge = dark ? const Color(0xFF1E293B) : const Color(0xFFD9DCEB);

      return ColoredBox(
        color: band,
        child: Center(
          child: SizedBox(
            width: width,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                border: Border.symmetric(vertical: BorderSide(color: edge)),
              ),
              child: MediaQuery(
                data: media.copyWith(
                  size: Size(width, media.size.height),
                  textScaler: TextScaler.linear(
                      media.textScaler.scale(scale * 14) / 14),
                ),
                child: IconTheme.merge(
                  data: const IconThemeData(size: 26),
                  child: ClipRect(child: child),
                ),
              ),
            ),
          ),
        ),
      );
    });
  }
}
