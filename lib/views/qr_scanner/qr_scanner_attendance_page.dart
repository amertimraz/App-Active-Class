// lib/views/qr_scanner/qr_scanner_attendance_page.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:active_class/config/constants.dart';
import 'package:active_class/config/theme.dart';
import 'package:active_class/controllers/qr_controller.dart';
import 'package:active_class/controllers/group_controller.dart';
import 'package:active_class/controllers/student_controller.dart';
import 'package:active_class/models/student_model.dart';
import 'package:active_class/views/attendance/attendance_page.dart';

class QRScannerAttendancePage extends StatefulWidget {
  const QRScannerAttendancePage({super.key});

  @override
  State<QRScannerAttendancePage> createState() => _QRScannerAttendancePageState();
}

class _QRScannerAttendancePageState extends State<QRScannerAttendancePage> with SingleTickerProviderStateMixin {
  late MobileScannerController scannerController;
  final QRController controller = Get.put(QRController());
  final GroupController groupController = Get.put(GroupController());
  final StudentController studentController = Get.put(StudentController());
  late TabController tabController;
  
  final TextEditingController searchController = TextEditingController();
  List<Student> searchResults = [];
  bool isSearching = false;

  @override
  void initState() {
    super.initState();
    tabController = TabController(length: 2, vsync: this);
    scannerController = MobileScannerController(autoStart: false);
    controller.mode.value = QRMode.attendance;
    scannerController.start();
  }

  @override
  void dispose() {
    tabController.dispose();
    scannerController.dispose();
    searchController.dispose();
    super.dispose();
  }

  void _searchStudent(String query) {
    setState(() {
      isSearching = true;
    });

    if (query.isEmpty) {
      setState(() {
        searchResults = [];
        isSearching = false;
      });
      return;
    }

    final allStudents = studentController.students;
    final results = allStudents.where((student) {
      return student.name.toLowerCase().contains(query.toLowerCase()) ||
             student.code.toLowerCase().contains(query.toLowerCase());
    }).toList();

    setState(() {
      searchResults = results;
      isSearching = false;
    });
  }

  void _selectStudent(Student student) async {
    await controller.handleScan(student.code);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Text('تم تسجيل حضور: ${student.name}'),
          ],
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
    
    searchController.clear();
    setState(() {
      searchResults = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(context).scaffoldBackgroundColor;
    return Scaffold(
      appBar: AppBar(
        title: const Text('تسجيل الحضور'),
        centerTitle: true,
        bottom: TabBar(
          controller: tabController,
          tabs: const [
            Tab(icon: Icon(Icons.qr_code_scanner), text: 'QR Scanner'),
            Tab(icon: Icon(Icons.search), text: 'بحث يدوياً'),
          ],
        ),
      ),
      body: Container(
        color: bg,
        child: TabBarView(
          controller: tabController,
          children: [
            _buildQRTab(context),
            _buildManualSearchTab(context),
          ],
        ),
      ),
    );
  }

  Widget _buildQRTab(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: PADDING_NORMAL),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: PADDING_NORMAL),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 600),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(BORDER_RADIUS_LARGE),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, 8)),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(BORDER_RADIUS_LARGE),
                    child: SizedBox(
                      height: MediaQuery.of(context).size.height * 0.45,
                      child: MobileScanner(
                        controller: scannerController,
                        onDetect: (capture) {
                          final barcodes = capture.barcodes;
                          for (final b in barcodes) {
                            final v = b.rawValue;
                            if (v != null) _handle(v);
                          }
                        },
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: PADDING_LARGE),
              Obx(() {
                final s = controller.scannedStudent.value;
                return AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  transitionBuilder: (child, anim) {
                    return FadeTransition(
                      opacity: anim,
                      child: SlideTransition(position: Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero).animate(anim), child: child),
                    );
                  },
                  child: s == null
                      ? const SizedBox.shrink()
                      : Card(
                          key: ValueKey(s.id),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(BORDER_RADIUS_NORMAL)),
                          child: Padding(
                            padding: const EdgeInsets.all(PADDING_NORMAL),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.15),
                                  child: const Icon(Icons.person, color: AppTheme.primaryColor),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(s.name, style: Theme.of(context).textTheme.titleMedium),
                                      const SizedBox(height: 4),
                                      Text('كود: ${s.code}', style: Theme.of(context).textTheme.labelSmall),
                                      const SizedBox(height: 2),
                                      Text('المجموعة: ${groupController.groups.firstWhereOrNull((g) => g.id == s.groupId)?.name ?? '-'}', style: Theme.of(context).textTheme.labelSmall),
                                    ],
                                  ),
                                ),
                                Chip(
                                  label: const Text(ATTENDANCE_PRESENT, style: TextStyle(fontWeight: FontWeight.bold)),
                                  labelStyle: const TextStyle(color: Colors.green),
                                  side: BorderSide(color: Colors.green.withValues(alpha: 0.4)),
                                  backgroundColor: Colors.green.withValues(alpha: 0.08),
                                  shape: StadiumBorder(side: BorderSide(color: Colors.green.withValues(alpha: 0.2))),
                                ),
                              ],
                            ),
                          ),
                        ),
                );
              }),
            ],
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.all(PADDING_NORMAL),
          color: AppTheme.primaryColor.withValues(alpha: 0.06),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.flash_on),
                onPressed: () => scannerController.toggleTorch(),
                color: AppTheme.primaryColor,
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.flip_camera_ios),
                onPressed: () => scannerController.switchCamera(),
                color: AppTheme.primaryColor,
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () => Get.to(() => const AttendancePage()),
                icon: const Icon(Icons.list_alt),
                label: const Text('عرض سجل الحضور'),
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildManualSearchTab(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: PADDING_NORMAL),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: PADDING_NORMAL),
          child: TextField(
            controller: searchController,
            decoration: InputDecoration(
              hintText: 'ابحث باسم الطالب أو الكود',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        searchController.clear();
                        setState(() {
                          searchResults = [];
                        });
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(BORDER_RADIUS_NORMAL),
              ),
              filled: true,
              fillColor: AppTheme.primaryColor.withValues(alpha: 0.05),
            ),
            onChanged: _searchStudent,
          ),
        ),
        const SizedBox(height: PADDING_NORMAL),
        Expanded(
          child: isSearching
              ? const Center(child: CircularProgressIndicator())
              : searchResults.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.person_search,
                            size: 80,
                            color: Colors.grey.withValues(alpha: 0.3),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            searchController.text.isEmpty
                                ? 'ابحث عن طالب لتسجيل الحضور'
                                : 'لم يتم العثور على نتائج',
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                  color: Colors.grey,
                                ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: PADDING_NORMAL),
                      itemCount: searchResults.length,
                      itemBuilder: (context, index) {
                        final student = searchResults[index];
                        final group = groupController.groups.firstWhereOrNull(
                          (g) => g.id == student.groupId,
                        );
                        return Card(
                          margin: const EdgeInsets.only(bottom: PADDING_SMALL),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(BORDER_RADIUS_NORMAL),
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.15),
                              child: const Icon(Icons.person, color: AppTheme.primaryColor),
                            ),
                            title: Text(student.name),
                            subtitle: Text('كود: ${student.code}\nالمجموعة: ${group?.name ?? '-'}'),
                            trailing: ElevatedButton.icon(
                              onPressed: () => _selectStudent(student),
                              icon: const Icon(Icons.check),
                              label: const Text('تسجيل'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryColor,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  void _handle(String qr) async {
    scannerController.stop();
    await controller.handleScan(qr);
    if (!mounted) return;

    scannerController.start();
  }
}
