import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:verifyblind_flutter/verifyblind_flutter.dart';

/// Public test backend. Its `generate` endpoint stores the nonce with the asked condition; its
/// `verify` endpoint checks the signed token. The API key lives there, never in this app.
const String kPartnerBackendUrl = 'https://test.verifyblind.com/api';
const String kGenerateEndpoint = 'generate';
const String kVerifyUrl = 'https://test.verifyblind.com/api/verify';

/// VerifyBlind opens this when it is done. The scheme is declared in AndroidManifest.xml /
/// Info.plist and registered as "App Return Scheme" in the Partner Portal.
const String kReturnUrl = 'verifyblinddemo://callback';

void main() => runApp(const ExampleApp());

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'VerifyBlind Flutter',
        theme: ThemeData(colorSchemeSeed: const Color(0xFF2563EB), useMaterial3: true),
        home: const VerifyScreen(),
      );
}

class VerifyScreen extends StatefulWidget {
  const VerifyScreen({super.key});

  @override
  State<VerifyScreen> createState() => _VerifyScreenState();
}

class _VerifyScreenState extends State<VerifyScreen> with WidgetsBindingObserver {
  // Same instance from start to poll: the native side keeps the temporary key pair on it.
  final VerifyBlind _vb = VerifyBlind(VerifyBlindConfig(
    partnerBackendUrl: kPartnerBackendUrl,
    generateEndpoint: kGenerateEndpoint,
  ));

  String? _activeNonce;
  bool _polling = false;
  bool _busy = false;
  int _pollGeneration = 0;
  String _status = 'Ready.';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _vb.dispose();
    super.dispose();
  }

  // Poll only in the foreground (the native demos do the same): start on resume, stop on pause.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _pollIfNeeded();
    } else if (state == AppLifecycleState.paused) {
      _pollGeneration++; // stops the running loop
      _polling = false;
    }
  }

  Future<void> _start() async {
    setState(() {
      _busy = true;
      _status = 'Opening VerifyBlind...';
    });
    try {
      // In a real app your server's start endpoint decides what to ask, not the phone.
      final nonce = await _vb.startAuthentication(
        validations: const {'age': '18+'},
        returnUrl: kReturnUrl,
      );
      _activeNonce = nonce;
      setState(() => _status = 'Finish in the VerifyBlind app, then come back.');
      // Polling starts when the app comes back to the foreground.
    } on VerifyBlindException catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pollIfNeeded() async {
    final nonce = _activeNonce;
    if (nonce == null || _polling) return;
    _polling = true;
    final gen = ++_pollGeneration;
    setState(() {
      _busy = true;
      _status = 'Waiting for the result...';
    });
    try {
      for (var i = 0; i < 60; i++) {
        await Future<void>.delayed(const Duration(seconds: 1));
        if (gen != _pollGeneration || !mounted) return;
        final Map<String, Object?>? result;
        try {
          result = await _vb.checkVerificationResult(nonce);
        } on VerifyBlindException catch (e) {
          _activeNonce = null;
          _showError(e);
          return;
        }
        if (result != null) {
          _activeNonce = null;
          await _verifyOnServer(result['token'] as String?);
          return;
        }
      }
      // Timed out: keep the nonce, try again next time the app comes to the foreground.
      setState(() => _status = 'No result yet. Come back to the app to check again.');
    } finally {
      if (gen == _pollGeneration) _polling = false;
      if (mounted) setState(() => _busy = false);
    }
  }

  /// The result on the phone is only for display. The decision is made on the server: it checks
  /// the signature, uses the nonce once and reads the condition it stored with that nonce.
  Future<void> _verifyOnServer(String? token) async {
    if (token == null || token.isEmpty) {
      setState(() => _status = 'Rejected: no signed token in the result.');
      return;
    }
    setState(() => _status = 'Verifying on the server...');
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
    try {
      final req = await client.postUrl(Uri.parse(kVerifyUrl));
      req.headers.contentType = ContentType.json;
      req.write(jsonEncode({'token': token}));
      final res = await req.close().timeout(const Duration(seconds: 15));
      final body = await res.transform(utf8.decoder).join();
      Object? json;
      try {
        json = jsonDecode(body);
      } catch (_) {}
      final ok = res.statusCode >= 200 &&
          res.statusCode < 300 &&
          json is Map &&
          json['success'] == true;
      if (ok) {
        setState(() => _status = 'Verified by the server.');
      } else {
        final err = json is Map && json['error'] is String ? json['error'] : 'HTTP ${res.statusCode}';
        setState(() => _status = 'Server rejected: $err');
      }
    } catch (e) {
      setState(() => _status = 'Could not reach the server. Check your connection.');
    } finally {
      client.close();
    }
  }

  void _showError(VerifyBlindException e) {
    if (!mounted) return;
    final String text;
    if (e.code == VerifyBlindErrorCode.userCancelled) {
      text = switch (e.cancelReason) {
        'no_card_registered' => 'No ID card in the VerifyBlind app yet.',
        'user_declined' => 'You declined the request.',
        'fingerprint_failed' => 'Biometric check failed.',
        'session_expired' => 'The session expired. Try again.',
        _ => 'Cancelled.',
      };
    } else if (e.code == VerifyBlindErrorCode.networkError) {
      text = 'Could not reach the server. Check your connection.';
    } else {
      text = 'Error (${e.code.raw}): ${e.message}';
    }
    setState(() => _status = text);
  }

  void _reset() {
    _pollGeneration++;
    _polling = false;
    _activeNonce = null;
    setState(() {
      _busy = false;
      _status = 'Ready.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('VerifyBlind Flutter example')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Asks VerifyBlind whether you are 18 or older. '
                  'The answer is checked by the server, not by this phone.'),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _busy ? null : _start,
                child: const Text('Verify with VerifyBlind'),
              ),
              if (_activeNonce != null) ...[
                const SizedBox(height: 8),
                OutlinedButton(onPressed: _reset, child: const Text('Cancel waiting')),
              ],
              const SizedBox(height: 24),
              if (_busy) const LinearProgressIndicator(),
              const SizedBox(height: 12),
              Text(_status, style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
        ),
      ),
    );
  }
}
