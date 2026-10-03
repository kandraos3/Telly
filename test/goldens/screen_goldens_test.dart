import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telly_app/core/theme/telly_colors.dart';
import 'package:telly_app/core/theme/telly_theme.dart';
import 'package:telly_app/core/widgets/telly_neon_badge.dart';
import 'package:telly_app/features/feed/domain/social_models.dart';
import 'package:telly_app/features/feed/presentation/widgets/upset_activity_card.dart';

void main() {
  group('Visual Surface & Design Token Regression Suite (QA-502)', () {
    testWidgets('TellyNeonBadge renders all variants with proper tokens', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            backgroundColor: TellyColors.backgroundCanvasOled,
            body: Column(
              children: [
                TellyNeonBadge(label: 'WINNER', variant: TellyBadgeVariant.winner),
                TellyNeonBadge(label: 'UPSET', variant: TellyBadgeVariant.upset),
                TellyNeonBadge(label: 'GOD TIER', variant: TellyBadgeVariant.godTier),
                TellyNeonBadge(label: '88% MATCH', variant: TellyBadgeVariant.tasteMatch),
                TellyNeonBadge(label: 'NEUTRAL', variant: TellyBadgeVariant.neutral),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('WINNER'), findsOneWidget);
      expect(find.text('UPSET'), findsOneWidget);
      expect(find.text('GOD TIER'), findsOneWidget);
      expect(find.text('88% MATCH'), findsOneWidget);
      expect(find.text('NEUTRAL'), findsOneWidget);
    });

    testWidgets('UpsetActivityCard renders Neon Coral accents and controversy stats', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final upsetActivity = ActivityLog(
        id: 'act-upset-1',
        userId: 'u-jordan',
        username: 'jordan',
        userDisplayName: 'Jordan Miller',
        activityType: ActivityType.upsetAlert,
        titleId: 102,
        titleName: 'Severance',
        releaseYear: 2022,
        mediaType: 'tv',
        rankPosition: 2,
        calculatedScore: 9.72,
        culturalTier: 'God Tier',
        isUpset: true,
        upsetDelta: 0.28,
        upsetOverTitleName: 'Succession',
        upsetOverTitleRank: 4,
        agreementPercentage: 14.0,
        microReview: 'The season 2 finale was the most stressful 60 minutes of television.',
        createdAt: DateTime.now().subtract(const Duration(hours: 1)),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: TellyTheme.darkTheme,
          home: Scaffold(
            backgroundColor: TellyColors.backgroundCanvasOled,
            body: SingleChildScrollView(
              child: UpsetActivityCard(
                activity: upsetActivity,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('SPICY UPSET ALERT'), findsOneWidget);
      expect(find.text('Severance'), findsAtLeastNWidgets(1));
      expect(find.text('Succession'), findsOneWidget);
      expect(find.text('⚡ OVER'), findsOneWidget);
      expect(find.text('Only 14% of Telly users agree with this pick'), findsOneWidget);
    });

    testWidgets('OLED Dark Theme surface tokens match spec values', (tester) async {
      expect(TellyColors.backgroundPrimary, equals(const Color(0xFF08090C)));
      expect(TellyColors.backgroundCanvasOled, equals(const Color(0xFF0A0A0C)));
      expect(TellyColors.backgroundSurface, equals(const Color(0xFF11131A)));
      expect(TellyColors.backgroundCard, equals(const Color(0xFF1A1D27)));
      expect(TellyColors.phosphorLime, equals(const Color(0xFFD2FF52)));
      expect(TellyColors.phosphorLimeAlt, equals(const Color(0xFFCCFF00)));
      expect(TellyColors.neonCoral, equals(const Color(0xFFFF4B6E)));
      expect(TellyColors.neonCoralAlt, equals(const Color(0xFFFF3366)));
      expect(TellyColors.warmAmber, equals(const Color(0xFFFFA733)));
      expect(TellyColors.warmAmberAlt, equals(const Color(0xFFFFB800)));
      expect(TellyColors.borderGlass, equals(const Color(0x14FFFFFF)));
    });
  });
}

