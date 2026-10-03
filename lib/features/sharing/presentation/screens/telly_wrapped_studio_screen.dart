import 'package:flutter/material.dart';
import 'package:telly_app/core/theme/telly_colors.dart';
import 'package:telly_app/core/theme/telly_typography.dart';
import 'package:telly_app/core/widgets/telly_neon_badge.dart';
import 'package:telly_app/core/widgets/telly_primary_button.dart';

/// SCR-19: Telly Wrapped Studio & Shareable Story Carousel.
/// Conforms to `FE-502` and `docs/design_system/03_SCREEN_BY_SCREEN_SPECS_AND_FLOWS.md` §19.
class TellyWrappedStudioScreen extends StatefulWidget {
  final String username;
  final String displayName;

  const TellyWrappedStudioScreen({
    super.key,
    this.username = 'jordan',
    this.displayName = 'Jordan Miller',
  });

  @override
  State<TellyWrappedStudioScreen> createState() => _TellyWrappedStudioScreenState();
}

class _TellyWrappedStudioScreenState extends State<TellyWrappedStudioScreen> {
  final PageController _pageController = PageController(viewportFraction: 0.85);
  int _currentPage = 0;

  final List<String> _templateTitles = [
    'Top 9 Movie Canon',
    'Top 9 Series Canon',
    'Spiciest Upset Take',
    'Director Affinity',
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _shareStory() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Exporting 1080x1920 Story to Instagram...'),
        backgroundColor: TellyColors.backgroundCard,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TellyColors.backgroundCanvasOled,
      appBar: AppBar(
        backgroundColor: TellyColors.backgroundCanvasOled,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: TellyColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'STORY STUDIO',
          style: TellyTypography.titleMedium(color: TellyColors.textPrimary).copyWith(letterSpacing: 1.2),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share, color: TellyColors.phosphorLime),
            onPressed: _shareStory,
          ),
        ],
      ),
      body: Column(
        children: [
          // Template indicator chip
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              _templateTitles[_currentPage].toUpperCase(),
              style: TellyTypography.labelSmall(
                color: TellyColors.phosphorLime,
              ).copyWith(letterSpacing: 1.2, fontWeight: FontWeight.w800),
            ),
          ),

          // 9:16 Vertical Card Carousel
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (idx) {
                setState(() {
                  _currentPage = idx;
                });
              },
              children: [
                _buildStoryCardWrapper(_buildTop9MoviesCard()),
                _buildStoryCardWrapper(_buildTop9SeriesCard()),
                _buildStoryCardWrapper(_buildSpicyUpsetCard()),
                _buildStoryCardWrapper(_buildDirectorAffinityCard()),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Paging Indicator Dots
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(4, (index) {
              final isSelected = _currentPage == index;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: isSelected ? 20 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: isSelected ? TellyColors.phosphorLime : TellyColors.strokeSubtle,
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),
          const SizedBox(height: 20),

          // Actions
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: TellyPrimaryButton(
              label: '📤 Share to Instagram Stories',
              onPressed: _shareStory,
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildStoryCardWrapper(Widget content) {
    return AspectRatio(
      aspectRatio: 9 / 16,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: TellyColors.backgroundSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: TellyColors.borderGlass),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.6),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: content,
      ),
    );
  }

  Widget _buildCardHeader(String subtitle) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'TELLY CANON',
                style: TellyTypography.caption(color: TellyColors.phosphorLime).copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
              Text(
                '@${widget.username}',
                style: TellyTypography.titleMedium(color: TellyColors.textPrimary).copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          Text(
            subtitle,
            style: TellyTypography.caption(color: TellyColors.textTertiary),
          ),
        ],
      ),
    );
  }

  Widget _buildTop9MoviesCard() {
    final titles = [
      'Interstellar', 'Parasite', 'Spirited Away',
      'The Godfather', 'Dune 2', 'Oppenheimer',
      'The Dark Knight', 'Whiplash', 'Pulp Fiction',
    ];

    return Column(
      children: [
        _buildCardHeader('2026 Film Canon'),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.all(12),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 6,
              mainAxisSpacing: 6,
              childAspectRatio: 2 / 3,
            ),
            itemCount: 9,
            itemBuilder: (context, idx) {
              return Container(
                decoration: BoxDecoration(
                  color: TellyColors.backgroundCard,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: TellyColors.borderGlass),
                ),
                padding: const EdgeInsets.all(6),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '#0${idx + 1}',
                      style: TellyTypography.caption(
                        color: idx == 0 ? TellyColors.warmAmber : TellyColors.textTertiary,
                      ).copyWith(fontWeight: FontWeight.w900),
                    ),
                    Text(
                      titles[idx],
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: TellyColors.textPrimary, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const Spacer(),
        _buildCardFooter(),
      ],
    );
  }

  Widget _buildTop9SeriesCard() {
    final series = [
      'Succession', 'Severance', 'The Bear',
      'The Wire', 'Fargo', 'Dark',
      'Chernobyl', 'Better Call Saul', 'Mindhunter',
    ];

    return Column(
      children: [
        _buildCardHeader('All-Time Series Canon'),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.all(12),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 6,
              mainAxisSpacing: 6,
              childAspectRatio: 2 / 3,
            ),
            itemCount: 9,
            itemBuilder: (context, idx) {
              return Container(
                decoration: BoxDecoration(
                  color: TellyColors.backgroundCard,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: TellyColors.borderGlass),
                ),
                padding: const EdgeInsets.all(6),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '#0${idx + 1}',
                      style: TellyTypography.caption(
                        color: idx == 0 ? TellyColors.warmAmber : TellyColors.textTertiary,
                      ).copyWith(fontWeight: FontWeight.w900),
                    ),
                    Text(
                      series[idx],
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: TellyColors.textPrimary, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const Spacer(),
        _buildCardFooter(),
      ],
    );
  }

  Widget _buildSpicyUpsetCard() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildCardHeader('Spiciest Take'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              TellyNeonBadge.upset(label: '🚨 SPICY UPSET ALERT'),
              const SizedBox(height: 16),
              Text(
                'I ranked Severance OVER Succession.',
                textAlign: TextAlign.center,
                style: TellyTypography.titleLarge(color: TellyColors.textPrimary).copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 12),
              Text(
                'Severance #1 (10.00) vs Succession #2 (9.82)\n"The Lumon elevator sequence was television history."',
                textAlign: TextAlign.center,
                style: TellyTypography.caption(color: TellyColors.textSecondary),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: TellyColors.backgroundCard,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: TellyColors.borderGlass),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Text('Am I crazy?', style: TextStyle(color: TellyColors.textSecondary, fontWeight: FontWeight.bold)),
                    Text('[ YES ]', style: TextStyle(color: TellyColors.neonCoral, fontWeight: FontWeight.bold)),
                    Text('[ NO ]', style: TextStyle(color: TellyColors.phosphorLime, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
        ),
        _buildCardFooter(),
      ],
    );
  }

  Widget _buildDirectorAffinityCard() {
    final directors = [
      ('Christopher Nolan', '9.62', '6 Films'),
      ('Denis Villeneuve', '9.48', '5 Films'),
      ('Hayao Miyazaki', '9.42', '7 Films'),
      ('Bong Joon-ho', '9.25', '4 Films'),
      ('Quentin Tarantino', '9.18', '8 Films'),
    ];

    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildCardHeader('Director Affinity'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'TOP DIRECTORS',
                style: TellyTypography.caption(color: TellyColors.warmAmber).copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              ...directors.map((d) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: TellyColors.backgroundCard,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(d.$1, style: const TextStyle(color: TellyColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                        Text('★ ${d.$2} (${d.$3})', style: const TextStyle(color: TellyColors.warmAmber, fontWeight: FontWeight.bold, fontSize: 11)),
                      ],
                    ),
                  )),
            ],
          ),
        ),
        _buildCardFooter(),
      ],
    );
  }

  Widget _buildCardFooter() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: TellyColors.phosphorLime,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'telly.app/@${widget.username}',
                style: TellyTypography.caption(color: TellyColors.textTertiary).copyWith(fontSize: 10),
              ),
            ],
          ),
          Text(
            'The Beli for Television',
            style: TellyTypography.caption(color: TellyColors.textTertiary).copyWith(fontSize: 9),
          ),
        ],
      ),
    );
  }
}
