import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/services/haptics_service.dart';
import '../../../../core/theme/telly_colors.dart';
import '../../../../core/theme/telly_typography.dart';
import '../../../../core/widgets/telly_avatar.dart';
import '../../../../core/widgets/telly_screen_header.dart';
import '../../../feed/domain/social_models.dart';
import '../../domain/user_search_result.dart';
import '../controllers/user_search_controller.dart';

/// SCR-28: Search Users / Find Friends Screen (epic #48).
///
/// Provides debounced user search by @handle and display name,
/// live taste match badges, and inline follow/request actions.
class SearchUsersScreen extends ConsumerStatefulWidget {
  const SearchUsersScreen({super.key});

  @override
  ConsumerState<SearchUsersScreen> createState() => _SearchUsersScreenState();
}

class _SearchUsersScreenState extends ConsumerState<SearchUsersScreen> {
  late final TextEditingController _queryController;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _queryController = TextEditingController();
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _queryController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onQueryChanged(String query) {
    ref.read(userSearchProvider.notifier).search(query);
    setState(() {}); // updates clear button visibility
  }

  void _clearSearch() {
    _queryController.clear();
    ref.read(userSearchProvider.notifier).search('');
    setState(() {});
  }

  void _openProfile(String handle) {
    HapticsService.lightImpact();
    context.push(Routes.profile(handle));
  }

  @override
  Widget build(BuildContext context) {
    final searchAsync = ref.watch(userSearchProvider);
    final searchNotifier = ref.read(userSearchProvider.notifier);
    final currentQuery = searchNotifier.currentQuery.trim();

    final canvasColor = TellyColors.canvasOf(context);
    final surfaceColor = TellyColors.surfaceOf(context);
    final primaryAccent = TellyColors.primaryAccentOf(context);
    final strokeColor = TellyColors.strokeSubtleOf(context);
    final textPrimary = TellyColors.textPrimaryOf(context);
    final textTertiary = TellyColors.textTertiaryOf(context);

    return Scaffold(
      backgroundColor: canvasColor,
      appBar: const TellySubpageAppBar(
        title: 'Find Friends',
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Search input bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Container(
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: strokeColor),
              ),
              child: TextField(
                key: const Key('user_search_input'),
                controller: _queryController,
                focusNode: _focusNode,
                autofocus: true,
                style: TellyTypography.bodyLarge(color: textPrimary),
                cursorColor: primaryAccent,
                onChanged: _onQueryChanged,
                decoration: InputDecoration(
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: textTertiary,
                    size: 20,
                  ),
                  suffixIcon: _queryController.text.isNotEmpty
                      ? IconButton(
                          key: const Key('user_search_clear_button'),
                          icon: Icon(
                            Icons.close_rounded,
                            color: textTertiary,
                            size: 18,
                          ),
                          onPressed: _clearSearch,
                        )
                      : null,
                  hintText: 'Search by name or @handle...',
                  hintStyle: TellyTypography.bodyMedium(color: textTertiary),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),
          ),

          // Content body
          Expanded(
            child: searchAsync.when(
              loading: () => const Center(
                key: Key('user_search_loading'),
                child: CircularProgressIndicator(),
              ),
              error: (error, _) => Center(
                key: const Key('user_search_error'),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.wifi_off_rounded, size: 48, color: textTertiary),
                      const SizedBox(height: 12),
                      Text(
                        'User search requires an internet connection.',
                        textAlign: TextAlign.center,
                        style: TellyTypography.bodyMedium(color: textTertiary),
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton(
                        key: const Key('user_search_retry_button'),
                        onPressed: () {
                          ref.read(userSearchProvider.notifier).search(_queryController.text);
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: primaryAccent,
                          side: BorderSide(color: primaryAccent),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
              data: (users) {
                if (currentQuery.isEmpty) {
                  return Center(
                    key: const Key('user_search_empty_prompt'),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.person_search_outlined,
                            size: 56,
                            color: textTertiary.withValues(alpha: 0.6),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            "Search for friends by name or @handle to see what they're watching.",
                            textAlign: TextAlign.center,
                            style: TellyTypography.bodyMedium(color: textTertiary),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                if (users.isEmpty) {
                  return Center(
                    key: const Key('user_search_no_results'),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32.0),
                      child: Text(
                        "No users found matching '$currentQuery'.",
                        textAlign: TextAlign.center,
                        style: TellyTypography.bodyMedium(color: textTertiary),
                      ),
                    ),
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: Text(
                        'MATCHES',
                        style: TellyTypography.caption(color: textTertiary).copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView.separated(
                        key: const Key('user_search_results_list'),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        itemCount: users.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final user = users[index];
                          return _UserSearchCard(
                            key: Key('user_search_card_${user.handle}'),
                            user: user,
                            onTap: () => _openProfile(user.handle),
                            onFollowTap: () {
                              HapticsService.selectionClick();
                              ref.read(userSearchProvider.notifier).toggleFollow(user.id);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _UserSearchCard extends StatelessWidget {
  final UserSearchResult user;
  final VoidCallback onTap;
  final VoidCallback onFollowTap;

  const _UserSearchCard({
    super.key,
    required this.user,
    required this.onTap,
    required this.onFollowTap,
  });

  @override
  Widget build(BuildContext context) {
    final surfaceColor = TellyColors.surfaceOf(context);
    final strokeColor = TellyColors.strokeSubtleOf(context);
    final textPrimary = TellyColors.textPrimaryOf(context);
    final textTertiary = TellyColors.textTertiaryOf(context);
    final violet = TellyColors.electricVioletOf(context);

    return Material(
      color: surfaceColor,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: strokeColor),
          ),
          child: Row(
            children: [
              TellyAvatar(
                name: user.displayName.isNotEmpty ? user.displayName : user.handle,
                imageUrl: user.avatarUrl,
                radius: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      user.displayName.isNotEmpty ? user.displayName : user.handle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TellyTypography.bodyLarge(color: textPrimary).copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '@${user.handle}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TellyTypography.caption(color: textTertiary),
                    ),
                    if (user.tasteMatchPercent != null && user.tasteMatchPercent! > 0) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: violet.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: violet.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '🎯 ${user.tasteMatchPercent}% Taste Match',
                              style: TellyTypography.caption(color: violet).copyWith(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _FollowButton(
                key: Key('user_search_follow_${user.handle}'),
                status: user.followStatus,
                onPressed: onFollowTap,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FollowButton extends StatelessWidget {
  final FollowStatus? status;
  final VoidCallback onPressed;

  const _FollowButton({
    super.key,
    required this.status,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final primaryAccent = TellyColors.primaryAccentOf(context);
    final warmAmber = TellyColors.warmAmberOf(context);
    final strokeColor = TellyColors.strokeSubtleOf(context);
    final textPrimary = TellyColors.textPrimaryOf(context);

    final String label;
    final Color textColor;
    final Color borderColor;

    switch (status) {
      case null:
      case FollowStatus.rejected:
        label = '+ Follow';
        textColor = primaryAccent;
        borderColor = primaryAccent;
      case FollowStatus.pending:
        label = 'Requested';
        textColor = warmAmber;
        borderColor = warmAmber;
      case FollowStatus.accepted:
        label = 'Following';
        textColor = textPrimary;
        borderColor = strokeColor;
      case FollowStatus.blocked:
        label = 'Blocked';
        textColor = textPrimary;
        borderColor = strokeColor;
    }

    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: textColor,
        side: BorderSide(color: borderColor),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: Text(
        label,
        style: TellyTypography.caption(color: textColor).copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
