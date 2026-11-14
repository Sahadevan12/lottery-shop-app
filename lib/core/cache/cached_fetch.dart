import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/presentation/auth_controller.dart';
import '../network/connectivity_service.dart';
import '../supabase/supabase_config.dart';
import 'app_cache_db.dart';

class CachedFetchResult<T> {
  const CachedFetchResult({
    required this.data,
    required this.cachedAt,
    required this.isFromCache,
  });

  final T data;
  final DateTime cachedAt;
  final bool isFromCache;
}

/// Shared read-through / offline-fallback helper keyed by auth user id.
abstract final class CachedFetch {
  static String currentUserId(Ref ref) {
    try {
      final String? ownerId = ref.read(authControllerProvider).shop?.ownerId;
      if (ownerId != null && ownerId.isNotEmpty) {
        return ownerId;
      }
      final String? repoUserId = ref.read(authRepositoryProvider).currentUserId;
      if (repoUserId != null && repoUserId.isNotEmpty) {
        return repoUserId;
      }
    } catch (_) {
      // Widget tests that do not override authRepositoryProvider when
      // SupabaseConfig is uninitialized should not fail on cache lookup.
    }
    return SupabaseConfig.clientOrNull?.auth.currentUser?.id ?? '';
  }

  static Future<CachedFetchResult<T>> run<T>({
    required Ref ref,
    required String cacheKey,
    required Future<T> Function() remoteFetch,
    required Object Function(T data) toJson,
    required T Function(Object json) fromJson,
  }) async {
    final String userId = currentUserId(ref);
    final AppCacheDb cacheDb = ref.read(appCacheDbProvider);
    final ConnectivityController connectivity =
        ref.read(isOnlineProvider.notifier);

    try {
      final T data = await remoteFetch();
      final DateTime now = DateTime.now();
      connectivity.markOnline();
      if (userId.isNotEmpty) {
        await cacheDb.putJson(
          userId: userId,
          key: cacheKey,
          value: toJson(data),
          now: now,
        );
      }
      return CachedFetchResult<T>(
        data: data,
        cachedAt: now,
        isFromCache: false,
      );
    } catch (e) {
      if (ConnectivityController.isNetworkError(e)) {
        connectivity.markOffline();
        if (userId.isNotEmpty) {
          final cached = await cacheDb.getJson(userId: userId, key: cacheKey);
          if (cached != null) {
            return CachedFetchResult<T>(
              data: fromJson(cached.data),
              cachedAt: cached.cachedAt,
              isFromCache: true,
            );
          }
        }
      }
      rethrow;
    }
  }
}
