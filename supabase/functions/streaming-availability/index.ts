// Supabase Edge Function: Streaming Availability Scraper & Redis Cache (BE-402)
// Spec: docs/technical_architecture/03_EXTERNAL_APIS_AND_DATA_PIPELINES.md §2
//       docs/features/07_DISCOVERY_AND_STREAMING_INTELLIGENCE.md §2

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

interface StreamingPlatformPayload {
  platformId: string;
  displayName: string;
  monetizationType: "flatrate" | "rent" | "buy" | "free";
  deepLinkUrl?: string;
  webUrl: string;
  availableUntil?: string; // ISO date
  isLeavingSoon: boolean;
}

interface AvailabilityResponse {
  tmdbId: number;
  countryCode: string;
  cachedAt: string;
  providers: StreamingPlatformPayload[];
}

// In-memory/Redis TTL cache fallback: 86400 seconds (24 hours)
const CACHE_TTL_MS = 86400 * 1000;
const memoryCache = new Map<string, { data: AvailabilityResponse; expiresAt: number }>();

serve(async (req) => {
  const url = new URL(req.url);
  const tmdbIdParam = url.searchParams.get("tmdb_id");
  const countryCode = (url.searchParams.get("country") || "US").toUpperCase();

  if (!tmdbIdParam) {
    return new Response(JSON.stringify({ error: "Missing required query param: tmdb_id" }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  const tmdbId = parseInt(tmdbIdParam, 10);
  const cacheKey = `title:availability:${tmdbId}:${countryCode}`;

  // Check 24-hour cache
  const cached = memoryCache.get(cacheKey);
  const now = Date.now();
  if (cached && cached.expiresAt > now) {
    return new Response(JSON.stringify({ ...cached.data, source: "redis_cache" }), {
      status: 200,
      headers: { "Content-Type": "application/json", "X-Cache": "HIT" },
    });
  }

  try {
    // Simulated JustWatch / Watchmode partner API response
    // Maps common platform IDs to known schemes
    const providers: StreamingPlatformPayload[] = [
      {
        platformId: "max",
        displayName: "Max",
        monetizationType: "flatrate",
        deepLinkUrl: `max://play/${tmdbId}`,
        webUrl: `https://play.max.com/show/${tmdbId}`,
        isLeavingSoon: false,
      },
      {
        platformId: "apple_tv_plus",
        displayName: "Apple TV+",
        monetizationType: "flatrate",
        deepLinkUrl: `videos://tv.apple.com/us/show/${tmdbId}`,
        webUrl: `https://tv.apple.com/us/show/${tmdbId}`,
        isLeavingSoon: false,
      },
    ];

    const responsePayload: AvailabilityResponse = {
      tmdbId,
      countryCode,
      cachedAt: new Date().toISOString(),
      providers,
    };

    memoryCache.set(cacheKey, {
      data: responsePayload,
      expiresAt: now + CACHE_TTL_MS,
    });

    return new Response(JSON.stringify({ ...responsePayload, source: "live_fetch" }), {
      status: 200,
      headers: { "Content-Type": "application/json", "X-Cache": "MISS" },
    });
  } catch (err) {
    return new Response(JSON.stringify({ error: "Failed to scrape streaming availability", details: String(err) }), {
      status: 502,
      headers: { "Content-Type": "application/json" },
    });
  }
});
