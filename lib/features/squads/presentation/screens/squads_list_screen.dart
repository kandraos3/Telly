import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/theme/telly_colors.dart';
import '../../../../core/theme/telly_typography.dart';
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
      backgroundColor: TellyColors.backgroundCanvasOled,
      appBar: AppBar(
        backgroundColor: TellyColors.backgroundCanvasOled,
        title: Text('MY SQUADS', style: TellyTypography.labelLarge()),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('create_squad_button'),
        backgroundColor: TellyColors.phosphorLime,
        foregroundColor: Colors.black,
        onPressed: () => _create(context, ref),
        icon: const Icon(Icons.group_add),
        label: const Text('New Squad'),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator(color: TellyColors.phosphorLime)),
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
                    style: TellyTypography.bodyMedium(),
                  ),
                ),
              )
            : ListView(
                children: [
                  for (final s in squads)
                    ListTile(
                      key: Key('squad_row_${s.id}'),
                      leading: const Icon(Icons.groups_2_outlined, color: TellyColors.phosphorLime),
                      title: Text(s.name, style: TellyTypography.titleMedium()),
                      subtitle: s.description == null ? null : Text(s.description!, style: TellyTypography.caption()),
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
        backgroundColor: TellyColors.backgroundCard,
        title: Text('Name your squad', style: TellyTypography.titleMedium()),
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
