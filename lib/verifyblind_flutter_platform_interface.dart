import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'verifyblind_flutter_method_channel.dart';

abstract class VerifyblindFlutterPlatform extends PlatformInterface {
  /// Constructs a VerifyblindFlutterPlatform.
  VerifyblindFlutterPlatform() : super(token: _token);

  static final Object _token = Object();

  static VerifyblindFlutterPlatform _instance = MethodChannelVerifyblindFlutter();

  /// The default instance of [VerifyblindFlutterPlatform] to use.
  ///
  /// Defaults to [MethodChannelVerifyblindFlutter].
  static VerifyblindFlutterPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [VerifyblindFlutterPlatform] when
  /// they register themselves.
  static set instance(VerifyblindFlutterPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
