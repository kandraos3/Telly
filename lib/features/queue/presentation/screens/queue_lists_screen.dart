import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:telly_app/core/router/routes.dart';
import 'package:telly_app/core/theme/telly_colors.dart';
import 'package:telly_app/core/theme/telly_typography.dart';
import 'package:telly_app/core/widgets/telly_empty_state.dart';
import 'package:telly_app/core/widgets/telly_neon_badge.dart';
import 'package:telly_app/core/widgets/telly_screen_header.dart';
import 'package:telly_app/core/widgets/telly_section_header.dart';
import 'package:telly_app/core/widgets/telly_segmented_control.dart';
import 'package:telly_app/features/queue/data/custom_list_repository.dart';
import 'package:telly_app/features/queue/domain/custom_list_models.dart';
import 'package:telly_app/features/queue/presentation/screens/custom_list_detail_screen.dart';

enum QueueListsMode { mine, friends }

/// SCR-13 Lists screen (`/more/queue/lists`, epic #47): your custom lists and your
/// friends' shared lists, pushed from the Queue's Lists action. New list lives in the
/// app bar. Conforms to `FE-LISTS-01` and screen spec SCR-13 (Lists screen).
class QueueListsScreen extends ConsumerStatefulWidget {
  final QueueListsMode initialMode;
  final List<CustomList>? testCustomLists;
  final List<CustomList>? testSharedLists;

  const QueueListsScreen({
    super.key,
    this.initialMode = QueueListsMode.mine,
    this.testCustomLists,
    this.testSharedLists,
  });

  @override
  ConsumerState<QueueListsScreen> createState() => _QueueListsScreenState();
}

class _QueueListsScreenState extends ConsumerState<QueueListsScreen> {
  late QueueListsMode _mode = widget.initialMode;

  void _showCreateListDialog(BuildContext context) {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    bool isPrivate = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          backgroundColor: TellyColors.surfaceOf(context),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: TellyColors.borderGlassOf(context)),
          ),
          title: Text(
            'Create Custom List',
            style: TellyTypography.titleMedium(color: TellyColors.textPrimaryOf(context))
                .copyWith(fontWeight: FontWeight.w800),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'LIST NAME',
                  style: TellyTypography.caption(color: TellyColors.textTertiaryOf(context))
                      .copyWith(fontWeight: FontWeight.w800, letterSpacing: 1.0),
                ),
                const SizedBox(height: 6),
                TextField(
                  key: const Key('create_list_title_field'),
                  controller: titleController,
                  style: TextStyle(color: TellyColors.textPrimaryOf(context)),
                  decoration: InputDecoration(
                    hintText: 'e.g. Criterion Must-Sees',
                    hintStyle: TextStyle(color: TellyColors.textTertiaryOf(context)),
                    filled: true,
                    fillColor: TellyColors.cardOf(context),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: TellyColors.borderGlassOf(context)),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'DESCRIPTION (OPTIONAL)',
                  style: TellyTypography.caption(color: TellyColors.textTertiaryOf(context))
                      .copyWith(fontWeight: FontWeight.w800, letterSpacing: 1.0),
                ),
                const SizedBox(height: 6),
                TextField(
                  key: const Key('create_list_desc_field'),
                  controller: descController,
                  style: TextStyle(color: TellyColors.textPrimaryOf(context)),
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'What makes this list special...',
                    hintStyle: TextStyle(color: TellyColors.textTertiaryOf(context)),
                    filled: true,
                    fillColor: TellyColors.cardOf(context),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: TellyColors.borderGlassOf(context)),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: TellyColors.cardOf(context),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: TellyColors.borderGlassOf(context)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isPrivate ? Icons.lock_outline : Icons.public,
                        color: isPrivate ? TellyColors.neonCoral : TellyColors.phosphorLime,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isPrivate ? 'Private List' : 'Public List',
                              style: TextStyle(
                                color: TellyColors.textPrimaryOf(context),
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              isPrivate
                                  ? 'Only you can view and edit'
                                  : 'Visible on your profile & shareable',
                              style: TextStyle(
                                color: TellyColors.textTertiaryOf(context),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        key: const Key('create_list_private_switch'),
                        value: isPrivate,
                        activeThumbColor: TellyColors.neonCoral,
                        onChanged: (val) {
                          setModalState(() {
                            isPrivate = val;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: TextStyle(color: TellyColors.textSecondaryOf(context))),
            ),
            ElevatedButton(
              key: const Key('create_list_submit_button'),
              onPressed: () async {
                final title = titleController.text.trim();
                if (title.isNotEmpty) {
                  final messenger = ScaffoldMessenger.of(context);
                  final cardBg = TellyColors.cardOf(context);
                  final desc = descController.text.trim();
                  await ref.read(userCustomListsProvider.notifier).createList(
                        title: title,
                        description: desc.isNotEmpty ? desc : null,
                        isPrivate: isPrivate,
                      );
                  if (ctx.mounted) Navigator.pop(ctx);
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Created list "$title"'),
                      backgroundColor: cardBg,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: TellyColors.phosphorLime,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Create List', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: TellySubpageAppBar(
        title: 'Lists',
        onNav: () => context.canPop() ? context.pop() : context.go(Routes.queue),
        actions: [
          TellyHeaderAction(
            key: const Key('create_new_list_button'),
            icon: Icons.add_rounded,
            tooltip: 'New list',
            onPressed: () => _showCreateListDialog(context),
          ),
        ],
      ),
      body: Column(
        children: [
          TellySegmentedControl<QueueListsMode>(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 6),
            segments: const [
              TellySegment(value: QueueListsMode.mine, label: 'My lists', key: Key('lists_mine_tab')),
              TellySegment(value: QueueListsMode.friends, label: "Friends' lists", key: Key('lists_friends_tab')),
            ],
            selected: _mode,
            // The selected segment is ephemeral UI state (AGENTS.md: setState allowed).
            onChanged: (mode) => setState(() => _mode = mode),
          ),
          Expanded(child: _mode == QueueListsMode.mine ? _buildMyListsView(context) : _buildSharedListsView(context)),
        ],
      ),
    );
  }

  Widget _buildMyListsView(BuildContext context) {
    final userListsAsync = ref.watch(userCustomListsProvider);
    final lists = widget.testCustomLists ?? userListsAsync.valueOrNull ?? const [];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 8, 0, 10),
          // New lists are created from the header's + action (FE-HEADER-01).
          child: TellySectionHeader(label: 'MY CURATED LISTS (${lists.length})'),
        ),
        Expanded(
          child: lists.isEmpty
              ? Center(
                  child: SingleChildScrollView(
                    child: TellyEmptyState(
                      icon: Icons.playlist_add,
                      title: 'No custom lists yet',
                      message: 'Create your first list for marathons or recommendations.',
                      actionLabel: 'New list',
                      actionIcon: Icons.add_rounded,
                      onAction: () => _showCreateListDialog(context),
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  itemCount: lists.length,
                  itemBuilder: (context, index) {
                    final list = lists[index];
                    return _buildCustomListCard(context, list, isUserOwned: true);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildSharedListsView(BuildContext context) {
    final sharedListsAsync = ref.watch(sharedCustomListsProvider);
    final lists = widget.testSharedLists ?? sharedListsAsync.valueOrNull ?? const [];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 8, 0, 10),
          child: TellySectionHeader(label: 'SHARED BY FRIENDS (${lists.length})'),
        ),
        Expanded(
          child: lists.isEmpty
              ? const Center(
                  child: SingleChildScrollView(
                    child: TellyEmptyState(
                      icon: Icons.group_outlined,
                      title: 'No shared lists found',
                      message: 'Friends\' public lists will show up here.',
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  itemCount: lists.length,
                  itemBuilder: (context, index) {
                    final list = lists[index];
                    return _buildCustomListCard(context, list, isUserOwned: false);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildCustomListCard(BuildContext context, CustomList list, {required bool isUserOwned}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: TellyColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: TellyColors.borderGlassOf(context)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => CustomListDetailScreen(
                  listId: list.id,
                  initialList: list,
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            list.title,
                            style: TellyTypography.titleMedium(color: TellyColors.textPrimaryOf(context))
                                .copyWith(fontWeight: FontWeight.w800),
                          ),
                          if (list.description != null && list.description!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              list.description!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TellyTypography.caption(color: TellyColors.textSecondaryOf(context)),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    TellyNeonBadge(
                      label: list.isPrivate ? 'PRIVATE' : 'PUBLIC',
                      variant: list.isPrivate ? TellyBadgeVariant.upset : TellyBadgeVariant.winner,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text(
                      'Curated by ${list.ownerHandle}',
                      style: TellyTypography.caption(color: TellyColors.textTertiaryOf(context)),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: TellyColors.cardOf(context),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '🎬 ${list.movieCount} Movies • 📺 ${list.seriesCount} Series',
                        style: TellyTypography.caption(color: TellyColors.textSecondaryOf(context))
                            .copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    if (!isUserOwned) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.bookmark_add_outlined, color: TellyColors.phosphorLime, size: 20),
                        tooltip: 'Save to My Lists',
                        onPressed: () {
                          ref.read(userCustomListsProvider.notifier).saveSharedList(list);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Saved "${list.title}" to your lists!'),
                              backgroundColor: TellyColors.cardOf(context),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
