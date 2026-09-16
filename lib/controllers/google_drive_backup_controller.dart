// lib/controllers/google_drive_backup_controller.dart
//
// spec 037 — حالة ربط Google Drive + قائمة النسخ السحابية، لعرضها في
// شاشة إدارة النسخ الاحتياطي.
import 'package:get/get.dart';

import 'package:active_class/services/google_drive_backup_service.dart';

class GoogleDriveBackupController extends GetxController {
  final GoogleDriveBackupService _svc = GoogleDriveBackupService();

  final RxBool isLinked = false.obs;
  final RxnString linkedEmail = RxnString();
  final RxList<CloudBackupEntry> cloudBackups = <CloudBackupEntry>[].obs;
  final RxBool busy = false.obs;

  @override
  void onInit() {
    super.onInit();
    refreshLinkStatus();
  }

  Future<void> refreshLinkStatus() async {
    isLinked.value = await _svc.isLinked();
    linkedEmail.value = await _svc.linkedEmail();
    if (isLinked.value) await refreshCloudBackups();
  }

  Future<void> refreshCloudBackups() async {
    if (!isLinked.value) {
      cloudBackups.clear();
      return;
    }
    cloudBackups.assignAll(await _svc.listCloudBackups());
  }

  Future<bool> linkAccount() async {
    busy.value = true;
    try {
      final ok = await _svc.linkAccount();
      if (ok) await refreshLinkStatus();
      return ok;
    } finally {
      busy.value = false;
    }
  }

  Future<void> unlinkAccount() async {
    busy.value = true;
    try {
      await _svc.unlinkAccount();
      isLinked.value = false;
      linkedEmail.value = null;
      cloudBackups.clear();
    } finally {
      busy.value = false;
    }
  }

  Future<bool> uploadNow() async {
    busy.value = true;
    try {
      final ok = await _svc.uploadBackup(isAutomatic: false);
      if (ok) await refreshCloudBackups();
      return ok;
    } finally {
      busy.value = false;
    }
  }

  Future<bool> restore(CloudBackupEntry entry) async {
    busy.value = true;
    try {
      return await _svc.restoreFromCloud(entry.id, entry.name);
    } finally {
      busy.value = false;
    }
  }

  Future<bool> deleteBackup(CloudBackupEntry entry) async {
    busy.value = true;
    try {
      final ok = await _svc.deleteCloudBackup(entry.id);
      if (ok) await refreshCloudBackups();
      return ok;
    } finally {
      busy.value = false;
    }
  }
}
