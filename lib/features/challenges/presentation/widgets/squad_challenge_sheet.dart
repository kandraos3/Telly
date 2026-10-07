import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/theme/telly_colors.dart';
import '../../../../core/theme/telly_typography.dart';
import '../../../../core/widgets/telly_frosted_sheet.dart';
import '../../../../core/widgets/telly_primary_button.dart';
import '../../../squads/domain/squad_models.dart';
import '../../data/challenges_repository.dart';
import '../../domain/challenge.dart';
import '../controllers/challenges_controller.dart';

/// `SCR-25` "+": a squad owner or admin starts a challenge from a template, with their own
/// name, a length, and the template's params (features/10 §8.3; #144). Form state is
/// ephemeral UI state, so it lives in the widget.
class SquadChallengeSheet extends ConsumerStatefulWidget {
  final List<Squad> squads;
  const SquadChallengeSheet({super.key, required this.squads});

  static Future<void> show(BuildContext context, List<Squad> squads) =>
      TellyFrostedSheet.show<void>(context: context, builder: (_) => SquadChallengeSheet(squads: squads));

  @override
  ConsumerState<SquadChallengeSheet> createState() => _SquadChallengeSheetState();
}

class _SquadChallengeSheetState extends ConsumerState<SquadChallengeSheet> {
  static const lengths = [7, 14, 30];

  late Squad _squad = widget.squads.first;
  ChallengeTemplate? _template;
  int _days = 30;
  final _name = TextEditingController();
  final _params = <String, TextEditingController>{};
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    for (final c in _params.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _pick(ChallengeTemplate t) {
    setState(() {
      _template = t;
      if (_name.text.isEmpty) _name.text = t.name;
      for (final p in t.params) {
        _params.putIfAbsent(p, TextEditingController.new);
      }
    });
  }

  /// A param as the rule expects it: numbers stay numbers (decade, collection).
  static Object _paramValue(String raw) => int.tryParse(raw.trim()) ?? raw.trim();

  Future<void> _create() async {
    final t = _template;
    if (t == null) return;
    final params = {for (final p in t.params) p: _paramValue(_params[p]!.text)};
    if (_name.text.trim().isEmpty || params.values.any((v) => v is String && v.isEmpty)) {
      setState(() => _error = 'Fill in the name and every field.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final start = DateTime.now();
      final created = await ref.read(challengesRepositoryProvider).createSquadChallenge(
            squadId: _squad.id,
            templateKey: t.key,
            name: _name.text.trim(),
            startsAt: start,
            endsAt: start.add(Duration(days: _days)),
            params: params,
          );
      ref.invalidate(challengesControllerProvider);
      if (!mounted) return;
      Navigator.of(context).pop();
      if (created != null) context.push(Routes.challenge(created.slug));
    } catch (_) {
      if (mounted) setState(() => _error = "Couldn't create it. Check the fields and try again.");
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final templates = ref.watch(challengeTemplatesProvider).valueOrNull ?? const <ChallengeTemplate>[];
    final label = TellyTypography.labelMedium(color: TellyColors.textSecondaryOf(context));
    return SingleChildScrollView(
      key: const Key('squad_challenge_sheet'),
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Start a squad challenge',
              style: TellyTypography.titleMedium(color: TellyColors.textPrimaryOf(context))
                  .copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          if (widget.squads.length > 1) ...[
            Text('Squad', style: label),
            Wrap(spacing: 8, children: [
              for (final s in widget.squads)
                ChoiceChip(label: Text(s.name), selected: s.id == _squad.id, onSelected: (_) => setState(() => _squad = s)),
            ]),
            const SizedBox(height: 12),
          ],
          Text('Template', style: label),
          const SizedBox(height: 6),
          Wrap(spacing: 8, runSpacing: 6, children: [
            for (final t in templates)
              ChoiceChip(
                key: Key('squad_challenge_template_${t.key}'),
                label: Text(t.name),
                selected: t.key == _template?.key,
                onSelected: (_) => _pick(t),
              ),
          ]),
          if (_template case final t?) ...[
            const SizedBox(height: 14),
            TextField(
              key: const Key('squad_challenge_name'),
              controller: _name,
              maxLength: 64,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            for (final p in t.params)
              TextField(
                key: Key('squad_challenge_param_$p'),
                controller: _params[p],
                decoration: InputDecoration(labelText: _paramLabel(p)),
              ),
            const SizedBox(height: 12),
            Text('Length', style: label),
            Wrap(spacing: 8, children: [
              for (final d in lengths)
                ChoiceChip(label: Text('$d days'), selected: d == _days, onSelected: (_) => setState(() => _days = d)),
            ]),
          ],
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: TellyTypography.bodyMedium(color: TellyColors.neonCoralOf(context))),
          ],
          const SizedBox(height: 16),
          TellyPrimaryButton(
            key: const Key('squad_challenge_create'),
            label: 'Start challenge',
            isLoading: _busy,
            onPressed: _template == null ? null : _create,
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  static String _paramLabel(String p) => switch (p) {
        'genre' => 'Genre (e.g. Horror)',
        'decade' => 'Decade (e.g. 1980)',
        'collection' => 'TMDB collection id',
        'network' => 'Network (e.g. HBO)',
        'company' => 'Studio (e.g. A24)',
        _ => p,
      };
}
