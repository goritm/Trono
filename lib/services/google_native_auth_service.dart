import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';

enum GoogleNativeAuthStatus { ok, cancelled, unavailable }

class GoogleNativeAuthResult {
  const GoogleNativeAuthResult({
    required this.status,
    this.idToken,
    this.rawNonce,
  });

  final GoogleNativeAuthStatus status;
  final String? idToken;
  final String? rawNonce;
}

/// Thrown when the user explicitly dismisses the native Google One-Tap sheet.
class GoogleSignInCancelledException implements Exception {
  const GoogleSignInCancelledException();
}

/// Zero-plugin bridge to Android's native Credential Manager Google One-Tap
/// bottom sheet (`GetGoogleIdOption`), with cryptographic SHA-256 nonce
/// generation for `Supabase.auth.signInWithIdToken(...)`.
class GoogleNativeAuthService {
  GoogleNativeAuthService({MethodChannel? channel})
    : _channel = channel ?? defaultChannel;

  static const MethodChannel defaultChannel = MethodChannel(
    'com.trono.trono/google_auth',
  );

  final MethodChannel _channel;

  static String generateNonce([int byteLength = 32]) {
    final random = Random.secure();
    final bytes = List<int>.generate(byteLength, (_) => random.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }

  static String hashNonce(String rawNonce) {
    return sha256.convert(utf8.encode(rawNonce)).toString();
  }

  Future<GoogleNativeAuthResult> requestIdToken({String? serverClientId}) async {
    final rawNonce = generateNonce();
    final hashedNonce = hashNonce(rawNonce);
    try {
      final res = await _channel.invokeMethod<Map<Object?, Object?>>(
        'signInWithGoogleNative',
        {
          'nonce': hashedNonce,
          if (serverClientId != null && serverClientId.trim().isNotEmpty)
            'serverClientId': serverClientId.trim(),
        },
      );
      final status = (res?['status'] as String?)?.trim() ?? 'unavailable';
      final idToken = (res?['idToken'] as String?)?.trim() ?? '';
      if (status == 'ok' && idToken.isNotEmpty) {
        return GoogleNativeAuthResult(
          status: GoogleNativeAuthStatus.ok,
          idToken: idToken,
          rawNonce: rawNonce,
        );
      }
      if (status == 'cancelled') {
        return const GoogleNativeAuthResult(
          status: GoogleNativeAuthStatus.cancelled,
        );
      }
      return const GoogleNativeAuthResult(
        status: GoogleNativeAuthStatus.unavailable,
      );
    } on MissingPluginException {
      return const GoogleNativeAuthResult(
        status: GoogleNativeAuthStatus.unavailable,
      );
    } on PlatformException {
      return const GoogleNativeAuthResult(
        status: GoogleNativeAuthStatus.unavailable,
      );
    }
  }
}
