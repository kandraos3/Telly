import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:telly_app/core/router/routes.dart';
import 'package:telly_app/core/theme/telly_colors.dart';
import 'package:telly_app/core/theme/telly_typography.dart';
import 'package:telly_app/core/widgets/poster_image.dart';
import 'package:telly_app/core/widgets/telly_neon_badge.dart';

import '../../domain/custom_list_models.dart';
import '../../data/custom_list_repository.dart';

class CustomListDetailScreen extends ConsumerStatefulWidget {
  final String listId;
  final CustomList? initialList;

  const CustomListDetailScreen({
    super.key,
    required this.listId,
    this.initialList,
  });

  @override
  ConsumerState<CustomListDetailScreen> createState() => _CustomListDetailScreenState();
}

class _CustomListDetailScreenState extends ConsumerState<CustomListDetailScreen> {
  void _shareList(CustomList list) {
    final shareUrl = 'https://telly.app/lists/${list.id}';
    Clipboard.setData(ClipboardData(text: shareUrl));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Share link copied: $shareUrl'),
        backgroundColor: TellyColors.backgroundCard,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showAddCollaboratorDialog(CustomList list) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: TellyColors.backgroundSurface,
        title: Text(
          'Add Collaborator',
          style: TellyTypography.titleMedium(color: TellyColors.textPrimary),
        ),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: TellyColors.textPrimary),
          decoration: InputDecoration(
            hintText: 'Enter @handle',
            hintStyle: const TextStyle(color: TellyColors.textTertiary),
            filled: true,
            fillColor: TellyColors.backgroundCard,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: TellyColors.borderGlass),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: TellyColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              final handle = controller.text.trim();
              if (handle.isNotEmpty) {
                final updatedCollaborators = [...list.collaborators, handle.startsWith('@') ? handle : '@$handle'];
                ref.read(customListRepositoryProvider).updateList(
                      list.copyWith(collaborators: updatedCollaborators),
                    );
                Navigator.pop(ctx);
                setState(() {});
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: TellyColors.phosphorLime,
              foregroundColor: TellyColors.backgroundCanvasOled,
            ),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userListsAsync = ref.watch(userCustomListsProvider);
    final sharedListsAsync = ref.watch(sharedCustomListsProvider);

    CustomList? currentList = widget.initialList;
    if (userListsAsync.hasValue) {
      for (final l in userListsAsync.value!) {
        if (l.id == widget.listId) {
          currentList = l;
          break;
        }
      }
    }
    if (currentList == null && sharedListsAsync.hasValue) {
      for (final l in sharedListsAsync.value!) {
        if (l.id == widget.listId) {
          currentList = l;
          break;
        }
      }
    }

    if (currentList == null) {
      return Scaffold(
        backgroundColor: TellyColors.backgroundCanvasOled,
        appBar: AppBar(
          backgroundColor: TellyColors.backgroundCanvasOled,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: TellyColors.textPrimary),
            onPressed: () => context.pop(),
          ),
        ),
        body: const Center(
          child: Text('List not found', style: TextStyle(color: TellyColors.textTertiary)),
        ),
      );
    }

    final list = currentList;
    final isOwner = list.isOwner('@me');

    return Scaffold(
      backgroundColor: TellyColors.backgroundCanvasOled,
      appBar: AppBar(
        backgroundColor: TellyColors.backgroundCanvasOled,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: TellyColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text(
          list.title.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TellyTypography.titleMedium(color: TellyColors.textPrimary).copyWith(letterSpacing: 1.2),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined, color: TellyColors.phosphorLime),
            tooltip: 'Share List',
            onPressed: () => _shareList(list),
          ),
          if (isOwner)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: TellyColors.neonCoral),
              tooltip: 'Delete List',
              onPressed: () async {
                final router = GoRouter.of(context);
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: TellyColors.backgroundSurface,
                    title: const Text('Delete List?', style: TextStyle(color: TellyColors.textPrimary)),
                    content: Text(
                      'Are you sure you want to delete "${list.title}"?',
                      style: const TextStyle(color: TellyColors.textSecondary),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel', style: TextStyle(color: TellyColors.textSecondary)),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: ElevatedButton.styleFrom(backgroundColor: TellyColors.neonCoral),
                        child: const Text('Delete', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                );
                if (confirm == true && mounted) {
                  await ref.read(userCustomListsProvider.notifier).deleteList(list.id);
                  if (mounted) router.pop();
                }
              },
            ),
        ],
      ),
      body: Column(
        children: [
          // Header card
          Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: TellyColors.backgroundSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: TellyColors.borderGlass),
            ),
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
                            style: TellyTypography.headlineSmall(color: TellyColors.textPrimary)
                                .copyWith(fontWeight: FontWeight.w800),
                          ),
                          if (list.description != null && list.description!.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              list.description!,
                              style: TellyTypography.bodyMedium(color: TellyColors.textSecondary),
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
                      style: TellyTypography.caption(color: TellyColors.textTertiary),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: TellyColors.backgroundCard,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '🎬 ${list.movieCount} Movies • 📺 ${list.seriesCount} Series',
                        style: TellyTypography.caption(color: TellyColors.textSecondary)
                            .copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                if (list.collaborators.isNotEmpty || isOwner) ...[
                  const SizedBox(height: 12),
                  const Divider(color: TellyColors.borderGlass, height: 1),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.people_outline, size: 16, color: TellyColors.textSecondary),
                      const SizedBox(width: 6),
                      Text(
                        'Collaborators:',
                        style: TellyTypography.caption(color: TellyColors.textSecondary)
                            .copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              for (final handle in list.collaborators)
                                Container(
                                  margin: const EdgeInsets.only(right: 6),
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: TellyColors.electricViolet.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: TellyColors.electricViolet.withValues(alpha: 0.4),
                                    ),
                                  ),
                                  child: Text(
                                    handle,
                                    style: TellyTypography.caption(color: TellyColors.electricViolet)
                                        .copyWith(fontSize: 11, fontWeight: FontWeight.w700),
                                  ),
                                ),
                              if (isOwner)
                                InkWell(
                                  onTap: () => _showAddCollaboratorDialog(list),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: TellyColors.backgroundCard,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: TellyColors.borderGlass),
                                    ),
                                    child: const Text(
                                      '+ Add',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: TellyColors.phosphorLime,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // Titles header with count & reorder hint
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'TITLES (${list.totalCount})',
                  style: TellyTypography.caption(color: TellyColors.textTertiary)
                      .copyWith(letterSpacing: 1.1, fontWeight: FontWeight.w800),
                ),
                if (isOwner && list.items.length > 1)
                  Text(
                    'Drag handle to reorder',
                    style: TellyTypography.caption(color: TellyColors.textTertiary),
                  ),
              ],
            ),
          ),

          // Titles List
          Expanded(
            child: list.items.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.playlist_add, size: 48, color: TellyColors.textTertiary),
                        const SizedBox(height: 12),
                        Text(
                          'No titles in this list yet',
                          style: TellyTypography.titleMedium(color: TellyColors.textPrimary),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Add movies and shows from detail pages.',
                          style: TellyTypography.caption(color: TellyColors.textTertiary),
                        ),
                      ],
                    ),
                  )
                : ReorderableListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    itemCount: list.items.length,
                    // ignore: deprecated_member_use
                    onReorder: (oldIndex, newIndex) {
                      if (isOwner) {
                        ref.read(userCustomListsProvider.notifier).reorderItems(
                              list.id,
                              oldIndex,
                              newIndex,
                            );
                      }
                    },
                    itemBuilder: (context, index) {
                      final item = list.items[index];
                      return _buildItemRow(
                        key: ValueKey('custom_item_${item.id}'),
                        item: item,
                        index: index,
                        listId: list.id,
                        isOwner: isOwner,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemRow({
    required Key key,
    required CustomListItem item,
    required int index,
    required String listId,
    required bool isOwner,
  }) {
    return Container(
      key: key,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: TellyColors.backgroundSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: TellyColors.borderGlass),
      ),
      child: Row(
        children: [
          // Order number
          SizedBox(
            width: 24,
            child: Text(
              '${index + 1}',
              style: TellyTypography.caption(color: TellyColors.textTertiary)
                  .copyWith(fontWeight: FontWeight.w800),
            ),
          ),

          // Poster Box
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Container(
              width: 38,
              height: 52,
              decoration: BoxDecoration(
                color: TellyColors.backgroundCard,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: TellyColors.borderGlass),
              ),
              child: PosterImage(
                posterPath: item.posterPath,
                fallback: Center(
                  child: Icon(
                    item.mediaType == 'movie' ? Icons.movie_outlined : Icons.tv_outlined,
                    color: TellyColors.textTertiary,
                    size: 18,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Title & Type
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => context.push(Routes.title(item.mediaType, item.showId)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TellyTypography.bodyMedium(color: TellyColors.textPrimary)
                        .copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: TellyColors.backgroundCard,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          item.mediaType == 'movie' ? 'MOVIE' : 'SERIES',
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: TellyColors.textTertiary,
                          ),
                        ),
                      ),
                      if (item.addedByHandle != null) ...[
                        const SizedBox(width: 6),
                        Text(
                          'by ${item.addedByHandle}',
                          style: TellyTypography.caption(color: TellyColors.textTertiary)
                              .copyWith(fontSize: 10),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Delete button
          if (isOwner)
            IconButton(
              icon: const Icon(Icons.remove_circle_outline, size: 20, color: TellyColors.neonCoral),
              tooltip: 'Remove from List',
              onPressed: () {
                ref.read(userCustomListsProvider.notifier).removeItem(listId, item.id);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Removed "${item.title}" from list'),
                    backgroundColor: TellyColors.backgroundCard,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),

          // Reorder handle
          if (isOwner)
            ReorderableDragStartListener(
              index: index,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Icon(Icons.drag_handle, color: TellyColors.textTertiary, size: 20),
              ),
            ),
        ],
      ),
    );
  }
}
