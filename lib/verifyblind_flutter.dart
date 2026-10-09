/// Flutter wrapper for the VerifyBlind native mobile SDKs.
///
/// Android: `com.verifyblind:verifyblind-android` (Maven Central).
/// iOS: Swift Package `https://github.com/VerifyBlind/sdk-ios`.
///
/// The phone never decides. Send the `token` from [VerifyBlind.checkVerificationResult]
/// to your server; your server verifies the signature and the condition it asked for.
library;

import 'package:flutter/services.dart';

const MethodChannel _channel = MethodChannel('com.verifyblind/flutter');

/// Configuration, same fields as the native `VerifyBlindConfig`.
class VerifyBlindConfig {
  /// Your backend base URL (the proxy that holds the API key).
  /// Example: `https://partner.example.com/api`
  final String partnerBackendUrl;

  /// Start endpoint, relative to [partnerBackendUrl]. `"."` means the base URL itself.
  /// Example: `"generate"`
  final String generateEndpoint;

  /// VerifyBlind app link base.
  final String verifyblindAppLinkBase;

  /// VerifyBlind relay URL used for polling the result.
  final String verifyblindApiUrl;

  /// Development only: turns off certificate pinning for your backend. Never `true` in production.
  final bool skipSecurityChecks;

  /// Optional SPKI SHA-256 pins for your backend (`"sha256/BASE64..."`). `null` = no pinning.
  final List<String>? certificatePins;

  VerifyBlindConfig({
    required this.partnerBackendUrl,
    this.generateEndpoint = '.',
    this.verifyblindAppLinkBase = 'https://app.verifyblind.com/request',
    this.verifyblindApiUrl = 'https://api.verifyblind.com',
    this.skipSecurityChecks = false,
    this.certificatePins,
  }) {
    if (partnerBackendUrl.trim().isEmpty) {
      throw ArgumentError.value(partnerBackendUrl, 'partnerBackendUrl', 'must not be empty');
    }
  }

  Map<String, Object?> toMap() => <String, Object?>{
        'partnerBackendUrl': partnerBackendUrl,
        'generateEndpoint': generateEndpoint,
        'verifyblindAppLinkBase': verifyblindAppLinkBase,
        'verifyblindApiUrl': verifyblindApiUrl,
        'skipSecurityChecks': skipSecurityChecks,
        'certificatePins': certificatePins,
      };
}

/// Error codes. Same names as the native SDKs (Android `ErrorCode`, iOS `VerifyBlindError.Code`).
enum VerifyBlindErrorCode {
  ipFetchFailed('IP_FETCH_FAILED'),
  networkError('NETWORK_ERROR'),
  partnerBackendError('PARTNER_BACKEND_ERROR'),
  invalidResponse('INVALID_RESPONSE'),
  appLinkFailed('APP_LINK_FAILED'),
  userCancelled('USER_CANCELLED'),

  /// iOS only (key generation / decryption failed).
  cryptoError('CRYPTO_ERROR'),

  /// The plugin was called wrongly (for example a missing argument).
  invalidArgument('INVALID_ARGUMENT'),
  unknown('UNKNOWN');

  const VerifyBlindErrorCode(this.raw);

  /// The string the native SDK uses.
  final String raw;

  static VerifyBlindErrorCode fromRaw(String? raw) {
    for (final c in values) {
      if (c.raw == raw) return c;
    }
    return VerifyBlindErrorCode.unknown;
  }
}

/// Thrown by [VerifyBlind] methods.
class VerifyBlindException implements Exception {
  final VerifyBlindErrorCode code;

  /// Developer-facing message from the native SDK (Turkish). Do not show it to end users as is.
  final String message;

  /// Set when [code] is [VerifyBlindErrorCode.userCancelled]:
  /// `user_cancelled`, `no_card_registered`, `user_declined`, `fingerprint_failed`, `session_expired`.
  /// Treat unknown values like `user_cancelled`.
  final String? cancelReason;

  const VerifyBlindException(this.code, this.message, {this.cancelReason});

  factory VerifyBlindException.fromPlatform(PlatformException e) {
    final details = e.details;
    String? reason;
    if (details is Map) {
      final r = details['cancelReason'];
      if (r is String && r.isNotEmpty) reason = r;
    }
    return VerifyBlindException(
      VerifyBlindErrorCode.fromRaw(e.code),
      e.message ?? e.code,
      cancelReason: reason,
    );
  }

  @override
  String toString() => 'VerifyBlindException(${code.raw}'
      '${cancelReason != null ? ', $cancelReason' : ''}): $message';
}

/// One verification client. Keep the same instance between [startAuthentication] and
/// [checkVerificationResult]: the native side holds the temporary key pair for it.
class VerifyBlind {
  static int _nextId = 0;

  final VerifyBlindConfig config;
  final int _id;
  final MethodChannel _ch;

  VerifyBlind(this.config)
      : _id = _nextId++,
        _ch = _channel;

  /// For tests: use another channel.
  VerifyBlind.withChannel(this.config, MethodChannel channel)
      : _id = _nextId++,
        _ch = channel;

  Map<String, Object?> _args([Map<String, Object?> extra = const {}]) =>
      <String, Object?>{'id': _id, 'config': config.toMap(), ...extra};

  /// Creates a temporary key pair on the device, asks your backend for a nonce and opens the
  /// VerifyBlind app. Returns the nonce.
  ///
  /// [validations]: what to ask, e.g. `{'age': '18+'}`. In a real app your server's start
  /// endpoint should decide this, not the phone.
  /// [returnUrl]: deep link VerifyBlind opens when done, e.g. `myapp://callback`. Its scheme must
  /// match the "App Return Scheme" in the Partner Portal, or VerifyBlind will not open it.
  Future<String> startAuthentication({
    Map<String, Object>? validations,
    Map<String, Object>? customData,
    String? returnUrl,
  }) async {
    try {
      final nonce = await _ch.invokeMethod<String>('startAuthentication', _args({
        'validations': validations,
        'customData': customData,
        'returnUrl': returnUrl,
      }));
      if (nonce == null || nonce.isEmpty) {
        throw const VerifyBlindException(
            VerifyBlindErrorCode.invalidResponse, 'No nonce returned.');
      }
      return nonce;
    } on PlatformException catch (e) {
      throw VerifyBlindException.fromPlatform(e);
    }
  }

  /// Polls the VerifyBlind relay once.
  ///
  /// Returns `null` while the user has not finished. When finished, returns the decrypted result.
  /// Its `token` field is the signed answer: send it to your server, which verifies it.
  /// Never decide on the phone.
  ///
  /// Throws [VerifyBlindException] with [VerifyBlindErrorCode.userCancelled] and a
  /// [VerifyBlindException.cancelReason] if the user cancelled.
  Future<Map<String, Object?>?> checkVerificationResult(String nonce) async {
    try {
      final raw = await _ch.invokeMethod<Object?>(
          'checkVerificationResult', _args({'nonce': nonce}));
      if (raw == null) return null;
      return _deepCast(raw as Map);
    } on PlatformException catch (e) {
      throw VerifyBlindException.fromPlatform(e);
    }
  }

  /// Frees the native instance (and its key pair). Call when you no longer need this client.
  Future<void> dispose() async {
    try {
      await _ch.invokeMethod<void>('dispose', <String, Object?>{'id': _id});
    } on PlatformException {
      // ignore
    }
  }

  static Map<String, Object?> _deepCast(Map m) => m.map<String, Object?>(
        (k, v) => MapEntry(k.toString(), v is Map ? _deepCast(v) : v),
      );
}
