import 'package:finding_buddy/controller/app_controller.dart';
import 'package:finding_buddy/controller/setting_controller.dart';
import 'package:get/get.dart';

class InitialBinding extends Bindings {
  @override
  void dependencies() {
    Get.put(AppController(), permanent: true);
    Get.lazyPut(() => SettingsController());
  }
}
