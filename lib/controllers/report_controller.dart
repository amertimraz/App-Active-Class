import 'package:get/get.dart';
import 'package:active_class/services/database_service.dart';
import 'package:active_class/utils/helpers.dart';
import 'package:active_class/models/payment_model.dart';
import 'package:active_class/models/attendance_model.dart';

class ReportController extends GetxController {
  final DatabaseService _dbService = DatabaseService();
  
  final RxInt totalAttendance = 0.obs;
  final RxDouble attendancePercentage = 0.0.obs;
  final RxDouble totalPayments = 0.0.obs;
  final RxInt paymentCount = 0.obs;
  final RxInt totalStudents = 0.obs;
  final RxInt totalGroups = 0.obs;

  final RxList<Payment> recentPayments = <Payment>[].obs;
  final RxList<Attendance> recentAttendance = <Attendance>[].obs;

  Future<void> generateReport() async => loadReports();

  Future<void> loadReports() async {
    try {
      final attendanceList = await _dbService.getAllAttendance();
      totalAttendance.value = attendanceList.length;

      final paymentsList = await _dbService.getAllPayments();
      paymentCount.value = paymentsList.length;
      totalPayments.value = paymentsList.fold(0.0, (sum, payment) => sum + payment.amount);

      final studentsList = await _dbService.getAllStudents();
      totalStudents.value = studentsList.length;

      final groupsList = await _dbService.getAllGroups();
      totalGroups.value = groupsList.length;

      if (totalStudents.value > 0 && totalAttendance.value > 0) {
        attendancePercentage.value = (totalAttendance.value / (totalStudents.value * 30)) * 100;
      } else {
        attendancePercentage.value = 0.0;
      }

      recentPayments.assignAll(paymentsList.take(10).toList());
      recentAttendance.assignAll(attendanceList.take(10).toList());
    } catch (e) {
      ToastHelper.error('حدث خطأ في تحميل التقارير');
    }
  }

  Future<void> exportPDF() async {
    try {
      ToastHelper.success('سيتم تطوير وظيفة تصدير PDF', title: 'قريباً');
    } catch (e) {
      ToastHelper.error('حدث خطأ في تصدير التقرير');
    }
  }
}
