import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verifyblind_flutter/verifyblind_flutter_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  MethodChannelVerifyblindFlutter platform = MethodChannelVerifyblindFlutter();
  const MethodChannel channel = MethodChannel('verifyblind_flutter');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          return '42';
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('getPlatformVersion', () async {
    expect(await platform.getPlatformVersion(), '42');
  });
}
