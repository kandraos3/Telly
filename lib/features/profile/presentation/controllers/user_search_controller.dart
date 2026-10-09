import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/data/auth_repository.dart';
import '../../../feed/domain/social_models.dart';
import '../../data/profile_repository.dart';
import '../../domain/user_search_result.dart';

class UserSearchController extends AutoDisposeAsyncNotifier<List<UserSearchResult>> {
  String _currentQuery = '';
  String get currentQuery => _currentQuery;

  @override
  Future<List<UserSearchResult>> build() async => const [];

  Future<void> search(String query) async {
    _currentQuery = query;
    final clean = query.trim();
    if (clean.isEmpty) {
      state = const AsyncData([]);
      return;
    }
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(profileRepositoryProvider).searchUsers(clean),
    );
  }

  Future<void> toggleFollow(String userId) async {
    final currentList = state.valueOrNull;
    if (currentList == null) return;

    final index = currentList.indexWhere((u) => u.id == userId);
    if (index == -1) return;

    final user = currentList[index];
    final me = ref.read(authRepositoryProvider).currentUserId;
    if (me != null && user.id == me) {
      throw StateError('Cannot follow yourself');
    }

    final repo = ref.read(profileRepositoryProvider);
    if (user.followStatus == null || user.followStatus == FollowStatus.rejected) {
      final newStatus = await repo.followUser(userId);
      final updatedList = List<UserSearchResult>.from(currentList);
      updatedList[index] = user.copyWith(followStatus: newStatus);
      state = AsyncData(updatedList);
    } else {
      await repo.unfollowUser(userId);
      final updatedList = List<UserSearchResult>.from(currentList);
      updatedList[index] = user.copyWith(clearFollowStatus: true);
      state = AsyncData(updatedList);
    }
  }

  Future<void> respondToFollow({required String requesterId, required bool approve}) async {
    final currentList = state.valueOrNull;
    final repo = ref.read(profileRepositoryProvider);
    final newStatus = await repo.respondToFollowRequest(requesterId: requesterId, approve: approve);

    if (currentList != null) {
      final index = currentList.indexWhere((u) => u.id == requesterId);
      if (index != -1) {
        final updatedList = List<UserSearchResult>.from(currentList);
        updatedList[index] = updatedList[index].copyWith(followStatus: newStatus);
        state = AsyncData(updatedList);
      }
    }
  }
}

final userSearchProvider =
    AutoDisposeAsyncNotifierProvider<UserSearchController, List<UserSearchResult>>(
  UserSearchController.new,
);
