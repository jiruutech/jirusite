import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/sync/sync_engine.dart';
import '../../domain/models/auth_state.dart';

const _storage = FlutterSecureStorage();

final authStateProvider =
    AsyncNotifierProvider<AuthNotifier, AuthAppState>(AuthNotifier.new);

class AuthNotifier extends AsyncNotifier<AuthAppState> {
  @override
  Future<AuthAppState> build() async {
    final token = await _storage.read(key: 'access_token');
    if (token == null) return const AuthAppState();

    try {
      final userJson = await _storage.read(key: 'user_json');
      if (userJson == null) return const AuthAppState();

      final user = AuthUser.fromJson(
          jsonDecode(userJson) as Map<String, dynamic>);
      _initSync(user);
      return AuthAppState(user: user);
    } catch (_) {
      return const AuthAppState();
    }
  }

  Future<void> login(String phone, String password) async {
    state = const AsyncLoading();
    try {
      final dio = ref.read(dioClientProvider);
      final resp = await dio.post(ApiEndpoints.login, data: {
        'phone_number': phone,
        'password': password,
      });

      await _persistTokens(resp.data as Map<String, dynamic>);
      final user = AuthUser.fromJson(
          resp.data['user'] as Map<String, dynamic>);
      _initSync(user);
      state = AsyncData(AuthAppState(user: user));
    } catch (e) {
      state = AsyncData(AuthAppState(error: _parseError(e)));
    }
  }

  Future<void> register(
      String fullName, String phone, String password, String role) async {
    state = const AsyncLoading();
    try {
      final dio = ref.read(dioClientProvider);
      final resp = await dio.post(ApiEndpoints.register, data: {
        'full_name': fullName,
        'phone_number': phone,
        'password': password,
        'role': role,
      });

      await _persistTokens(resp.data as Map<String, dynamic>);
      final user = AuthUser.fromJson(
          resp.data['user'] as Map<String, dynamic>);
      state = AsyncData(AuthAppState(user: user));
    } catch (e) {
      state = AsyncData(AuthAppState(error: _parseError(e)));
    }
  }

  Future<void> requestOtp(String phone, {String purpose = 'verify'}) async {
    try {
      final dio = ref.read(dioClientProvider);
      await dio.post(ApiEndpoints.otpRequest,
          data: {'phone_number': phone, 'purpose': purpose});
    } catch (e) {
      // OTP send failure is non-blocking — caller handles UI feedback
      rethrow;
    }
  }

  Future<void> setupOrganization(String name, String? tin) async {
    try {
      final dio = ref.read(dioClientProvider);
      final resp = await dio.post(ApiEndpoints.orgCreate, data: {
        'name': name,
        if (tin != null) 'tin_number': tin,
      });

      final userJson = await _storage.read(key: 'user_json');
      if (userJson != null) {
        final raw = jsonDecode(userJson) as Map<String, dynamic>;
        final orgId = resp.data['id'] as String;
        raw['organization_id'] = orgId;
        await _storage.write(key: 'user_json', value: jsonEncode(raw));
        final updated = AuthUser.fromJson(raw);
        _initSync(updated);
        state = AsyncData(AuthAppState(user: updated));
      }
    } catch (e) {
      throw Exception(_parseError(e));
    }
  }

  Future<void> logout() async {
    try {
      final dio = ref.read(dioClientProvider);
      await dio.post(ApiEndpoints.logout);
    } catch (_) {}
    await _storage.deleteAll();
    state = const AsyncData(AuthAppState());
  }

  void _initSync(AuthUser user) {
    if (user.organizationId != null) {
      ref.read(syncEngineProvider).initialize(user.organizationId!);
    }
  }

  Future<void> _persistTokens(Map<String, dynamic> data) async {
    await _storage.write(
        key: 'access_token', value: data['accessToken'] as String);
    await _storage.write(
        key: 'refresh_token', value: data['refreshToken'] as String);
    if (data['user'] != null) {
      await _storage.write(
          key: 'user_json',
          value: jsonEncode(data['user']));
    }
  }

  String _parseError(dynamic e) {
    // 1. Dio HTTP errors — extract the server's own message first
    if (e is DioException) {
      // Connection-level failures
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        return 'Connection timed out. Check your internet and try again.';
      }
      if (e.type == DioExceptionType.connectionError) {
        return 'Could not reach the server. Check your internet connection.';
      }
      // Server returned a response — use its message if present
      final data = e.response?.data;
      if (data is Map) {
        final msg = data['error'] ?? data['message'] ?? data['detail'];
        if (msg is String && msg.isNotEmpty) {
          return _humanise(msg, e.response?.statusCode);
        }
      }
      // Fall back to status code
      return _humanise(null, e.response?.statusCode);
    }
    // 2. Any other exception — strip technical prefixes
    final raw = e.toString()
        .replaceAll('Exception: ', '')
        .replaceAll('DioException: ', '')
        .replaceAll('FormatException: ', '');
    // If it still looks like a stack trace or technical string, use generic
    if (raw.contains('\n') || raw.length > 120) {
      return 'Something went wrong. Please try again.';
    }
    return raw;
  }

  /// Convert a server error string + status code into plain language.
  String _humanise(String? serverMsg, int? statusCode) {
    // Specific server messages we control
    if (serverMsg != null) {
      if (serverMsg.toLowerCase().contains('invalid credentials') ||
          serverMsg.toLowerCase().contains('unauthorized')) {
        return 'Incorrect phone number or password.';
      }
      if (serverMsg.toLowerCase().contains('already registered') ||
          serverMsg.toLowerCase().contains('already exists')) {
        return 'This phone number is already registered. Try logging in.';
      }
      if (serverMsg.toLowerCase().contains('deactivated')) {
        return 'Your account has been deactivated. Contact support.';
      }
      if (serverMsg.toLowerCase().contains('otp') &&
          serverMsg.toLowerCase().contains('invalid')) {
        return 'Invalid or expired verification code. Request a new one.';
      }
      if (serverMsg.toLowerCase().contains('expired')) {
        return 'Your session has expired. Please log in again.';
      }
      if (serverMsg.toLowerCase().contains('not found')) {
        return 'Account not found. Please check your phone number.';
      }
    }
    // Status code fallbacks
    return switch (statusCode) {
      400 => 'Please check your information and try again.',
      401 => 'Incorrect phone number or password.',
      403 => 'You don\'t have permission to do that.',
      404 => 'Account not found. Please check your phone number.',
      409 => 'This phone number is already registered. Try logging in.',
      422 => 'Please check your information and try again.',
      429 => 'Too many attempts. Please wait a moment and try again.',
      500 || 502 || 503 => 'Server is temporarily unavailable. Try again shortly.',
      _ => 'Something went wrong. Please try again.',
    };
  }
}
