// Reads the live TellyTypography styles for the site's tokens.css (WEB-01).
import 'package:flutter/painting.dart';
import 'package:telly_app/core/theme/telly_typography.dart';

import 'tokens.dart';

/// Every public `TellyTypography` style. Dart can't enumerate static methods,
/// so a new style needs one line here; `test/site/typography_tokens_test.dart`
/// fails until it has one.
final Map<String, TextStyle Function()> tellyTypeStyles = {
  'displayXXL': TellyTypography.displayXXL,
  'displayXL': TellyTypography.displayXL,
  'screenTitle': TellyTypography.screenTitle,
  'subpageTitle': TellyTypography.subpageTitle,
  'titleLarge': TellyTypography.titleLarge,
  'titleMedium': TellyTypography.titleMedium,
  'bodyLarge': TellyTypography.bodyLarge,
  'bodyMedium': TellyTypography.bodyMedium,
  'caption': TellyTypography.caption,
  'headlineSmall': TellyTypography.headlineSmall,
  'labelLarge': TellyTypography.labelLarge,
  'labelMedium': TellyTypography.labelMedium,
  'labelSmall': TellyTypography.labelSmall,
  'monoDigits': TellyTypography.monoDigits,
  'scoreHero': TellyTypography.scoreHero,
  'scoreChip': TellyTypography.scoreChip,
  'scoreMono': TellyTypography.scoreMono,
};

/// The CSS-relevant parts of [style]. google_fonts names the family
/// `PlusJakartaSans_700` and lists the bare family as its fallback.
TypeToken typeTokenOf(String name, TextStyle style) => TypeToken(
      name: name,
      family: style.fontFamilyFallback?.first ?? style.fontFamily!.split('_').first,
      size: style.fontSize!,
      weight: (style.fontWeight ?? FontWeight.w400).value,
      height: style.height,
      letterSpacing: style.letterSpacing ?? 0,
      tabularFigures: style.fontFeatures?.any((f) => f.feature == 'tnum') ?? false,
    );

List<TypeToken> tellyTypeTokens() => [
      for (final MapEntry(key: name, value: style) in tellyTypeStyles.entries) typeTokenOf(name, style()),
    ];
