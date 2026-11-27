import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trono/config/supabase_config.dart';
import 'package:trono/services/google_native_auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GoogleNativeAuthService (V2.8.1 Native One-Tap)', () {
    const channel = MethodChannel('com.trono.trono/google_auth_test');
    final recordedCalls = <MethodCall>[];

    tearDown(() {
      recordedCalls.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('generates unique secure nonces and valid lowercase SHA-256 hashes', () {
      final n1 = GoogleNativeAuthService.generateNonce();
      final n2 = GoogleNativeAuthService.generateNonce();
      expect(n1.length, greaterThanOrEqualTo(32));
      expect(n1, isNot(n2));

      final hashed = GoogleNativeAuthService.hashNonce(n1);
      expect(hashed, sha256.convert(utf8.encode(n1)).toString());
      expect(hashed.length, 64);
    });

    test('returns ok with idToken + rawNonce and sends hashedNonce to native', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            recordedCalls.add(call);
            return {'status': 'ok', 'idToken': 'fake.google.id.token'};
          });

      final service = GoogleNativeAuthService(channel: channel);
      final result = await service.requestIdToken(
        serverClientId: '12345.apps.googleusercontent.com',
      );

      expect(result.status, GoogleNativeAuthStatus.ok);
      expect(result.idToken, 'fake.google.id.token');
      expect(result.rawNonce, isNotNull);
      expect(recordedCalls.length, 1);
      expect(recordedCalls.first.method, 'signInWithGoogleNative');
      final args = Map<String, Object?>.from(
        recordedCalls.first.arguments as Map,
      );
      expect(args['serverClientId'], '12345.apps.googleusercontent.com');
      expect(
        args['nonce'],
        GoogleNativeAuthService.hashNonce(result.rawNonce!),
      );
    });

    test('returns cancelled when user dismisses the native Google sheet', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            return {'status': 'cancelled'};
          });

      final service = GoogleNativeAuthService(channel: channel);
      final result = await service.requestIdToken();
      expect(result.status, GoogleNativeAuthStatus.cancelled);
      expect(result.idToken, isNull);
    });

    test('returns unavailable when native returns unavailable or channel is missing', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            return {'status': 'unavailable'};
          });

      final service = GoogleNativeAuthService(channel: channel);
      expect(
        (await service.requestIdToken()).status,
        GoogleNativeAuthStatus.unavailable,
      );

      const missing = MethodChannel('com.trono.trono/google_auth_missing');
      final missingService = GoogleNativeAuthService(channel: missing);
      expect(
        (await missingService.requestIdToken()).status,
        GoogleNativeAuthStatus.unavailable,
      );
    });

    test('surfaces native diagnostic errorMessage when unavailable', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            return {
              'status': 'unavailable',
              'error': 'GetCredentialProviderConfigurationException: missing',
            };
          });

      final service = GoogleNativeAuthService(channel: channel);
      final result = await service.requestIdToken();
      expect(result.status, GoogleNativeAuthStatus.unavailable);
      expect(
        result.errorMessage,
        'GetCredentialProviderConfigurationException: missing',
      );
    });

    test('configures default public Google Web Client ID & Android R8 keep rules', () {
      expect(
        SupabaseConfig.googleWebClientId,
        endsWith('.apps.googleusercontent.com'),
      );
      final proguard = File('android/app/proguard-rules.pro');
      expect(proguard.existsSync(), isTrue);
      final rules = proguard.readAsStringSync();
      expect(rules, contains('androidx.credentials.playservices.**'));
      expect(rules, contains('com.google.android.libraries.identity.googleid.**'));

      final keepXml = File('android/app/src/main/res/raw/keep.xml');
      expect(keepXml.existsSync(), isTrue);
      expect(keepXml.readAsStringSync(), contains('default_web_client_id'));
    });
  });
}
