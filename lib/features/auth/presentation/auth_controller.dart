import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/auth_repository.dart';
import '../domain/shop_profile.dart';

enum AuthStage {
  unauthenticated,
  needsShopSetup,
  authenticated,
}

@immutable
class AuthState {
  const AuthState({
    this.stage = AuthStage.unauthenticated,
    this.shop,
    this.isLoading = false,
    this.errorMessage,
  });

  final AuthStage stage;
  final ShopProfile? shop;
  final bool isLoading;
  final String? errorMessage;

  AuthState copyWith({
    AuthStage? stage,
    ShopProfile? shop,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
    bool clearShop = false,
  }) {
    return AuthState(
      stage: stage ?? this.stage,
      shop: clearShop ? null : (shop ?? this.shop),
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

final Provider<AuthRepository> authRepositoryProvider =
    Provider<AuthRepository>((Ref ref) {
  return createAuthRepository();
});

final NotifierProvider<AuthController, AuthState> authControllerProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);

class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() {
    final AuthRepository repo = ref.watch(authRepositoryProvider);
    if (repo.currentUserId == null) {
      return const AuthState(stage: AuthStage.unauthenticated);
    }
    // Load existing shop asynchronously if a session is persisted
    Future<void>.microtask(_restoreSession);
    return const AuthState(isLoading: true);
  }

  Future<void> _restoreSession() async {
    final AuthRepository repo = ref.read(authRepositoryProvider);
    try {
      final ShopProfile? shop = await repo.fetchCurrentShop();
      if (shop == null) {
        state = const AuthState(stage: AuthStage.needsShopSetup);
      } else {
        state = AuthState(stage: AuthStage.authenticated, shop: shop);
      }
    } catch (_) {
      state = const AuthState(stage: AuthStage.unauthenticated);
    }
  }

  Future<bool> signInWithPhoneAndPin({
    required String phone,
    required String pin,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    final AuthRepository repo = ref.read(authRepositoryProvider);
    try {
      await repo.signInOrSignUp(phone: phone, pin: pin);
      final ShopProfile? shop = await repo.fetchCurrentShop();
      if (shop == null) {
        state = const AuthState(stage: AuthStage.needsShopSetup);
      } else {
        state = AuthState(stage: AuthStage.authenticated, shop: shop);
      }
      return true;
    } catch (err) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: err.toString(),
      );
      return false;
    }
  }

  Future<bool> completeShopSetup({
    required String name,
    required String ownerName,
    required String district,
    String? agentCode,
    required String language,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    final AuthRepository repo = ref.read(authRepositoryProvider);
    try {
      final ShopProfile shop = await repo.createShopWithDefaults(
        name: name,
        ownerName: ownerName,
        district: district,
        agentCode: agentCode,
        language: language,
      );
      state = AuthState(stage: AuthStage.authenticated, shop: shop);
      return true;
    } catch (err) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: err.toString(),
      );
      return false;
    }
  }

  Future<void> signOut() async {
    final AuthRepository repo = ref.read(authRepositoryProvider);
    await repo.signOut();
    state = const AuthState(
      stage: AuthStage.unauthenticated,
    );
  }
}
