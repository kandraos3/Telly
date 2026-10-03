// Maps upstream provider names/ids to Telly platform ids (streaming_platforms.id), which are also the
// providerId values understood by the Dart StreamingDeepLinkFactory.

export const PLATFORM_IDS = [
  "netflix",
  "max",
  "hulu",
  "apple_tv_plus",
  "disney_plus",
  "prime_video",
  "crunchyroll",
  "paramount_plus",
  "criterion",
] as const;

export type PlatformId = (typeof PLATFORM_IDS)[number];

// TMDB watch-provider ids (JustWatch data).
const TMDB_PROVIDER_IDS: Record<number, PlatformId> = {
  8: "netflix",
  1796: "netflix", // Netflix basic with Ads
  1899: "max",
  384: "max", // HBO Max (legacy id)
  15: "hulu",
  350: "apple_tv_plus",
  337: "disney_plus",
  9: "prime_video",
  119: "prime_video",
  283: "crunchyroll",
  531: "paramount_plus",
  258: "criterion",
};

const NAME_PATTERNS: [RegExp, PlatformId][] = [
  [/^netflix/i, "netflix"],
  [/^(hbo )?max\b|hbo max/i, "max"],
  [/^hulu/i, "hulu"],
  [/apple tv(\+| plus)/i, "apple_tv_plus"], // not the "Apple TV" purchase store
  [/disney/i, "disney_plus"],
  [/prime video|amazon prime/i, "prime_video"],
  [/crunchyroll/i, "crunchyroll"],
  [/paramount/i, "paramount_plus"],
  [/criterion/i, "criterion"],
];

export function platformFromTmdbId(providerId: number): PlatformId | null {
  return TMDB_PROVIDER_IDS[providerId] ?? null;
}

export function platformFromName(name: string): PlatformId | null {
  // Add-on channels resold through another store (e.g. "Paramount+ Apple TV Channel") are not the service itself.
  if (/\bchannel\b/i.test(name) && !/criterion/i.test(name)) return null;
  for (const [pattern, id] of NAME_PATTERNS) {
    if (pattern.test(name)) return id;
  }
  return null;
}
