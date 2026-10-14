part of '../settings_page.dart';

// spec 051 — فئة «الحساب والفريق»

class _AccountTeamCategoryPage extends StatelessWidget {
  const _AccountTeamCategoryPage({this.highlightId});

  /// معرّف عنصر من نتيجة بحث (spec 051) — بيتميّز بشريط في أول الصفحة.
  final String? highlightId;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final SettingsController settings = Get.find();
    return _CategoryScaffold(
      title: 'الحساب والفريق',
      highlightId: highlightId,
      children: [
        _buildTeacherSection(context, isDark, settings),
        const SizedBox(height: 14),
        _buildSection(
          context,
          isDark,
          title: 'المساعدين والحسابات',
          icon: Icons.account_circle_rounded,
          color: const Color(0xFF4F46E5),
          children: [
            Obx(() {
              final auth = Get.find<AuthController>();
              final phone = auth.currentPhone.value ?? '';
              return _buildNavTile(
                context,
                isDark,
                icon: Icons.groups_rounded,
                iconColor: const Color(0xFF4F46E5),
                title: 'المساعدين والحسابات',
                subtitle: auth.isLoggedIn.value
                    ? phone
                    : 'تسجيل دخول ومشاركة البيانات مع مساعدين',
                onTap: () => Get.to(() => const AccountTeamScreen()),
              );
            }),
          ],
        ),
        const SizedBox(height: 14),
        // ── متابعة أولياء الأمور (إضافة مدفوعة، spec 016) ──
        Obx(() {
          final lic = Get.find<LicenseController>();
          // قراءة العدادين دول مقصودة عشان الـObx يعيد البناء:
          // - recheckTick كل 5 دقايق (الفحص الدوري لانتهاء المدة)
          // - verifiedTick بعد كل قراءة ترخيص ناجحة (عشان القسم
          //   يظهر فورًا لما القراءة تخلص/تتغيّر، مش بعد 5 دقايق)
          // ignore: unnecessary_statements
          lic.parentPortalRecheckTick.value;
          // ignore: unnecessary_statements
          lic.licenseVerifiedTick.value;

          // نعرض القسم طول ما الإضافة مفعّلة على الترخيص — حتى لو
          // مدتها المستقلة انتهت — عشان المدرس يشوف تاريخ الانتهاء
          // ويعرف يجدّد، بدل ما تختفي وتبان وكأنها "اتلغت".
          if (!lic.parentPortalEnabled.value) {
            return const SizedBox.shrink();
          }
          final expired = !lic.parentPortalActiveNow;
          return Column(children: [
            _buildSection(
              context,
              isDark,
              title: 'متابعة أولياء الأمور',
              icon: Icons.family_restroom_rounded,
              color:
                  expired ? const Color(0xFFEF4444) : const Color(0xFF10B981),
              children: [
                _ParentPortalTile(isDark: isDark, expired: expired),
              ],
            ),
            const SizedBox(height: 14),
          ]);
        }),
      ],
    );
  }
}

Widget _buildTeacherSection(
  BuildContext context,
  bool isDark,
  SettingsController settings,
) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(right: 4, bottom: 8),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFFF4D7A).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.person_rounded,
                  size: 16, color: Color(0xFFFF4D7A)),
            ),
            const SizedBox(width: 8),
            Text(
              'بيانات المعلم',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white70 : const Color(0xFF374151),
              ),
            ),
          ],
        ),
      ),
      Container(
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF131D31).withValues(alpha: 0.95)
              : Colors.white.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.white.withValues(alpha: 0.9),
          ),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.18)
                  : const Color(0xFFD8E0F0).withValues(alpha: 0.45),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        padding: const EdgeInsets.all(20),
        child: Obx(() {
          final team = TeamModeService();
          final isAssistant = team.isEnabled.value && !team.isOwner.value;
          final fullName = settings.teacherFullName.value.trim();
          final avatarPath = settings.teacherAvatarPath.value.trim();

          ImageProvider? avatarImage;
          if (avatarPath.isNotEmpty) {
            final f = File(avatarPath);
            if (f.existsSync()) avatarImage = FileImage(f);
          }
          final initial = fullName.isNotEmpty ? fullName.characters.first : 'م';

          if (isAssistant) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.lock_rounded,
                      size: 14, color: Color(0xFF9CA3AF)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'بيانات المعلم بتتعرض من حساب المدرس اللي انت مساعد لديه — معندكش صلاحية تعدّلها من جهازك',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 12,
                        color:
                            isDark ? Colors.white54 : const Color(0xFF6B7280),
                      ),
                    ),
                  ),
                ]),
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  // ── الصورة ──────────────────────────────────────────
                  GestureDetector(
                    onTap: () async {
                      final picker = ImagePicker();
                      final x = await picker.pickImage(
                        source: ImageSource.gallery,
                        maxWidth: 800,
                        imageQuality: 85,
                      );
                      if (x != null) {
                        // بنسخ بايتات الصورة فعليًا لمسار دائم جوه مجلد
                        // التطبيق بدل ما نخزّن مسار الجاليري/الكاش الأصلي
                        // زي ما كان — المسار ده ممكن يتنضّف/يتغيّر من النظام
                        // في أي وقت (زي ما تأكّد فعليًا بعد استعادة نسخة
                        // احتياطية: المسار المحفوظ رجع لكن الملف نفسه راح).
                        try {
                          final docsDir =
                              await getApplicationDocumentsDirectory();
                          final ext = p.extension(x.path);
                          final permanentPath = p.join(docsDir.path,
                              'teacher_avatar${ext.isNotEmpty ? ext : '.jpg'}');
                          await File(x.path).copy(permanentPath);
                          settings.setTeacherAvatarPath(permanentPath);
                        } catch (_) {
                          // فشل النسخ (نادر) → احتفظ بالسلوك القديم بدل ما
                          // نضيّع الاختيار خالص.
                          settings.setTeacherAvatarPath(x.path);
                        }
                        await settings.saveTeacherInfo();
                      }
                    },
                    child: Stack(
                      alignment: Alignment.bottomLeft,
                      children: [
                        CircleAvatar(
                          radius: 36,
                          backgroundImage: avatarImage,
                          backgroundColor:
                              AppTheme.primaryColor.withValues(alpha: 0.15),
                          child: avatarImage == null
                              ? Text(initial,
                                  style: const TextStyle(
                                    color: AppTheme.primaryColor,
                                    fontSize: 26,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Cairo',
                                  ))
                              : null,
                        ),
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isDark
                                  ? const Color(0xFF131D31)
                                  : Colors.white,
                              width: 2,
                            ),
                          ),
                          child: const Icon(Icons.camera_alt_rounded,
                              size: 11, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  // ── الاسم + الجنس ─────────────────────────────────────────
                  Expanded(
                    child: Column(
                      children: [
                        _buildTextField(
                          isDark,
                          label: 'اسم المعلم',
                          value: settings.teacherFullName.value,
                          icon: Icons.badge_rounded,
                          onChanged: (v) async {
                            settings.setTeacherFullName(v);
                            await settings.saveTeacherInfo();
                          },
                        ),
                        const SizedBox(height: 12),
                        // ── اختيار الجنس ──────────────────────────
                        Row(
                          children: [
                            Expanded(
                              child: _GenderChip(
                                isDark: isDark,
                                label: 'مستر',
                                icon: Icons.male_rounded,
                                color: const Color(0xFF4F46E5),
                                selected:
                                    settings.teacherGender.value == 'male',
                                onTap: () async {
                                  settings.setTeacherGender('male');
                                  await settings.saveTeacherInfo();
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _GenderChip(
                                isDark: isDark,
                                label: 'مس',
                                icon: Icons.female_rounded,
                                color: const Color(0xFFE91E8C),
                                selected:
                                    settings.teacherGender.value == 'female',
                                onTap: () async {
                                  settings.setTeacherGender('female');
                                  await settings.saveTeacherInfo();
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // ── التخصص — بيتكتب في رسائل الواتساب اللي بتتبعت لأولياء الأمور ──
              _buildTextField(
                isDark,
                label: 'التخصص',
                value: settings.teacherSpecialization.value,
                icon: Icons.school_rounded,
                onChanged: (v) async {
                  settings.setTeacherSpecialization(v);
                  await settings.saveTeacherInfo();
                },
              ),
            ],
          );
        }),
      ),
    ],
  );
}

// ─── عن التطبيق ───────────────────────────────────────────────────────────
