part of '../settings_page.dart';

// spec 051 — فئة «الحساب والفريق» بتصميم السبورة والكروت:
// سبورة ببيانات المعلم + كارت حقول التعديل + كارت الحساب والمساعدين.

class _AccountTeamCategoryPage extends StatelessWidget {
  const _AccountTeamCategoryPage({this.highlightId});

  /// معرّف عنصر من نتيجة بحث (spec 051) — بيتميّز بشريط في أول الصفحة.
  final String? highlightId;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final t = _tk(isDark);
    final SettingsController settings = Get.find();
    const indigo = Color(0xFF4F46E5);
    const gap = SizedBox(height: AppSpace.lg);
    return _CategoryScaffold(
      title: 'الحساب والفريق',
      highlightId: highlightId,
      children: [
        _buildTeacherSection(context, isDark, settings),
        gap,
        // ── الحساب والمساعدين: كارت بحالة الدخول ──
        Obx(() {
          final auth = Get.find<AuthController>();
          final phone = auth.currentPhone.value ?? '';
          final logged = auth.isLoggedIn.value;
          return _plainSectionBlock(
            t,
            'المساعدين والحسابات',
            Icons.account_circle_rounded,
            indigo,
            _settingsCard(
              t,
              InkWell(
                onTap: () => Get.to(() => const AccountTeamScreen()),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpace.lg),
                  child: Row(children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: logged ? t.positiveSoft : t.cautionSoft,
                        border: Border.all(
                            color: logged ? t.positive : t.cautionBar,
                            width: 1.5),
                      ),
                      child: Icon(
                          logged
                              ? Icons.groups_rounded
                              : Icons.login_rounded,
                          color: logged ? t.positive : t.caution),
                    ),
                    const SizedBox(width: AppSpace.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('المساعدين والحسابات',
                              style: AppType.label.copyWith(color: t.ink)),
                          const SizedBox(height: 2),
                          Text(
                            logged
                                ? 'مسجّل دخول — $phone'
                                : 'تسجيل دخول ومشاركة البيانات مع مساعدين',
                            style:
                                AppType.caption.copyWith(color: t.inkFaint),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.arrow_forward_ios_rounded,
                        size: 14, color: t.inkFaint),
                  ]),
                ),
              ),
            ),
          );
        }),
        gap,
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
  final t = _tk(isDark);

  // اختيار صورة المعلم: بننسخ البايتات لمسار دائم جوه مجلد التطبيق بدل
  // مسار الجاليري/الكاش (النظام ممكن ينضّفه، وده اتأكد بعد استعادة نسخة).
  Future<void> pickAvatar() async {
    final x = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      imageQuality: 85,
    );
    if (x == null) return;
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final ext = p.extension(x.path);
      final permanentPath = p.join(
          docsDir.path, 'teacher_avatar${ext.isNotEmpty ? ext : '.jpg'}');
      await File(x.path).copy(permanentPath);
      settings.setTeacherAvatarPath(permanentPath);
    } catch (_) {
      // فشل النسخ (نادر) → احتفظ بالسلوك القديم بدل ما نضيّع الاختيار.
      settings.setTeacherAvatarPath(x.path);
    }
    await settings.saveTeacherInfo();
  }

  return Obx(() {
    final team = TeamModeService();
    final isAssistant = team.isEnabled.value && !team.isOwner.value;

    if (isAssistant) {
      return _plainSectionBlock(
        t,
        'بيانات المعلم',
        Icons.person_rounded,
        const Color(0xFFFF4D7A),
        _settingsCard(
          t,
          Padding(
            padding: const EdgeInsets.all(AppSpace.lg),
            child: Row(children: [
              Icon(Icons.lock_rounded, size: 18, color: t.inkFaint),
              const SizedBox(width: AppSpace.sm),
              Expanded(
                child: Text(
                  'بيانات المعلم بتتعرض من حساب المدرس اللي انت مساعد لديه — معندكش صلاحية تعدّلها من جهازك',
                  style: AppType.caption.copyWith(color: t.inkSoft),
                ),
              ),
            ]),
          ),
        ),
      );
    }

    final fullName = settings.teacherFullName.value.trim();
    final avatarPath = settings.teacherAvatarPath.value.trim();
    final gender = settings.teacherGender.value;
    final spec = settings.teacherSpecialization.value.trim();
    ImageProvider? avatarImage;
    if (avatarPath.isNotEmpty) {
      final f = File(avatarPath);
      if (f.existsSync()) avatarImage = FileImage(f);
    }
    final initial = fullName.isNotEmpty ? fullName.characters.first : 'م';
    final title = gender == 'female' ? 'مس' : 'مستر';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── السبورة: الصورة والاسم ──
        Material(
          color: t.board,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.board),
            side: BorderSide(color: t.boardLine),
          ),
          child: InkWell(
            onTap: pickAvatar,
            child: Padding(
              padding: const EdgeInsets.all(AppSpace.lg),
              child: Row(children: [
                Stack(alignment: Alignment.bottomLeft, children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundImage: avatarImage,
                    backgroundColor: t.chalk,
                    child: avatarImage == null
                        ? Text(initial,
                            style: AppType.greeting
                                .copyWith(color: t.onChalk, fontSize: 26))
                        : null,
                  ),
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: t.chalk,
                      shape: BoxShape.circle,
                      border: Border.all(color: t.board, width: 2),
                    ),
                    child: Icon(Icons.camera_alt_rounded,
                        size: 12, color: t.onChalk),
                  ),
                ]),
                const SizedBox(width: AppSpace.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fullName.isEmpty ? 'اكتب اسمك' : '$title $fullName',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.greeting.copyWith(color: t.boardInk),
                      ),
                      if (spec.isNotEmpty)
                        Text(spec,
                            style: AppType.body
                                .copyWith(color: t.boardInkSoft)),
                      const SizedBox(height: 4),
                      Text('اضغط للتغيير — الاسم والتخصص بيظهروا في رسايل أولياء الأمور',
                          style: AppType.caption
                              .copyWith(color: t.boardInkSoft)),
                    ],
                  ),
                ),
              ]),
            ),
          ),
        ),
        const SizedBox(height: AppSpace.lg),
        // ── حقول التعديل ──
        _plainSectionBlock(
          t,
          'بيانات المعلم',
          Icons.person_rounded,
          const Color(0xFFFF4D7A),
          _settingsCard(
            t,
            Padding(
              padding: const EdgeInsets.all(AppSpace.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
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
                  const SizedBox(height: AppSpace.md),
                  // ── اختيار الجنس ──
                  Row(children: [
                    Expanded(
                      child: _GenderChip(
                        isDark: isDark,
                        label: 'مستر',
                        icon: Icons.male_rounded,
                        color: const Color(0xFF4F46E5),
                        selected: gender == 'male',
                        onTap: () async {
                          settings.setTeacherGender('male');
                          await settings.saveTeacherInfo();
                        },
                      ),
                    ),
                    const SizedBox(width: AppSpace.sm),
                    Expanded(
                      child: _GenderChip(
                        isDark: isDark,
                        label: 'مس',
                        icon: Icons.female_rounded,
                        color: const Color(0xFFE91E8C),
                        selected: gender == 'female',
                        onTap: () async {
                          settings.setTeacherGender('female');
                          await settings.saveTeacherInfo();
                        },
                      ),
                    ),
                  ]),
                  const SizedBox(height: AppSpace.md),
                  // ── التخصص — بيتكتب في رسايل واتساب لأولياء الأمور ──
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
              ),
            ),
          ),
        ),
      ],
    );
  });
}

// ─── عن التطبيق ───────────────────────────────────────────────────────────
