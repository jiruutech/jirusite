import 'dart:convert';

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
    final dio = ref.read(dioClientProvider);
    await dio.post(ApiEndpoints.otpRequest,
        data: {'phone_number': phone, 'purpose': purpose});
  }

  Future<void> setupOrganization(String name, String? tin) async {
    final dio = ref.read(dioClientProvider);
    final resp = await dio.post(ApiEndpoints.orgCreate, data: {
      'name': name,
      if (tin != null) 'tin_number': tin,
    });

    final userJson = await _storage.read(key: 'user_json');
    if (userJson != null) {
      final raw =
          jsonDecode(userJson) as Map<String, dynamic>;
      final orgId = resp.data['id'] as String;
      raw['organization_id'] = orgId;
      await _storage.write(key: 'user_json', value: jsonEncode(raw));

      final updated = AuthUser.fromJson(raw);
      _initSync(updated);
      state = AsyncData(AuthAppState(user: updated));
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
    return e.toString().replaceAll('Exception: ', '');
  }
}
