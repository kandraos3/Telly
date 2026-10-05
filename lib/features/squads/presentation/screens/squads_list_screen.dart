import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/theme/telly_colors.dart';
import '../../../../core/theme/telly_typography.dart';
import '../../../../core/widgets/telly_screen_header.dart';
import '../controllers/squad_controllers.dart';

/// My Squads (entry to `SCR-17`, FE-608): list + create.
class SquadsListScreen extends ConsumerWidget {
  const SquadsListScreen({super.key});

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final name = await showDialog<String>(context: context, builder: (_) => const _CreateSquadDialog());
    if (name == null || name.trim().isEmpty || !context.mounted) return;
    try {
      final squad = await ref.read(squadsListProvider.notifier).create(name);
      if (context.mounted) context.push(Routes.squad(squad.id));
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Couldn't create the squad.")));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(squadsListProvider);
    return Scaffold(
      backgroundColor: TellyColors.canvasOf(context),
      appBar: TellySubpageAppBar(
        title: 'My Squads',
        onNav: () => context.canPop() ? context.pop() : context.go(Routes.feed),
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('create_squad_button'),
        backgroundColor: TellyColors.primaryAccentOf(context),
        foregroundColor: Theme.of(context).brightness == Brightness.light ? Colors.white : Colors.black,
        onPressed: () => _create(context, ref),
        icon: const Icon(Icons.group_add),
        label: const Text('New Squad'),
      ),
      body: async.when(
        loading: () => Center(child: CircularProgressIndicator(color: TellyColors.primaryAccentOf(context))),
        error: (_, __) => Center(
          key: const Key('squads_error'),
          child: TextButton(onPressed: () => ref.invalidate(squadsListProvider), child: const Text('Retry')),
        ),
        data: (squads) => squads.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    'Squads rank together: roommates, a book club, the group chat. Create one to start a consensus canon.',
                    textAlign: TextAlign.center,
                    style: TellyTypography.bodyMedium(color: TellyColors.textPrimaryOf(context))
                        .copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              )
            : ListView(
                children: [
                  for (final s in squads)
                    ListTile(
                      key: Key('squad_row_${s.id}'),
                      leading: Icon(Icons.groups_2_outlined, color: TellyColors.primaryAccentOf(context)),
                      title: Text(s.name, style: TellyTypography.titleMedium(color: TellyColors.textPrimaryOf(context))),
                      subtitle: s.description == null
                          ? null
                          : Text(s.description!, style: TellyTypography.caption(color: TellyColors.textSecondaryOf(context))),
                      onTap: () => context.push(Routes.squad(s.id)),
                    ),
                ],
              ),
      ),
    );
  }
}

class _CreateSquadDialog extends StatefulWidget {
  const _CreateSquadDialog();

  @override
  State<_CreateSquadDialog> createState() => _CreateSquadDialogState();
}

class _CreateSquadDialogState extends State<_CreateSquadDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        backgroundColor: TellyColors.cardOf(context),
        title: Text('Name your squad', style: TellyTypography.titleMedium(color: TellyColors.textPrimaryOf(context))),
        content: TextField(
          key: const Key('squad_name_field'),
          controller: _controller,
          autofocus: true,
          maxLength: 64,
          decoration: const InputDecoration(hintText: 'The Apartment'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          TextButton(
            key: const Key('squad_create_confirm'),
            onPressed: () => Navigator.of(context).pop(_controller.text),
            child: const Text('Create'),
          ),
        ],
      );
}
