import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verifyblind_flutter/verifyblind_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.verifyblind/flutter');
  final calls = <MethodCall>[];

  void mock(Future<Object?>? Function(MethodCall call) handler) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) {
      calls.add(call);
      return handler(call);
    });
  }

  setUp(calls.clear);
  tearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, null));

  VerifyBlind client() => VerifyBlind(VerifyBlindConfig(
        partnerBackendUrl: 'https://partner.example.com/api',
        generateEndpoint: 'generate',
      ));

  test('startAuthentication sends config and arguments, returns the nonce', () async {
    mock((_) async => 'n-123');
    final vb = client();
    final nonce = await vb.startAuthentication(
      validations: {'age': '18+'},
      returnUrl: 'myapp://callback',
    );
    expect(nonce, 'n-123');
    final args = calls.single.arguments as Map;
    expect(calls.single.method, 'startAuthentication');
    expect(args['id'], isA<int>());
    expect(args['validations'], {'age': '18+'});
    expect(args['returnUrl'], 'myapp://callback');
    final config = args['config'] as Map;
    expect(config['partnerBackendUrl'], 'https://partner.example.com/api');
    expect(config['generateEndpoint'], 'generate');
    expect(config['verifyblindAppLinkBase'], 'https://app.verifyblind.com/request');
    expect(config['verifyblindApiUrl'], 'https://api.verifyblind.com');
  });

  test('start and poll use the same native instance id', () async {
    mock((call) async => call.method == 'startAuthentication' ? 'n-1' : null);
    final vb = client();
    final other = client();
    final nonce = await vb.startAuthentication();
    expect(await vb.checkVerificationResult(nonce), isNull);
    await other.checkVerificationResult(nonce);
    final ids = calls.map((c) => (c.arguments as Map)['id']).toList();
    expect(ids[0], ids[1]);
    expect(ids[2], isNot(ids[0]));
  });

  test('checkVerificationResult returns a string-keyed map with the token', () async {
    mock((_) async => <Object?, Object?>{
          'token': 'dG9rZW4=',
          'validations': <Object?, Object?>{'age_over_18': true},
        });
    final result = await client().checkVerificationResult('n-1');
    expect(result!['token'], 'dG9rZW4=');
    expect(result['validations'], isA<Map<String, Object?>>());
    expect((result['validations'] as Map)['age_over_18'], true);
  });

  test('a cancellation becomes a typed exception with the reason', () async {
    mock((_) async => throw PlatformException(
          code: 'USER_CANCELLED',
          message: 'Kullanıcı doğrulama isteğini reddetti.',
          details: {'cancelReason': 'user_declined'},
        ));
    await expectLater(
      client().checkVerificationResult('n-1'),
      throwsA(isA<VerifyBlindException>()
          .having((e) => e.code, 'code', VerifyBlindErrorCode.userCancelled)
          .having((e) => e.cancelReason, 'cancelReason', 'user_declined')),
    );
  });

  test('unknown native codes map to unknown', () async {
    mock((_) async => throw PlatformException(code: 'SOMETHING_NEW', message: 'x'));
    await expectLater(
      client().startAuthentication(),
      throwsA(isA<VerifyBlindException>()
          .having((e) => e.code, 'code', VerifyBlindErrorCode.unknown)),
    );
  });

  test('an empty partnerBackendUrl is rejected', () {
    expect(() => VerifyBlindConfig(partnerBackendUrl: ' '), throwsArgumentError);
  });
}
