import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/haptics_service.dart';
import '../../../../core/theme/telly_colors.dart';
import '../../../../core/theme/telly_typography.dart';
import '../../../../core/widgets/telly_frosted_sheet.dart';
import '../../../../core/widgets/telly_primary_button.dart';
import '../../domain/canon_type.dart';
import '../../domain/editorial_tagging.dart';

/// SCR-11 Editorial Tagging Sheet for capturing post-duel subjective nuances.
/// Conforms to:
/// - `docs/design_system/03_SCREEN_BY_SCREEN_SPECS_AND_FLOWS.md` §11 (SCR-11)
/// - `docs/features/02_PAIRWISE_RANKING_ENGINE_AND_LOGGING.md` §3 (Editorial Tagging)
/// - `docs/features/09_MOVIE_INTEGRATION_AND_DUAL_CANON.md` §3 (Theatrical Tracking)
/// - `docs/features/08_ANIME_INTEGRATION_AND_HYBRID_CANON.md` §6.2 (Sub/Dub Mode)
class EditorialTaggingSheet extends ConsumerStatefulWidget {
  final String title;
  final String mediaType; // 'movie' or 'tv'
  final int targetRank;
  final int totalInCanon;
  final bool isAnime;
  final String? director;
  final List<String> castMembers;
  final EditorialTaggingData? initialData;
  final ValueChanged<EditorialTaggingData> onPublish;
  final VoidCallback? onSkip;
  final VoidCallback? onBack;

  const EditorialTaggingSheet({
    super.key,
    required this.title,
    required this.mediaType,
    required this.targetRank,
    this.totalInCanon = 1,
    this.isAnime = false,
    this.director,
    this.castMembers = const [],
    this.initialData,
    required this.onPublish,
    this.onSkip,
    this.onBack,
  });

  @override
  ConsumerState<EditorialTaggingSheet> createState() => _EditorialTaggingSheetState();

  /// Static helper to display [EditorialTaggingSheet] inside a modal frosted sheet.
  static Future<EditorialTaggingData?> show({
    required BuildContext context,
    required String title,
    required String mediaType,
    required int targetRank,
    int totalInCanon = 1,
    bool isAnime = false,
    String? director,
    List<String> castMembers = const [],
    EditorialTaggingData? initialData,
  }) {
    EditorialTaggingData? result;
    return TellyFrostedSheet.show<EditorialTaggingData>(
      context: context,
      isDismissible: true,
      builder: (ctx) => SizedBox(
        height: MediaQuery.of(ctx).size.height * 0.88,
        child: EditorialTaggingSheet(
          title: title,
          mediaType: mediaType,
          targetRank: targetRank,
          totalInCanon: totalInCanon,
          isAnime: isAnime,
          director: director,
          castMembers: castMembers,
          initialData: initialData,
          onPublish: (data) {
            result = data;
            Navigator.of(ctx).pop(result);
          },
          onSkip: () {
            result = EditorialTaggingData(
              viewingVenue: CanonType.fromMediaType(mediaType) == CanonType.movie
                  ? ViewingVenue.home
                  : null,
            );
            Navigator.of(ctx).pop(result);
          },
          onBack: () => Navigator.of(ctx).pop(null),
        ),
      ),
    );
  }
}

class _EditorialTaggingSheetState extends ConsumerState<EditorialTaggingSheet> {
  late ViewingVenue? _selectedVenue;
  late bool _isRewatch;
  late int _rewatchCount;
  late BingeVelocity? _selectedVelocity;
  late AnimeAudioMode? _selectedAudioMode;
  late List<String> _selectedVibes;
  late String? _selectedDirector;
  late String? _selectedMvpCharacter;
  late final TextEditingController _reviewController;

  bool get _isMovie => CanonType.fromMediaType(widget.mediaType) == CanonType.movie;

  @override
  void initState() {
    super.initState();
    final init = widget.initialData;
    _selectedVenue = init?.viewingVenue ?? (_isMovie ? ViewingVenue.home : null);
    _isRewatch = init?.isRewatch ?? false;
    _rewatchCount = init?.rewatchCount ?? 1;
    _selectedVelocity = init?.bingeVelocity ?? (!_isMovie ? BingeVelocity.weeklyAiring : null);
    _selectedAudioMode = init?.audioMode ?? (widget.isAnime ? AnimeAudioMode.sub : null);
    _selectedVibes = List<String>.from(init?.vibeTags ?? []);
    _selectedDirector = init?.director;
    _selectedMvpCharacter = init?.mvpCharacter;
    _reviewController = TextEditingController(text: init?.review ?? '');
  }

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  void _toggleVibeTag(String tag) {
    ref.read(hapticsServiceProvider).duelSelectCandidate();
    setState(() {
      if (_selectedVibes.contains(tag)) {
        _selectedVibes.remove(tag);
      } else {
        if (_selectedVibes.length >= 3) {
          // FIFO queue: remove oldest tag (first element) to make room for new tag
          _selectedVibes.removeAt(0);
        }
        _selectedVibes.add(tag);
      }
    });
  }

  void _handlePublish() {
    ref.read(hapticsServiceProvider).duelWinner();
    final data = EditorialTaggingData(
      viewingVenue: _isMovie ? _selectedVenue : null,
      isRewatch: _isRewatch,
      rewatchCount: _isRewatch ? _rewatchCount : 1,
      bingeVelocity: !_isMovie ? _selectedVelocity : null,
      audioMode: widget.isAnime ? _selectedAudioMode : null,
      vibeTags: List.unmodifiable(_selectedVibes),
      director: _selectedDirector,
      mvpCharacter: _selectedMvpCharacter,
      review: _reviewController.text.trim(),
    );
    widget.onPublish(data);
  }

  @override
  Widget build(BuildContext context) {
    final availableVibes = _isMovie
        ? EditorialTaggingData.defaultMovieVibes
        : EditorialTaggingData.defaultSeriesVibes;

    return Column(
      children: [
        // 1. TOP APP BAR / HEADER
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              key: const Key('editorial_back_button'),
              icon: const Icon(Icons.arrow_back, color: TellyColors.textSecondary),
              onPressed: widget.onBack ?? () => Navigator.of(context).maybePop(),
            ),
            Text(
              'DETAILS & NOTES',
              style: TellyTypography.titleMedium(color: TellyColors.textPrimary).copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
            TextButton(
              key: const Key('editorial_skip_button'),
              onPressed: widget.onSkip ?? () => Navigator.of(context).maybePop(),
              child: Text(
                'Skip',
                style: TellyTypography.bodyMedium(color: TellyColors.textTertiary).copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 8),

        // 2. PLACED BANNER
        Container(
          key: const Key('placed_canon_banner'),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: TellyColors.backgroundCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: TellyColors.borderGlass),
          ),
          child: RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: '${widget.title.toUpperCase()} • ',
                  style: TellyTypography.labelSmall(color: TellyColors.textSecondary).copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextSpan(
                  text: 'Placed at #${widget.targetRank} ',
                  style: TellyTypography.labelSmall(color: TellyColors.phosphorLime).copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextSpan(
                  text: 'in Your ${_isMovie ? 'Movie' : 'Series'} Canon!',
                  style: TellyTypography.labelSmall(color: TellyColors.textTertiary),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // 3. SCROLLABLE BODY
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- SECTION: MOVIE VIEWING VENUE (Movies Only) ---
                if (_isMovie) ...[
                  _buildSectionHeader('VIEWING VENUE (Movies Only)'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: ViewingVenue.values.map((venue) {
                      final isSelected = _selectedVenue == venue;
                      return _buildSelectableChip(
                        key: Key('venue_chip_${venue.name}'),
                        label: '${venue.emoji} ${venue.shortLabel}',
                        isSelected: isSelected,
                        onTap: () {
                          ref.read(hapticsServiceProvider).duelSelectCandidate();
                          setState(() => _selectedVenue = venue);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                ],

                // --- SECTION: SERIES BINGE VELOCITY (Series Only) ---
                if (!_isMovie) ...[
                  _buildSectionHeader('BINGE VELOCITY'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: BingeVelocity.values.map((vel) {
                      final isSelected = _selectedVelocity == vel;
                      return _buildSelectableChip(
                        key: Key('velocity_chip_${vel.name}'),
                        label: '${vel.emoji} ${vel.displayName}',
                        isSelected: isSelected,
                        onTap: () {
                          ref.read(hapticsServiceProvider).duelSelectCandidate();
                          setState(() => _selectedVelocity = vel);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                ],

                // --- SECTION: REWATCH STATUS ---
                _buildSectionHeader('REWATCH STATUS'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildSelectableChip(
                      key: const Key('rewatch_chip_first_time'),
                      label: 'First-Time Watch',
                      isSelected: !_isRewatch,
                      onTap: () {
                        ref.read(hapticsServiceProvider).duelSelectCandidate();
                        setState(() {
                          _isRewatch = false;
                          _rewatchCount = 1;
                        });
                      },
                    ),
                    const SizedBox(width: 8),
                    _buildSelectableChip(
                      key: const Key('rewatch_chip_rewatch'),
                      label: _isRewatch ? 'Rewatch (x$_rewatchCount)' : 'Rewatch',
                      isSelected: _isRewatch,
                      onTap: () {
                        ref.read(hapticsServiceProvider).duelSelectCandidate();
                        setState(() {
                          _isRewatch = true;
                          if (_rewatchCount < 2) _rewatchCount = 2;
                        });
                      },
                    ),
                    if (_isRewatch) ...[
                      const SizedBox(width: 12),
                      _buildStepper(
                        onDecrement: _rewatchCount > 2
                            ? () {
                                ref.read(hapticsServiceProvider).duelSelectCandidate();
                                setState(() => _rewatchCount--);
                              }
                            : null,
                        onIncrement: () {
                          ref.read(hapticsServiceProvider).duelSelectCandidate();
                          setState(() => _rewatchCount++);
                        },
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 20),

                // --- SECTION: ANIME AUDIO MODE (Anime Only) ---
                if (widget.isAnime) ...[
                  _buildSectionHeader('AUDIO MODE'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: AnimeAudioMode.values.map((audio) {
                      final isSelected = _selectedAudioMode == audio;
                      return _buildSelectableChip(
                        key: Key('audio_chip_${audio.name}'),
                        label: '${audio.emoji} ${audio.displayName}',
                        isSelected: isSelected,
                        onTap: () {
                          ref.read(hapticsServiceProvider).duelSelectCandidate();
                          setState(() => _selectedAudioMode = audio);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                ],

                // --- SECTION: TAG THE VIBE (Up to 3, FIFO) ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildSectionHeader('TAG THE VIBE (Up to 3)'),
                    Text(
                      '${_selectedVibes.length}/3 selected',
                      key: const Key('vibe_selection_counter'),
                      style: TellyTypography.caption(
                        color: _selectedVibes.length == 3
                            ? TellyColors.phosphorLime
                            : TellyColors.textTertiary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: availableVibes.map((tag) {
                    final isSelected = _selectedVibes.contains(tag);
                    return _buildSelectableChip(
                      key: Key('vibe_chip_$tag'),
                      label: '#$tag',
                      isSelected: isSelected,
                      onTap: () => _toggleVibeTag(tag),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),

                // --- SECTION: DIRECTOR & MVP CHARACTER ---
                _buildSectionHeader('DIRECTOR & STANDOUT PERFORMANCE'),
                const SizedBox(height: 8),
                if (widget.director != null && widget.director!.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: FilterChip(
                      key: const Key('director_toggle_chip'),
                      avatar: Icon(
                        Icons.movie_creation_outlined,
                        size: 16,
                        color: _selectedDirector != null ? TellyColors.phosphorLime : TellyColors.textTertiary,
                      ),
                      label: Text(
                        _selectedDirector != null ? 'Director: ${widget.director}' : '+ Tag Director (${widget.director})',
                      ),
                      selected: _selectedDirector != null,
                      onSelected: (selected) {
                        ref.read(hapticsServiceProvider).duelSelectCandidate();
                        setState(() {
                          _selectedDirector = selected ? widget.director : null;
                        });
                      },
                      backgroundColor: TellyColors.backgroundCard,
                      selectedColor: TellyColors.phosphorLime.withValues(alpha: 0.15),
                      labelStyle: TextStyle(
                        color: _selectedDirector != null ? TellyColors.phosphorLime : TellyColors.textSecondary,
                        fontWeight: _selectedDirector != null ? FontWeight.bold : FontWeight.normal,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],

                // MVP Character Dropdown / Field
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    color: TellyColors.backgroundCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: TellyColors.strokeSubtle),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String?>(
                      key: const Key('mvp_character_dropdown'),
                      value: _selectedMvpCharacter,
                      isExpanded: true,
                      dropdownColor: TellyColors.backgroundSurface,
                      icon: const Icon(Icons.arrow_drop_down, color: TellyColors.phosphorLime),
                      hint: Text(
                        'Select MVP Standout Performance (Optional)',
                        style: TellyTypography.bodyMedium(color: TellyColors.textTertiary),
                      ),
                      items: [
                        DropdownMenuItem<String?>(
                          value: null,
                          child: Text(
                            'None (Optional)',
                            style: TellyTypography.bodyMedium(color: TellyColors.textTertiary),
                          ),
                        ),
                        ...widget.castMembers.map((cast) {
                          return DropdownMenuItem<String?>(
                            value: cast,
                            child: Text(
                              cast,
                              style: TellyTypography.bodyMedium(color: TellyColors.textPrimary),
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }),
                      ],
                      onChanged: (val) {
                        ref.read(hapticsServiceProvider).duelSelectCandidate();
                        setState(() => _selectedMvpCharacter = val);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // --- SECTION: 280-CHAR MICRO REVIEW ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildSectionHeader('HOT TAKE / MICRO-REVIEW (280 chars max)'),
                    ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _reviewController,
                      builder: (context, value, _) {
                        return Text(
                          '(${value.text.length}/280)',
                          key: const Key('micro_review_counter'),
                          style: TellyTypography.caption(
                            color: value.text.length > 280
                                ? TellyColors.neonCoral
                                : TellyColors.textTertiary,
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextFormField(
                  key: const Key('micro_review_input'),
                  controller: _reviewController,
                  maxLength: 280,
                  maxLines: 4,
                  minLines: 3,
                  buildCounter: (context, {required currentLength, required isFocused, maxLength}) =>
                      null, // Hide default counter; using custom counter above
                  style: TellyTypography.bodyLarge(color: TellyColors.textPrimary),
                  cursorColor: TellyColors.phosphorLime,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: TellyColors.backgroundCard,
                    hintText:
                        'Write a crisp hot take or memorable scene (e.g., "The docking scene in IMAX 70mm was pure cinematic transcendence...").',
                    hintStyle: TellyTypography.bodyMedium(color: TellyColors.textTertiary),
                    contentPadding: const EdgeInsets.all(14),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: TellyColors.strokeSubtle),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: TellyColors.phosphorLime, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        // 4. BOTTOM ACTION: PUBLISH BUTTON
        TellyPrimaryButton(
          key: const Key('publish_editorial_button'),
          label: 'Publish',
          onPressed: _handlePublish,
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: TellyTypography.labelSmall(color: TellyColors.textTertiary).copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: 1.1,
      ),
    );
  }

  Widget _buildSelectableChip({
    required Key key,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      key: key,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? TellyColors.phosphorLime.withValues(alpha: 0.15)
              : TellyColors.backgroundCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? TellyColors.phosphorLime : TellyColors.strokeSubtle,
            width: isSelected ? 1.5 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: TellyColors.phosphorLime.withValues(alpha: 0.2),
                    blurRadius: 8,
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TellyTypography.bodyMedium(
            color: isSelected ? TellyColors.phosphorLime : TellyColors.textSecondary,
          ).copyWith(
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildStepper({
    required VoidCallback? onDecrement,
    required VoidCallback onIncrement,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: TellyColors.backgroundCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: TellyColors.strokeSubtle),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            key: const Key('rewatch_decrement_button'),
            icon: const Icon(Icons.remove, size: 16),
            color: onDecrement != null ? TellyColors.textPrimary : TellyColors.textDisabled,
            onPressed: onDecrement,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: EdgeInsets.zero,
          ),
          IconButton(
            key: const Key('rewatch_increment_button'),
            icon: const Icon(Icons.add, size: 16),
            color: TellyColors.phosphorLime,
            onPressed: onIncrement,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }
}
