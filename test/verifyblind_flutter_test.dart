import 'package:flutter_test/flutter_test.dart';
import 'package:verifyblind_flutter/verifyblind_flutter.dart';
import 'package:verifyblind_flutter/verifyblind_flutter_platform_interface.dart';
import 'package:verifyblind_flutter/verifyblind_flutter_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockVerifyblindFlutterPlatform
    with MockPlatformInterfaceMixin
    implements VerifyblindFlutterPlatform {
  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final VerifyblindFlutterPlatform initialPlatform = VerifyblindFlutterPlatform.instance;

  test('$MethodChannelVerifyblindFlutter is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelVerifyblindFlutter>());
  });

  test('getPlatformVersion', () async {
    VerifyblindFlutter verifyblindFlutterPlugin = VerifyblindFlutter();
    MockVerifyblindFlutterPlatform fakePlatform = MockVerifyblindFlutterPlatform();
    VerifyblindFlutterPlatform.instance = fakePlatform;

    expect(await verifyblindFlutterPlugin.getPlatformVersion(), '42');
  });
}
