
import 'verifyblind_flutter_platform_interface.dart';

class VerifyblindFlutter {
  Future<String?> getPlatformVersion() {
    return VerifyblindFlutterPlatform.instance.getPlatformVersion();
  }
}
