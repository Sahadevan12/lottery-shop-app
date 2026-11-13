import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_config.dart';
import '../../../core/utils/validators.dart';
import '../domain/shop_profile.dart';

/// Repository interface for Phone + PIN authentication and shop setup (§6.2, §6.5).
abstract interface class AuthRepository {
  String? get currentUserId;
  String? get currentPhone;

  /// Signs in with 10-digit phone + 6-digit PIN mapped to `<10-digit-phone>@luckyledger.app`.
  /// Automatically registers the user if the account does not exist yet.
  Future<void> signInOrSignUp({
    required String phone,
    required String pin,
  });

  /// Fetches the owner's `ShopProfile`, or `null` if first-time login (needs shop setup).
  Future<ShopProfile?> fetchCurrentShop();

  /// Calls `create_shop_with_defaults` RPC to create the shop + default lotteries + template.
  Future<ShopProfile> createShopWithDefaults({
    required String name,
    required String ownerName,
    required String district,
    String? agentCode,
    required String language,
  });

  Future<void> signOut();
}

/// Production Supabase implementation (§6.2, §6.5).
class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._client);

  final SupabaseClient _client;
  String? _lastPhone;

  @override
  String? get currentUserId => _client.auth.currentUser?.id;

  @override
  String? get currentPhone {
    if (_lastPhone != null) {
      return _lastPhone;
    }
    final String? email = _client.auth.currentUser?.email;
    if (email == null || !email.contains('@')) {
      return null;
    }
    return email.split('@').first;
  }

  @override
  Future<void> signInOrSignUp({
    required String phone,
    required String pin,
  }) async {
    final String normalizedPhone = AppValidators.normalizePhone(phone);
    final String internalEmail =
        AppValidators.phoneToInternalEmail(normalizedPhone);
    _lastPhone = normalizedPhone;

    try {
      await _client.auth.signInWithPassword(
        email: internalEmail,
        password: pin,
      );
    } on AuthException catch (err) {
      final String msg = err.message.toLowerCase();
      if (msg.contains('invalid login credentials') ||
          msg.contains('user not found')) {
        final AuthResponse res = await _client.auth.signUp(
          email: internalEmail,
          password: pin,
        );
        if (res.session == null || _client.auth.currentUser == null) {
          throw const AuthException(
            'Turn OFF "Confirm email" in Supabase Dashboard → Authentication → Providers → Email, then sign in again.',
          );
        }
      } else {
        rethrow;
      }
    }
  }

  @override
  Future<ShopProfile?> fetchCurrentShop() async {
    final String? uid = currentUserId;
    if (uid == null) {
      return null;
    }
    final Map<String, dynamic>? row = await _client
        .from('shops')
        .select()
        .eq('owner_id', uid)
        .maybeSingle();
    if (row == null) {
      return null;
    }
    return ShopProfile.fromJson(row);
  }

  @override
  Future<ShopProfile> createShopWithDefaults({
    required String name,
    required String ownerName,
    required String district,
    String? agentCode,
    required String language,
  }) async {
    await _client.rpc<String>(
      'create_shop_with_defaults',
      params: <String, dynamic>{
        'p_name': name.trim(),
        'p_owner_name': ownerName.trim(),
        'p_district': district,
        'p_agent_code': (agentCode == null || agentCode.trim().isEmpty)
            ? null
            : agentCode.trim(),
        'p_language': language,
        'p_phone': currentPhone,
      },
    );
    final ShopProfile? shop = await fetchCurrentShop();
    if (shop == null) {
      throw StateError('Shop was not returned after create_shop_with_defaults');
    }
    return shop;
  }

  @override
  Future<void> signOut() async {
    _lastPhone = null;
    await _client.auth.signOut();
  }
}

AuthRepository createAuthRepository() {
  final SupabaseClient? client = SupabaseConfig.clientOrNull;
  if (client == null) {
    throw StateError(
      'SupabaseClient is not initialized. Pass --dart-define=SUPABASE_URL and SUPABASE_ANON_KEY, or override authRepositoryProvider in tests.',
    );
  }
  return SupabaseAuthRepository(client);
}
